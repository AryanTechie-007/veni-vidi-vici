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
                fontFamily: 'Georgia',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isResponder ? theme.colorScheme.onSurface : MeshTheme.terracottaRed,
              ),
            ),
            Text(
              '${widget.userName.isNotEmpty ? widget.userName : "User"} · ${widget.userIdentifier}',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 11,
                fontStyle: FontStyle.italic,
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
                child: Text('$peers Peer${peers == 1 ? '' : 's'}', style: const TextStyle(fontFamily: 'Georgia', fontSize: 11)),
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
        builder: (context, _) => Column(
          children: [
            _MinimalistStatusBar(app: _app, isResponder: isResponder),
            const Divider(height: 1),
            Expanded(
              child: isResponder
                  ? ResponderScreen(app: _app)
                  : VictimScreen(app: _app),
            ),
          ],
        ),
      ),
    );
  }
}

class _MinimalistStatusBar extends StatelessWidget {
  const _MinimalistStatusBar({required this.app, required this.isResponder});

  final MeshApp app;
  final bool isResponder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final service = app.service;
    final peers = service.peers.length;
    final isRunning = service.isRunning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      color: theme.scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Radio Status & Controls Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            service.nickname,
                            style: const TextStyle(
                              fontFamily: 'Georgia',
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isRunning ? MeshTheme.sageGreen : theme.dividerColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isRunning ? 'ONLINE' : 'OFFLINE',
                              style: const TextStyle(
                                fontFamily: 'Georgia',
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isRunning
                            ? 'Mesh radio active · $peers reachable peers'
                            : 'Radio idle',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 12,
                          color: isDark ? MeshTheme.darkTextMuted : MeshTheme.lightTextMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: isRunning ? service.stop : service.start,
                  style: FilledButton.styleFrom(
                    backgroundColor: isRunning ? MeshTheme.terracottaRed : theme.colorScheme.onSurface,
                    foregroundColor: isRunning ? Colors.white : theme.scaffoldBackgroundColor,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(
                    isRunning ? 'Stop Radio' : 'Start Radio',
                    style: const TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          if (!service.gpsEnabled) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: MeshTheme.terracottaRed),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_off_outlined, color: MeshTheme.terracottaRed, size: 18),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Location services off. Nearby Connections requires GPS to establish links.',
                      style: TextStyle(fontFamily: 'Georgia', fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: service.requestPermissions,
                    child: const Text('Enable', style: TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.bold, color: MeshTheme.terracottaRed)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
