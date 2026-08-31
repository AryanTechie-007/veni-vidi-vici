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

  /// A message a CANCEL already closed. Kept out of the store for good.
  cancelled,
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

  /// When true, this device auto-emits an ACK the moment an SOS enters its
  /// store. Not triggered by a human tap, so an unattended responder phone
  /// still confirms.
  bool isResponder = false;

  /// Fired when the state of a referenced message changes — an ACK or CANCEL
  /// landed for it. The UI uses this to move an SOS out of "relayed" and into
  /// a state that actually means something.
  void Function(String sosId)? onReferencedChanged;

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
    await _applyEffects(message);
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

    // A CANCEL already closed this incident. Refuse to take it back.
    if (await store.isCancelled(message.id)) {
      onDropped?.call(DropReason.cancelled, message.id);
      await store.markSeen(message.id, expiresAt: message.env.exp);
      _log('refused cancelled ${message.id}');
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

  /// Applies the meaning of a message once it is in the store.
  ///
  /// All three types travel through identical flooding machinery; this is the
  /// only place where type matters at all. An ACK or CANCEL may arrive at a
  /// node that has never seen the message it references — out-of-order arrival
  /// is normal, so the reference is recorded regardless of whether we hold the
  /// target.
  Future<void> _applyEffects(MeshMessage message) async {
    switch (message.core.type) {
      case MessageType.sos:
        // A responder confirms automatically, with no human tap, so an
        // unattended responder phone still acknowledges.
        if (isResponder && message.core.origin != origin) {
          await _emitAck(message.id);
        }

      case MessageType.ack:
        final ref = message.core.ref;
        if (ref == null) return;
        await store.markAcked(ref);
        onReferencedChanged?.call(ref);
        _log('ACK for $ref — suppressing further relay of it');

      case MessageType.cancel:
        final ref = message.core.ref;
        if (ref == null) return;
        await _noteCancelBasis(message, ref);
        await store.markCancelled(ref);
        // Deletes the message but deliberately leaves the seen entry, which is
        // what refuses it if a peer offers it again.
        await store.delete(ref);
        onReferencedChanged?.call(ref);
        _log('CANCEL (${message.core.reason?.wire ?? 'no reason'}) for $ref '
            '— purged from local storage');

      case MessageType.unknown:
        // Relayed but never acted on, so newer builds can add types without
        // older ones dropping their traffic.
        break;
    }
  }

  /// Records how trustworthy a CANCEL was, for the log.
  ///
  /// The spec's rule is to honour a CANCEL whose origin matches either the
  /// referenced SOS's origin, or a known responder UID — otherwise any device
  /// could silence any other device's SOS.
  ///
  /// Only the first half is checkable today, and only when we happen to hold
  /// the referenced message. Nothing on this link is signed, there is no
  /// responder registry, and `origin` is a plain JSON field any device can
  /// set, so a responder's CANCEL is indistinguishable from a forged one.
  ///
  /// Every CANCEL is therefore honoured. Refusing the unverifiable ones would
  /// break the main flow — a responder closing someone else's incident — while
  /// still not stopping a determined forger, who can simply claim the victim's
  /// origin. This method is the single place to harden once messages are
  /// signed.
  Future<void> _noteCancelBasis(MeshMessage cancel, String ref) async {
    final target = await store.get(ref);
    if (target != null && cancel.core.origin == target.core.origin) return;
    _log('honouring unverified CANCEL for $ref from ${cancel.core.origin}');
  }

  /// Creates and floods an ACK referencing [sosId].
  Future<MeshMessage> _emitAck(String sosId) async {
    final seq = await store.nextSeq();
    final ack = MeshMessage.createAck(
      origin: origin,
      uid: uid,
      seq: seq,
      now: now,
      sosId: sosId,
    );
    await _accept(ack, receivedAt: now);
    final peers = await transport.broadcast(ack.encode());
    _log('auto-ACK ${ack.id} for $sosId → $peers peer${peers == 1 ? '' : 's'}');
    return ack;
  }

  /// Closes the incident referenced by [sosId] and floods the CANCEL.
  Future<MeshMessage> createCancel({
    required String sosId,
    required CancelReason reason,
  }) async {
    final seq = await store.nextSeq();
    final cancel = MeshMessage.createCancel(
      origin: origin,
      uid: uid,
      seq: seq,
      now: now,
      sosId: sosId,
      reason: reason,
    );
    await _accept(cancel, receivedAt: now);
    final peers = await transport.broadcast(cancel.encode());
    _log('CANCEL ${cancel.id} for $sosId (${reason.wire}) → $peers peer'
        '${peers == 1 ? '' : 's'}');
    return cancel;
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
