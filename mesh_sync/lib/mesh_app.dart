// Owns everything and wires it together: persisted identity, the message
// store, the radio, and the router.
//
// Nothing else in the app knows how those four fit together.

import 'dart:async';

// `hide Category`: foundation exports a Category annotation that collides with
// the message category enum.
import 'package:flutter/foundation.dart' hide Category;

import 'auth.dart';
import 'device_identity.dart';
import 'location_service.dart';
import 'mesh_service.dart';
import 'messages/mesh_message.dart';
import 'messages/mesh_router.dart';
import 'messages/message_store.dart';

/// A written reply from a responder who read the incident.
@immutable
class ResponderReply {
  const ResponderReply({
    required this.from,
    required this.text,
    required this.ts,
  });

  /// The responder's origin. There is no name to resolve it to until the
  /// responder directory is pre-cached.
  final String from;

  final String text;
  final int ts;
}

/// A victim revising their own open incident.
@immutable
class IncidentUpdate {
  const IncidentUpdate({
    required this.status,
    required this.text,
    required this.ts,
  });

  /// Null when the sender used a status this build does not recognise.
  final UpdateStatus? status;

  final String? text;
  final int ts;
}

/// The lifecycle of one incident, as this device understands it.
enum IncidentState {
  /// Nobody has acknowledged it yet.
  open,

  /// A responder confirmed receipt. The SOS stops being relayed but stays
  /// stored, so a responder arriving later still sees the record.
  acknowledged,

  /// Closed by a CANCEL. Purged from the message store and refused from peers;
  /// kept here only so this device can still show what it closed.
  closed,
}

/// How often expired messages and seen entries are swept.
const Duration kPruneInterval = Duration(minutes: 5);

class MeshApp extends ChangeNotifier {
  MeshApp._(this._identity, this.service, this.store, this.router) {
    // The whole wiring, in one place.
    service.onPayload = router.onBytes;
    service.onPeerConnected = router.onPeerConnected;
    router.onLog = service.logLine;
    router.onAccepted = _record;
    router.onReferencedChanged = (_) => notifyListeners();
    router.isResponder = _identity.role == MeshRole.responder;

    _pruneTimer = Timer.periodic(kPruneInterval, (_) => router.prune());
  }

  static Future<MeshApp> create() async {
    final identity = await DeviceIdentity.load();
    final service = MeshService(role: identity.role);

    final store = InMemoryMessageStore(
      startingSeq: identity.seq,
      // Persisted on every increment. If this counter ever restarts, ids
      // collide with previously sent messages and the mesh drops real
      // traffic as duplicates.
      onSeqAdvanced: identity.saveSeq,
    );

    final router = MeshRouter(
      store: store,
      transport: service,
      origin: identity.origin,
    );

    return MeshApp._(identity, service, store, router);
  }

  final DeviceIdentity _identity;

  final LocationService location = LocationService();
  final MeshService service;
  final MessageStore store;
  final MeshRouter router;

  late final Timer _pruneTimer;

  /// Everything this device holds, newest first.
  ///
  /// Kept alongside the store because [MessageStore.all] is async and cannot
  /// be called from `build`.
  final List<MeshMessage> _messages = [];

  String get origin => _identity.origin;

  /// Messages this device has created. Survives sign-out on purpose.
  int get seq => _identity.seq;
  MeshRole get role => _identity.role;

  /// SOS messages from other devices — the responder's incident list.
  List<MeshMessage> get incidents => [
    for (final m in _messages)
      if (m.core.type == MessageType.sos && m.core.origin != origin) m,
  ];

  /// SOS messages this device sent itself.
  List<MeshMessage> get myMessages => [
    for (final m in _messages)
      if (m.core.origin == origin && m.core.type == MessageType.sos) m,
  ];

  /// Looked up by id rather than held by value: a CANCEL can purge a message
  /// while a detail page is open on it.
  MeshMessage? messageById(String id) {
    for (final m in _messages) {
      if (m.id == id) return m;
    }
    return null;
  }

