// The propagation rules from §2 of the spec, and nothing else.
//
// This class knows nothing about Nearby Connections or Flutter widgets — it
// talks to a MessageStore and a MeshTransport, both of which are interfaces.
// That is what lets a whole multi-node mesh be simulated in a unit test.

// dart:typed_data rather than flutter/foundation.dart: foundation exports a
// `Category` annotation that collides with our message category enum.
import 'dart:typed_data';

import 'mesh_message.dart';
import 'mesh_transport.dart';
import 'message_store.dart';

/// Why a received message was not accepted. Useful in logs and tests.
enum DropReason {
  malformed,
  duplicate,
  expired,
}

class MeshRouter {
  MeshRouter({
    required this.store,
    required this.transport,
    required this.origin,
    String? uid,
    int Function()? clock,
  })  : uid = uid ?? origin,
        _clock = clock ?? _wallClock;

  final MessageStore store;
  final MeshTransport transport;

  /// This device's identity. Stands in for the Firebase UID until auth lands.
  final String origin;
  final String uid;

  /// Unix seconds. Injectable so expiry and the 72h skew rule are testable
  /// without waiting three days.
  final int Function() _clock;

  static int _wallClock() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

  int get now => _clock();

  /// Fired when a message is accepted into the local store — whether we
  /// created it or received it.
  void Function(MeshMessage message)? onAccepted;

  /// Fired when an inbound message is not accepted.
  void Function(DropReason reason, String detail)? onDropped;

  /// Human-readable activity, for the app's log panel.
  void Function(String line)? onLog;

  void _log(String line) => onLog?.call(line);

  /// The clock-skew bound: a node expires a message on whichever comes first,
  /// its own `exp` or 72h after local receipt. A wrong sender clock can
  /// therefore only make us hold a message too long, never discard it early.
  int _localExpiryFor(MeshMessage message, int receivedAt) {
    final skewBound = receivedAt + kExpirySeconds;
    return message.env.exp < skewBound ? message.env.exp : skewBound;
  }

  // --- creating ------------------------------------------------------------

  /// Builds an SOS, stores it, and floods it.
  ///
  /// Works with zero peers in range — the message simply sits in the store
  /// until [onPeerConnected] flushes it to someone.
  Future<MeshMessage> createSos({
    Category? cat,
    int? n,
    String? txt,
    GeoPoint? loc,
  }) async {
    final seq = await store.nextSeq();
    final message = MeshMessage.createSos(
      origin: origin,
      uid: uid,
      seq: seq,
      now: now,
      cat: cat,
      n: n,
      txt: txt,
      loc: loc,
    );
    await _accept(message, receivedAt: now);
    final peers = await transport.broadcast(message.encode());
    _log('created ${message.core.typeWire} ${message.id} → $peers peer'
        '${peers == 1 ? '' : 's'}');
    return message;
  }

  /// Stores a message and marks it seen.
  ///
  /// Marking our *own* messages seen is what stops a device accepting its own
  /// message back from a neighbour.
  Future<void> _accept(MeshMessage message, {required int receivedAt}) async {
    final localExpiry = _localExpiryFor(message, receivedAt);
    await store.markSeen(message.id, expiresAt: localExpiry);
    await store.put(message, localExpiry: localExpiry);
    onAccepted?.call(message);
  }

  // --- receiving -----------------------------------------------------------

  /// Handles bytes that arrived from [endpointId].
  ///
  /// The rules, in order:
  ///   1. id already seen  → drop silently, no reply and no forward
  ///   2. expired          → drop
  ///   3. otherwise        → store, hops++, forward to every peer but the sender
  ///
  /// Dedup runs at every hop, not just at the destination, so a duplicate
  /// travels exactly one hop and dies at the cost of one lookup. Duplicates are
  /// a feature — the goal is never to prevent them, only to make them cheap.
  Future<void> onBytes(String endpointId, Uint8List bytes) async {
    final MeshMessage message;
    try {
      message = MeshMessage.decode(bytes);
    } on MalformedMessageException catch (e) {
      // Bytes come from strangers over an unauthenticated link. Dropping a bad
      // packet is routine, not exceptional.
      onDropped?.call(DropReason.malformed, e.reason);
      _log('dropped malformed packet from $endpointId: ${e.reason}');
      return;
    }

    if (await store.hasSeen(message.id)) {
      onDropped?.call(DropReason.duplicate, message.id);
      return; // Silently. No reply, no forward.
    }

    final receivedAt = now;
    if (message.env.exp <= receivedAt) {
      onDropped?.call(DropReason.expired, message.id);
      _log('dropped expired ${message.id}');
      return;
    }

    // The increment belongs to receipt, not to forwarding: a node one hop from
    // the origin holds the message at hops=1, and hands on that same copy.
    final relayed = message.incrementHops();
    await _accept(relayed, receivedAt: receivedAt);

    final peers = await transport.broadcast(
      relayed.encode(),
      exceptEndpointId: endpointId,
    );
    _log('relayed ${relayed.core.typeWire} ${relayed.id} '
        'hops=${relayed.env.hops} → $peers peer${peers == 1 ? '' : 's'}');
  }

  // --- store and forward ---------------------------------------------------

  /// What we have already handed to each peer, keyed by the peer's advertised
  /// name rather than its endpoint id.
  ///
  /// Nearby regenerates the endpoint id on every reconnect, so it is useless
  /// for remembering anything across a link bouncing. The advertised name is
  /// stable, which is what makes each (peer, message) pair transfer once
  /// however often the connection flaps.
  final Map<String, Set<String>> _flushedByPeer = {};

  /// Pushes the backlog to a peer that just connected.
  ///
  /// This is the mechanism the whole system rests on: a person physically
  /// walking is a valid data carrier. Without it, messages only ever propagate
  /// at the instant of receipt and a courier carries nothing.
  ///
  /// There is no retry timer anywhere — reconnection is the retry.
  Future<void> onPeerConnected(String endpointId, String peerName) async {
    final backlog = await store.forwardable(now: now);
    if (backlog.isEmpty) return;

    final alreadySent = _flushedByPeer.putIfAbsent(peerName, () => {});
    final pending = [
      for (final message in backlog)
        if (!alreadySent.contains(message.id)) message,
    ];
    if (pending.isEmpty) return;

    var sent = 0;
    for (final message in pending) {
      if (await transport.sendTo(endpointId, message.encode())) {
        // Only on success: a transfer that failed mid-flight must be retried
        // on the next connect, not recorded as delivered.
        alreadySent.add(message.id);
        sent++;
      }
    }
    _log('flushed $sent/${pending.length} held message'
        '${pending.length == 1 ? '' : 's'} to $peerName');
  }

  /// Drops expired seen entries and messages. Safe to call periodically.
  Future<void> prune() async {
    await store.pruneExpired(now: now);

    // Forget flush bookkeeping for messages that no longer exist, so the map
    // cannot outgrow the store.
    final live = {
      for (final message in await store.all()) message.id,
    };
    for (final sent in _flushedByPeer.values) {
      sent.removeWhere((id) => !live.contains(id));
    }
  }
}
