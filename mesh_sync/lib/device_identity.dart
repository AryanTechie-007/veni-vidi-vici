// The three things that must survive a restart: who this device is, how many
// messages it has sent, and which role it is playing.

import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

enum MeshRole {
  victim('C', 'Victim'),
  responder('R', 'Responder');

  const MeshRole(this.code, this.label);

  /// Prefix in the advertised endpoint name, so a peer can see the role
  /// before connecting.
  final String code;

  final String label;
}

const String _kOrigin = 'mesh.origin';
const String _kSeq = 'mesh.seq';
const String _kRole = 'mesh.role';
const String _kUsername = 'mesh.username';

/// Persisted device identity.
///
/// [seq] is the load-bearing part. Message ids are `hash(origin + seq)`, so if
/// the counter ever restarts at 1 for an origin that has sent before, the
/// regenerated ids collide with old ones and real messages are silently
/// dropped as duplicates — with no error surfaced anywhere.
class DeviceIdentity {
  DeviceIdentity._(
      this._prefs, this.origin, this._role, this._seq, this._username);

  final SharedPreferences _prefs;

  /// Stands in for the Firebase UID until auth is wired up. Minted once.
  final String origin;

  int _seq;
  MeshRole _role;
  String? _username;

  int get seq => _seq;
  MeshRole get role => _role;

  /// Null when signed out.
  String? get username => _username;

  static Future<DeviceIdentity> load() async {
    final prefs = await SharedPreferences.getInstance();

    var origin = prefs.getString(_kOrigin);
    if (origin == null) {
      origin = _mintOrigin();
      await prefs.setString(_kOrigin, origin);
    }

    return DeviceIdentity._(
      prefs,
      origin,
      MeshRole.values.firstWhere(
        (r) => r.name == prefs.getString(_kRole),
        orElse: () => MeshRole.victim,
      ),
      prefs.getInt(_kSeq) ?? 0,
      prefs.getString(_kUsername),
    );
  }

  /// Records the counter. Called on every increment, before the message goes
  /// anywhere.
  Future<void> saveSeq(int value) async {
    _seq = value;
    await _prefs.setInt(_kSeq, value);
  }

  Future<void> saveRole(MeshRole value) async {
    _role = value;
    await _prefs.setString(_kRole, value.name);
  }

  Future<void> signIn(String username, MeshRole role) async {
    _username = username;
    await _prefs.setString(_kUsername, username);
    await saveRole(role);
  }

  /// Clears the session only.
  ///
  /// [origin] and [seq] are deliberately left alone: they are this device's
  /// message identity, and resetting the counter would make new messages reuse
  /// the ids of old ones, which the mesh would silently drop as duplicates.
  Future<void> signOut() async {
    _username = null;
    await _prefs.remove(_kUsername);
  }

  static String _mintOrigin() {
    final rng = Random.secure();
    return List.generate(16, (_) => rng.nextInt(16).toRadixString(16)).join();
  }
}