  void _record(MeshMessage message) {
    _messages.insert(0, message);
    if (message.core.type == MessageType.ack && message.core.ref != null) {
      _ackedIds.add(message.core.ref!);
      // An ACK carrying text was written by a person who read the incident,
      // not emitted by a device on receipt. Worth surfacing on both sides.
      final txt = message.core.txt;
      if (txt != null && txt.isNotEmpty) {
        _repliesByRef
            .putIfAbsent(message.core.ref!, () => [])
            .add(
              ResponderReply(
                from: message.core.origin,
                text: txt,
                ts: message.core.ts,
              ),
            );
      }
    }
    if (message.core.type == MessageType.update && message.core.ref != null) {
      _updatesByRef
          .putIfAbsent(message.core.ref!, () => [])
          .add(
            IncidentUpdate(
              status: message.core.st,
              text: message.core.txt,
              ts: message.core.ts,
            ),
          );
    }
    if (message.core.type == MessageType.cancel && message.core.ref != null) {
      // The store purges it and refuses it from peers, exactly as the spec
      // says. This list is a local archive kept only so the operator can see
      // what they closed — it never changes what goes over the radio.
      _closedIds.add(message.core.ref!);
    }
    notifyListeners();
  }

  String? get username => _identity.username;

  bool get isSignedIn => _identity.username != null;

  Future<void> signIn(Account account) async {
    await _identity.signIn(account.username, account.role);
    router.isResponder = account.role == MeshRole.responder;
    await service.setRole(account.role);
    notifyListeners();
  }

  /// Ends the session and takes the radio down with it.
  ///
  /// Held messages stay in the store: this device may still be carrying a
  /// stranger's SOS, and signing out is no reason to drop it.
  Future<void> signOut() async {
    await service.stop();
    await _identity.signOut();
    notifyListeners();
  }

  Future<void> setRole(MeshRole value) async {
    if (value == role) return;
    await _identity.saveRole(value);
    router.isResponder = value == MeshRole.responder;
    await service.setRole(value);
    notifyListeners();
  }

  /// Whether [sosId] has been acknowledged by some responder.
  ///
  /// Synchronous so the UI can call it from `build`; kept in step with the
  /// store by [MeshRouter.onReferencedChanged].
  bool isAcked(String sosId) => _ackedIds.contains(sosId);

  bool isClosed(String sosId) => _closedIds.contains(sosId);

  /// Closed outranks acknowledged: an incident that was acked and then closed
  /// reads as closed.
  IncidentState stateOf(String sosId) {
    if (_closedIds.contains(sosId)) return IncidentState.closed;
    if (_ackedIds.contains(sosId)) return IncidentState.acknowledged;
    return IncidentState.open;
  }

  /// Written replies, newest last, keyed by the SOS they reference.
  List<ResponderReply> repliesFor(String sosId) =>
      List.unmodifiable(_repliesByRef[sosId] ?? const []);

  final Set<String> _ackedIds = {};
  final Map<String, List<ResponderReply>> _repliesByRef = {};
  final Map<String, List<IncidentUpdate>> _updatesByRef = {};

  /// Status updates on [sosId], oldest first.
  List<IncidentUpdate> updatesFor(String sosId) =>
      List.unmodifiable(_updatesByRef[sosId] ?? const []);

  /// When this incident last showed any sign of life — the SOS itself, or the
  /// most recent update on it. Used to sort the responder's list.
  int lastActivity(MeshMessage sos) {
    final updates = _updatesByRef[sos.id];
    if (updates == null || updates.isEmpty) return sos.core.ts;
    return updates.last.ts > sos.core.ts ? updates.last.ts : sos.core.ts;
  }

  /// Seconds until another update on [sosId] would be accepted; zero if now.
  int secondsUntilNextUpdate(String sosId) =>
      router.secondsUntilNextUpdate(sosId);

  /// Revises an open incident. Returns false when the rate limit refused it.
  Future<bool> sendUpdate(
    String sosId, {
    required UpdateStatus status,
    String? txt,
  }) async {
    final sent = await router.createUpdate(
      sosId: sosId,
      status: status,
      txt: txt,
    );
    notifyListeners();
    return sent != null;
  }

  final Set<String> _closedIds = {};

  /// Acknowledges an incident by hand.
  ///
  /// A responder device already ACKs on receipt, so this only matters for an
  /// incident that arrived while this device was not yet a responder.
  Future<void> acknowledge(String sosId, {String? txt}) async {
    await router.sendAck(sosId, txt: txt);
    notifyListeners();
  }

  /// Closes an incident and floods the CANCEL.
  Future<void> cancel(String sosId, CancelReason reason) async {
    await router.createCancel(sosId: sosId, reason: reason);
    notifyListeners();
  }

  /// Creates and floods an SOS. Works with zero peers in range — it simply
  /// waits in the store until someone connects.
  Future<MeshMessage> sendSos({
    required Category cat,
    required int n,
    String? txt,
    GeoPoint? loc,
  }) => router.createSos(cat: cat, n: n, txt: txt, loc: loc);

  @override
  void dispose() {
    _pruneTimer.cancel();
    service.dispose();
    super.dispose();
  }
}
