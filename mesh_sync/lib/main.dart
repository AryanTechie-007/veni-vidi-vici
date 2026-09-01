// MeshSync — offline SOS relay over Google Nearby Connections, P2P_CLUSTER.
//
// This file is UI only. The radio lives in mesh_service.dart, the propagation
// rules in messages/mesh_router.dart, and mesh_app.dart wires them together.

import 'package:flutter/material.dart';

import 'device_identity.dart';
import 'mesh_app.dart';
import 'ui/auth_screen.dart';
import 'ui/responder_screen.dart';
import 'ui/theme/mesh_theme.dart';
import 'ui/victim_screen.dart';
import 'ui/widgets/peers_sheet.dart';

// Global theme mode notifier for Dark / Light mode switching
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final app = await MeshApp.create();
  runApp(MeshSyncApp(app: app));
}

class MeshSyncApp extends StatelessWidget {
  const MeshSyncApp({super.key, required this.app});

  final MeshApp app;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'MeshSync',
          debugShowCheckedModeBanner: false,
          theme: MeshTheme.lightTheme,
          darkTheme: MeshTheme.darkTheme,
          themeMode: currentMode,
          home: MeshRootController(app: app),
        );
      },
    );
  }
}

class MeshRootController extends StatefulWidget {
  const MeshRootController({super.key, required this.app});

  final MeshApp app;

  @override
  State<MeshRootController> createState() => _MeshRootControllerState();
}

class _MeshRootControllerState extends State<MeshRootController> {
  bool _isAuthenticated = false;
  String _userName = '';
  String _userIdentifier = '';

  MeshApp get _app => widget.app;

  void _onLogin(MeshRole role, String name, String id) async {
    await _app.setRole(role);
    setState(() {
      _userName = name;
      _userIdentifier = id;
      _isAuthenticated = true;
    });
  }

  void _onLogout() {
    setState(() {
      _isAuthenticated = false;
      _userName = '';
      _userIdentifier = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthenticated) {
      return AuthScreen(onAuthenticated: _onLogin);
    }
    return MeshHomePage(
      app: _app,
      userName: _userName,
      userIdentifier: _userIdentifier,
      onLogout: _onLogout,
    );
  }
}

class MeshHomePage extends StatefulWidget {
  const MeshHomePage({
    super.key,
    required this.app,
    required this.userName,
    required this.userIdentifier,
    required this.onLogout,
  });

  final MeshApp app;
  final String userName;
  final String userIdentifier;
  final VoidCallback onLogout;

  @override
  State<MeshHomePage> createState() => _MeshHomePageState();
}

class _MeshHomePageState extends State<MeshHomePage> {
  MeshApp get _app => widget.app;

  @override
  void dispose() {
    _app.dispose();
    super.dispose();
  }

  void _showPeersSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => PeersSheet(app: _app),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isResponder = _app.role == MeshRole.responder;
    final service = _app.service;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isResponder ? 'SAR Command Portal' : 'Citizen Emergency Portal',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isResponder ? theme.colorScheme.onSurface : MeshTheme.emergencyRed,
              ),
            ),
            Text(
              '${widget.userName.isNotEmpty ? widget.userName : "User"} · ${widget.userIdentifier}',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? MeshTheme.darkTextMuted : MeshTheme.lightTextMuted,
              ),
            ),
          ],
        ),
        actions: [
          // Theme Toggle Button
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              size: 20,
            ),
            tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            onPressed: () {
              themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
            },
          ),
          // Peers Pill
          ListenableBuilder(
            listenable: service,
            builder: (context, _) {
              final peers = service.peers.length;
              return OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: _showPeersSheet,
                child: Text('$peers Peer${peers == 1 ? '' : 's'}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              );
            },
          ),
          // Logout Button
          IconButton(
            icon: const Icon(Icons.logout, size: 18),
            tooltip: 'Sign Out',
            onPressed: widget.onLogout,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([_app, _app.service]),
        builder: (context, _) {
          return Column(
            children: [
              if (!service.gpsEnabled)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: MeshTheme.emergencyRed),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_off_outlined, color: MeshTheme.emergencyRed, size: 18),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Location services off. Nearby requires GPS to connect.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      TextButton(
                        onPressed: service.requestPermissions,
                        child: const Text('Enable', style: TextStyle(fontWeight: FontWeight.w700, color: MeshTheme.emergencyRed)),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: isResponder
                    ? ResponderScreen(app: _app)
                    : VictimScreen(app: _app),
              ),
            ],
          );
        },
      ),
    );
  }
}
