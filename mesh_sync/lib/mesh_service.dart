// All Nearby Connections handling lives here. Nothing in this file imports
// material.dart — the transport has no opinion about the UI, and the UI only
// sees the observable surface below.
//
// Scope is still the spike's: raw UTF-8 bytes to directly-connected peers.
// No packet format, no dedup, no forwarding. See [onPayload] for where the
// mesh layer plugs in when it arrives.

import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';

import 'device_identity.dart';
import 'messages/mesh_transport.dart';

/// Must be identical on every device or they will never see each other.
const String kServiceId = 'com.meshsync.mesh_sync';

/// The only strategy where every device advertises and discovers at once and
/// forms a graph rather than a hub-and-spoke.
const Strategy kStrategy = Strategy.P2P_CLUSTER;

/// Why the mesh is not running, in terms a user can act on.
enum MeshFault {
  none('', null),

  /// Asked and refused, but askable again.
  permissionsDenied(
    'Nearby needs Bluetooth and location permission to find other devices.',
    'Grant',
  ),

  /// Refused with "don't ask again" — only Android settings can undo it.
  permissionsBlocked(
    'Permissions are blocked. Turn them on in Android settings, then start '
    'the mesh again.',
    'Open settings',
  ),

  /// Holding the permission is not the same as having the GPS toggle on, and
  /// Nearby cannot scan without it.
  locationOff(
    'Turn on location services. Nearby cannot scan for devices without them, '
    'even with permission granted.',
    null,
  ),

  /// Nearby itself refused: Bluetooth off, Play Services missing or stale.
  radioUnavailable(
    'Could not start the radio. Check Bluetooth is on and that Google Play '
    'services is available on this device.',
    'Retry',
  );

  const MeshFault(this.message, this.actionLabel);

  final String message;
  final String? actionLabel;
}

/// A peer we are currently connected to.
@immutable
class MeshPeer {
  const MeshPeer({required this.endpointId, required this.name});

  /// Opaque, assigned by Nearby, and different on every reconnect.
  final String endpointId;

  /// What the peer advertised — stable across reconnects, so this is what
  /// gets shown to humans.
  final String name;
}

/// Owns the Nearby Connections lifecycle and exposes it as observable state.
///
/// Listen to it directly (it is a [ChangeNotifier]) for connection and log
/// changes; set [onPayload] to receive inbound bytes.
class MeshService extends ChangeNotifier implements MeshTransport {
  MeshService({MeshRole role = MeshRole.victim}) : _deviceTag = _generateTag() {
    _role = role;
    _append('I am $nickname');
    refreshGps();
  }

  /// The random half of the advertised name, so two phones running the same
  /// build are distinguishable in the log.
  final String _deviceTag;

  late MeshRole _role;

  MeshRole get role => _role;

  /// This device's advertised endpoint name, e.g. `C|dev-K7P2`.
  ///
  /// The role prefix is what lets a peer see the role before connecting, per
  /// the spec. It also means responders sort above citizens in the symmetry
  /// break below, so a responder always dials — deterministic either way.
  String get nickname => '${_role.code}|$_deviceTag';

  /// Called for every inbound BYTES payload, tagged with the peer it arrived
  /// from. That [String] endpointId is what the forwarding rule needs in order
  /// to re-broadcast to every peer *except* the sender.
  void Function(String endpointId, Uint8List bytes)? onPayload;

  /// Called when a link comes up, with the peer's stable advertised name.
  ///
  /// This is what drives store-and-forward: without it, messages would only
  /// ever propagate at the instant of receipt and a courier would carry
  /// nothing.
  void Function(String endpointId, String peerName)? onPeerConnected;

  bool _running = false;
  bool _gpsEnabled = true;
  MeshFault _fault = MeshFault.none;
  String? _faultDetail;
  List<String> _missingPermissions = [];
  bool _disposed = false;

  /// endpointId -> name, for peers we are actually connected to.
  final Map<String, String> _connected = {};

