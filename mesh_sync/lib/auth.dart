// Demo sign-in. Two fixed accounts; the username picks the role.
//
// This stands in for Firebase Auth, which will issue a real UID and carry the
// role on a server-side profile. Until then the credentials below are the
// whole of it.
//
// Signing out deliberately does NOT touch the device identity. `origin` and
// `seq` must survive it — message ids are hash(origin + seq), so resetting the
// counter would regenerate ids that collide with already-sent messages and the
// mesh would drop real traffic as duplicates.

import 'device_identity.dart';

class Account {
  const Account({required this.username, required this.role});

  final String username;
  final MeshRole role;
}

class Auth {
  const Auth._();

  static const Map<String, ({String password, MeshRole role})> _accounts = {
    'victim': (password: 'victim', role: MeshRole.victim),
    'responder': (password: 'responder', role: MeshRole.responder),
  };

  /// Returns the account for these credentials, or null if they do not match.
  static Account? verify(String username, String password) {
    final key = username.trim().toLowerCase();
    final entry = _accounts[key];
    if (entry == null || entry.password != password) return null;
    return Account(username: key, role: entry.role);
  }

  /// The role for an already-signed-in username, for restoring a session.
  static MeshRole? roleFor(String username) =>
      _accounts[username.trim().toLowerCase()]?.role;
}
