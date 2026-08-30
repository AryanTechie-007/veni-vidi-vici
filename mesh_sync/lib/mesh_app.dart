// Owns everything and wires it together: persisted identity, the message
// store, the radio, and the router.
//
// Nothing else in the app knows how those four fit together.

import 'dart:async';

// `hide Category`: foundation exports a Category annotation that collides with
// the message category enum.
import 'package:flutter/foundation.dart' hide Category;

import 'device_identity.dart';
import 'mesh_service.dart';
import 'messages/mesh_message.dart';
import 'messages/mesh_router.dart';
import 'messages/message_store.dart';

/// How often expired messages and seen entries are swept.
const Duration kPruneInterval = Duration(minutes: 5);

class MeshApp extends ChangeNotifier {
  MeshApp._(this._identity, this.service, this.store, this.router) {
    // The whole wiring, in one place.
    service.onPayload = router.onBytes;
    service.onPeerConnected = router.onPeerConnected;
    router.onLog = service.logLine;
    router.onAccepted = _record;

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
  MeshRole get role => _identity.role;

  /// SOS messages from other devices — the responder's incident list.
  List<MeshMessage> get incidents => [
        for (final m in _messages)
          if (m.core.type == MessageType.sos && m.core.origin != origin) m,
      ];

  /// What this device has sent itself.
  List<MeshMessage> get myMessages => [
        for (final m in _messages)
          if (m.core.origin == origin) m,
      ];

  void _record(MeshMessage message) {
    _messages.insert(0, message);
    notifyListeners();
  }

  Future<void> setRole(MeshRole value) async {
    if (value == role) return;
    await _identity.saveRole(value);
    await service.setRole(value);
    notifyListeners();
  }

  /// Creates and floods an SOS. Works with zero peers in range — it simply
  /// waits in the store until someone connects.
  Future<MeshMessage> sendSos({
    required Category cat,
    required int n,
    String? txt,
  }) =>
      router.createSos(cat: cat, n: n, txt: txt);

  @override
  void dispose() {
    _pruneTimer.cancel();
    service.dispose();
    super.dispose();
  }
}
