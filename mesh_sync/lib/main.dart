// MeshSync — offline SOS relay over Google Nearby Connections, P2P_CLUSTER.
//
// This file is UI only. The radio lives in mesh_service.dart, the propagation
// rules in messages/mesh_router.dart, and mesh_app.dart wires them together.

import 'package:flutter/material.dart';

import 'device_identity.dart';
import 'mesh_app.dart';
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
          home: MeshHomePage(app: app),
        );
      },
    );
  }
}

class MeshHomePage extends StatefulWidget {
  const MeshHomePage({super.key, required this.app});

  final MeshApp app;

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
    final service = _app.service;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: service.isRunning ? MeshTheme.safeGreen : MeshTheme.darkTextDim,
              ),
            ),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MESHSYNC',
                  style: TextStyle(
                    fontFamily: 'Arial',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                Text(
                  'Offline Emergency Relay',
                  style: TextStyle(
                    fontFamily: 'Arial',
                    fontSize: 11,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Dark / Light Mode Toggle Button
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
          // Peers Button
          ListenableBuilder(
            listenable: service,
            builder: (context, _) {
              final peers = service.peers.length;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: _showPeersSheet,
                  child: Text('$peers Peer${peers == 1 ? '' : 's'}'),
                ),
              );
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([_app, _app.service]),
        builder: (context, _) => Column(
          children: [
            _MinimalistStatusBar(app: _app),
            const Divider(height: 1),
            Expanded(
              child: _app.role == MeshRole.responder
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
  const _MinimalistStatusBar({required this.app});

  final MeshApp app;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = app.service;
    final peers = service.peers.length;
    final isRunning = service.isRunning;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: theme.scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Minimalist Role Switcher
          SegmentedButton<MeshRole>(
            segments: const [
              ButtonSegment(
                value: MeshRole.victim,
                label: Text('Victim / Citizen'),
                icon: Icon(Icons.person, size: 16),
              ),
              ButtonSegment(
                value: MeshRole.responder,
                label: Text('Search & Rescue'),
                icon: Icon(Icons.medical_services, size: 16),
              ),
            ],
            selected: {app.role},
            onSelectionChanged: (selection) => app.setRole(selection.first),
          ),
          const SizedBox(height: 10),

          // Radio Status & Controls Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(8),
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
                              fontFamily: 'Arial',
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isRunning ? MeshTheme.safeGreen : theme.dividerColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isRunning ? 'ONLINE' : 'OFFLINE',
                              style: const TextStyle(
                                fontFamily: 'Arial',
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isRunning
                            ? 'Advertising & Discovering · $peers in range'
                            : 'Radio idle',
                        style: TextStyle(
                          fontFamily: 'Arial',
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: isRunning ? service.stop : service.start,
                  style: FilledButton.styleFrom(
                    backgroundColor: isRunning ? MeshTheme.emergencyRed : theme.colorScheme.primary,
                    foregroundColor: isRunning ? Colors.white : theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(
                    isRunning ? 'Stop' : 'Start',
                    style: const TextStyle(fontFamily: 'Arial', fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          if (!service.gpsEnabled) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: MeshTheme.emergencyRed),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_off, color: MeshTheme.emergencyRed, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'GPS is off. Nearby requires location to connect.',
                      style: TextStyle(fontFamily: 'Arial', fontSize: 11),
                    ),
                  ),
                  TextButton(
                    onPressed: service.requestPermissions,
                    child: const Text('Fix', style: TextStyle(fontFamily: 'Arial', fontWeight: FontWeight.bold, color: MeshTheme.emergencyRed)),
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