  /// Connection requested or initiated, not yet resolved. Guards against
  /// `onEndpointFound` firing repeatedly for the same endpoint.
  final Set<String> _pending = {};

  /// endpointId -> name, kept even after disconnect so log lines can still
  /// name the peer once it has left [_connected].
  final Map<String, String> _names = {};

  /// endpointId -> when the link came up, for reporting session length.
  final Map<String, DateTime> _connectedAt = {};

  // --- observable state ----------------------------------------------------

  bool get isRunning => _running;

  /// Whether the GPS *toggle* is on — distinct from holding the location
  /// permission, and Nearby needs both.
  bool get gpsEnabled => _gpsEnabled;

  int get pendingCount => _pending.length;

  /// Why the last start attempt failed, or [MeshFault.none].
  MeshFault get fault => _fault;

  /// The underlying error, for the log and for a details line in the UI.
  String? get faultDetail => _faultDetail;

  /// Human-readable names of the permissions still missing.
  List<String> get missingPermissions => List.unmodifiable(_missingPermissions);

  List<MeshPeer> get peers => [
        for (final entry in _connected.entries)
          MeshPeer(endpointId: entry.key, name: entry.value),
      ];

  // --- internals -----------------------------------------------------------

  static String _generateTag() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random();
    final suffix =
        List.generate(4, (_) => chars[rng.nextInt(chars.length)]).join();
    return 'dev-$suffix';
  }

  /// Switches role and republishes the advertised name.
  ///
  /// The name is baked into the advertisement, so it only changes on a restart
  /// of advertising — peers re-form afterwards.
  Future<void> setRole(MeshRole value) async {
    if (value == _role) return;
    final wasRunning = _running;
    if (wasRunning) await stop();
    _role = value;
    _append('role → ${value.label}, now advertising as $nickname');
    if (wasRunning) await start();
    _notify();
  }

  /// Lets other layers write into the one log panel rather than keeping their
  /// own. The router's `onLog` is wired to this.
  void logLine(String line) => _append(line);

  /// Nearby callbacks can land after the widget tree is gone.
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Transport activity goes to logcat only — read it with `flutter logs` or
  /// `adb logcat`. There is no in-app log panel.
  void _append(String message) {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    debugPrint('[MeshSync] ${two(now.hour)}:${two(now.minute)}:'
        '${two(now.second)}  $message');
  }

  // --- permissions ---------------------------------------------------------

  Future<void> refreshGps() async {
    final enabled = await Permission.location.serviceStatus.isEnabled;
    _gpsEnabled = enabled;
    _notify();
  }

  /// Everything Nearby needs. Which of these actually exist depends on the
  /// Android version, which is why nothing here is used to *block* a start —
  /// it only explains one that already failed.
  static const List<Permission> _required = [
    Permission.location,
    Permission.bluetoothScan,
    Permission.bluetoothAdvertise,
    Permission.bluetoothConnect,
    Permission.nearbyWifiDevices,
  ];

  static String _label(Permission permission) =>
      permission.toString().replaceFirst('Permission.', '');

  /// Asks for anything missing. Returns whether everything is now granted.
  Future<bool> requestPermissions() async {
    final statuses = await _required.request();

    for (final entry in statuses.entries) {
      _append('perm ${_label(entry.key)}: ${entry.value.name}');
    }

    final denied = [
      for (final entry in statuses.entries)
        if (!entry.value.isGranted) entry.key,
    ];
    _missingPermissions = [for (final p in denied) _label(p)];

    // Granting the location permission is not the same as having the GPS
    // toggle on, and Nearby drops connections almost immediately without it.
    await refreshGps();

    if (denied.isNotEmpty) {
      final blocked = statuses.values.any((s) => s.isPermanentlyDenied);
      _fault = blocked
          ? MeshFault.permissionsBlocked
          : MeshFault.permissionsDenied;
      _faultDetail = 'Denied: ${_missingPermissions.join(', ')}';
    } else if (!_gpsEnabled) {
      _fault = MeshFault.locationOff;
      _faultDetail = 'Location services are switched off';
    } else {
      _fault = MeshFault.none;
      _faultDetail = null;
    }

    _notify();
    return denied.isEmpty && _gpsEnabled;
  }

  /// Opens the system settings page for this app, for permissions the user has
  /// blocked with "don't ask again".
  Future<void> openSettings() => openAppSettings();

  /// Works out why a start attempt failed, so the UI can say something better
  /// than "it didn't work".
  ///
  /// Deliberately runs *after* a failure rather than gating the attempt:
  /// which permissions exist varies by Android version, so treating a
  /// permission report as authoritative up front would refuse to start on
  /// devices where the mesh works fine.
  Future<void> _diagnose(String detail) async {
    _faultDetail = detail;

    final missing = <Permission>[];
    var blocked = false;
    for (final permission in _required) {
      final status = await permission.status;
      if (status.isGranted) continue;
      missing.add(permission);
      if (status.isPermanentlyDenied) blocked = true;
    }
    _missingPermissions = [for (final p in missing) _label(p)];

    await refreshGps();

    // Nearby reports its own permission failures as MISSING_PERMISSION_*,
    // which is more trustworthy than our own reading of the permission state.
    final nearbySaysPermissions = detail.contains('MISSING_PERMISSION');

    if (missing.isNotEmpty || nearbySaysPermissions) {
      _fault = blocked
          ? MeshFault.permissionsBlocked
          : MeshFault.permissionsDenied;
    } else if (!_gpsEnabled) {
      _fault = MeshFault.locationOff;
    } else {
      _fault = MeshFault.radioUnavailable;
    }

    _append('start failed (${_fault.name}): $detail');
  }

  // --- lifecycle -----------------------------------------------------------

  Future<void> start() async {
    if (_running) return;
    _fault = MeshFault.none;
    _faultDetail = null;
    _notify();
    await refreshGps();
    try {
      final advertising = await Nearby().startAdvertising(
        nickname,
        kStrategy,
        serviceId: kServiceId,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );
      final discovering = await Nearby().startDiscovery(
        nickname,
        kStrategy,
        serviceId: kServiceId,
        onEndpointFound: _onEndpointFound,
        onEndpointLost: _onEndpointLost,
      );
      if (advertising && discovering) {
        _running = true;
        _fault = MeshFault.none;
        _faultDetail = null;
        _missingPermissions = [];
        _append('started — advertising and discovering as $nickname');
      } else {
        // Half-started is worse than not started: tear down whichever side
        // came up so the state is honest.
        await Nearby().stopAdvertising();
        await Nearby().stopDiscovery();
        await _diagnose(
          'Nearby refused to start (advertising=$advertising, '
          'discovering=$discovering)',
        );
      }
    } catch (e) {
      await _diagnose('$e');
    }
    _notify();
  }

  Future<void> stop() async {
    try {
      await Nearby().stopAdvertising();
      await Nearby().stopDiscovery();
      await Nearby().stopAllEndpoints();
    } catch (e) {
      _append('stop error: $e');
    }
    _running = false;
    _connected.clear();
    _pending.clear();
    _fault = MeshFault.none;
    _faultDetail = null;
    _append('stopped');
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    // Best effort — we are going away, so failures here are not actionable.
    Nearby().stopAdvertising();
    Nearby().stopDiscovery();
    Nearby().stopAllEndpoints();
    super.dispose();
  }

  // --- nearby callbacks ----------------------------------------------------

  void _onEndpointFound(String id, String name, String serviceId) {
    _append('found $name ($id)');
    if (_connected.containsKey(id) || _pending.contains(id)) return;

    // Both devices discover each other and would both call requestConnection,
    // which Nearby answers with STATUS_ALREADY_CONNECTED_TO_ENDPOINT noise.
    // Let only the higher-named side dial; the other waits to be invited.
    if (nickname.compareTo(name) <= 0) {
      _append('deferring to $name to initiate');
      return;
    }

    _pending.add(id);
    _names[id] = name;
    _notify();

    Nearby()
        .requestConnection(
      nickname,
      id,
      onConnectionInitiated: _onConnectionInitiated,
      onConnectionResult: _onConnectionResult,
      onDisconnected: _onDisconnected,
    )
        .catchError((e) {
      _pending.remove(id);
      _append('requestConnection to $name failed: $e');
      return false;
    });
  }

  void _onEndpointLost(String? id) {
    _append('lost endpoint ${_names[id] ?? id}');
  }

  void _onConnectionInitiated(String id, ConnectionInfo info) {
    _names[id] = info.endpointName;
    final direction = info.isIncomingConnection ? 'incoming' : 'outgoing';
    _append('$direction connection with ${info.endpointName} — auto-accepting');

    // No pairing-code dialog. Nobody confirms a 4-digit token in an emergency.
    Nearby().acceptConnection(
      id,
      onPayLoadRecieved: _onPayloadReceived,
    ).catchError((e) {
      _append('acceptConnection with ${info.endpointName} failed: $e');
      return false;
    });
  }

  void _onPayloadReceived(String endpointId, Payload payload) {
    if (payload.type != PayloadType.BYTES || payload.bytes == null) {
      _append('<-- non-bytes payload (${payload.type.name})');
      return;
    }
    final bytes = payload.bytes!;
    _append('<-- ${_preview(bytes)}');
    onPayload?.call(endpointId, bytes);
  }

  /// Bytes are opaque to this layer, so render something readable for the log
  /// without pretending to understand the contents.
  String _preview(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return '${bytes.length} bytes (not utf-8)';
    }
  }

  void _onConnectionResult(String id, Status status) {
    final name = _names[id] ?? id;
    _pending.remove(id);
    if (status == Status.CONNECTED) {
      _connected[id] = name;
      _connectedAt[id] = DateTime.now();
    }
    _append(status == Status.CONNECTED
        ? 'CONNECTED to $name'
        : 'connection to $name ended as ${status.name}');
    _notify();

    if (status == Status.CONNECTED) {
      // After the log line, so the flush reads in order beneath it.
      onPeerConnected?.call(id, name);
    }
  }

  void _onDisconnected(String id) {
    final name = _connected[id] ?? _names[id] ?? id;
    final since = _connectedAt.remove(id);
    _connected.remove(id);

    // Session length separates ordinary medium-upgrade churn from a real
    // fault: 30s+ is normal, repeated sub-second drops mean GPS is off or
    // both sides deferred in the symmetry break and neither dialled.
    final held = since == null
        ? ''
        : ' after ${DateTime.now().difference(since).inSeconds}s';
    _append('disconnected from $name$held');
    _notify();
  }

  // --- sending -------------------------------------------------------------

  /// Broadcasts [bytes] to every connected peer, skipping [exceptEndpointId].
  ///
  /// Returns the number of peers it reached. The skip parameter is what the
  /// forwarding rule will use to avoid echoing a message back to its sender.
  @override
  Future<int> broadcast(Uint8List bytes, {String? exceptEndpointId}) async {
    var sent = 0;
    // Defensive copy: there is an await in the loop, and a disconnect callback
    // firing mid-send would otherwise mutate the map while we iterate it.
    for (final id in _connected.keys.toList()) {
      if (id == exceptEndpointId) continue;
      try {
        await Nearby().sendBytesPayload(id, bytes);
        sent++;
      } catch (e) {
        _append('send to ${_connected[id] ?? id} failed: $e');
      }
    }
    return sent;
  }

  @override
  Future<bool> sendTo(String endpointId, Uint8List bytes) async {
    if (!_connected.containsKey(endpointId)) return false;
    try {
      await Nearby().sendBytesPayload(endpointId, bytes);
      return true;
    } catch (e) {
      _append('send to ${_connected[endpointId] ?? endpointId} failed: $e');
      return false;
    }
  }
}
