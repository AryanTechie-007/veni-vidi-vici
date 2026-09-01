// MeshSync — offline SOS relay over Google Nearby Connections, P2P_CLUSTER.
//
// This file is UI only. The radio lives in mesh_service.dart, the propagation
// rules in messages/mesh_router.dart, and mesh_app.dart wires them together.

import 'package:flutter/material.dart';

import 'device_identity.dart';
import 'mesh_app.dart';
import 'ui/log_view.dart';
import 'ui/responder_screen.dart';
import 'ui/theme/mesh_theme.dart';
import 'ui/victim_screen.dart';
import 'ui/widgets/peers_sheet.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Identity and the persisted seq counter must be loaded before anything can
  // create a message, so this happens up front rather than in initState.
  final app = await MeshApp.create();
  runApp(MeshSyncApp(app: app));
}

class MeshSyncApp extends StatelessWidget {
  const MeshSyncApp({super.key, required this.app});

  final MeshApp app;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MeshSync',
      debugShowCheckedModeBanner: false,
      theme: MeshTheme.darkTheme,
      home: MeshHomePage(app: app),
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
      backgroundColor: Colors.transparent,
      builder: (context) => PeersSheet(app: _app),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = _app.service;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: MeshTheme.meshCyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.emergency_rounded, color: MeshTheme.meshCyan, size: 22),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'MESHSYNC',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    'P2P Offline Emergency Relay',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            // Quick Peers Counter in AppBar
            ListenableBuilder(
              listenable: service,
              builder: (context, _) {
                final peers = service.peers.length;
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: ActionChip(
                    avatar: Icon(
                      Icons.hub_rounded,
                      size: 16,
                      color: peers > 0 ? MeshTheme.meshCyan : MeshTheme.darkTextDim,
                    ),
                    label: Text(
                      '$peers Peer${peers == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: peers > 0 ? MeshTheme.meshCyan : MeshTheme.darkTextDim,
                      ),
                    ),
                    onPressed: _showPeersSheet,
                  ),
                );
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.sensors_rounded, size: 20),
                text: 'Emergency Mesh',
              ),
              Tab(
                icon: Icon(Icons.terminal_rounded, size: 20),
                text: 'Tactical Log',
              ),
            ],
          ),
        ),
        body: ListenableBuilder(
          listenable: Listenable.merge([_app, _app.service]),
          builder: (context, _) => TabBarView(
            children: [
              Column(
                children: [
                  _TacticalStatusBar(app: _app, onShowPeers: _showPeersSheet),
                  const Divider(height: 1),
                  Expanded(
                    child: _app.role == MeshRole.responder
                        ? ResponderScreen(app: _app)
                        : VictimScreen(app: _app),
                  ),
                ],
              ),
              LogView(entries: _app.service.log),
            ],
          ),
        ),
      ),
    );
  }
}

class _TacticalStatusBar extends StatelessWidget {
  const _TacticalStatusBar({required this.app, required this.onShowPeers});

  final MeshApp app;
  final VoidCallback onShowPeers;

  @override
  Widget build(BuildContext context) {
    final service = app.service;
    final peers = service.peers.length;
    final isRunning = service.isRunning;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: MeshTheme.darkSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Role Selection Bar
          SegmentedButton<MeshRole>(
            segments: const [
              ButtonSegment(
                value: MeshRole.victim,
                label: Text('Victim / Citizen'),
                icon: Icon(Icons.person_pin_rounded, size: 18),
              ),
              ButtonSegment(
                value: MeshRole.responder,
                label: Text('Search & Rescue'),
                icon: Icon(Icons.medical_services_rounded, size: 18),
              ),
            ],
            selected: {app.role},
            onSelectionChanged: (selection) => app.setRole(selection.first),
          ),
          const SizedBox(height: 10),

          // Radio Status & Controls Container
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: MeshTheme.darkCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: MeshTheme.darkCardBorder),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _GlowStatusDot(active: isRunning),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                service.nickname,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  fontFamily: 'monospace',
                                  color: MeshTheme.meshCyan,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isRunning
                                      ? MeshTheme.ackGreen.withValues(alpha: 0.15)
                                      : MeshTheme.darkCardBorder,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isRunning ? 'ONLINE' : 'STANDBY',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isRunning ? MeshTheme.ackGreen : MeshTheme.darkTextDim,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isRunning
                                ? 'Advertising & Discovering · $peers in direct range'
                                : 'Mesh radio stopped',
                            style: const TextStyle(fontSize: 11, color: MeshTheme.darkTextDim),
                          ),
                        ],
                      ),
                    ),
                    // Start / Stop Radio Button
                    FilledButton(
                      onPressed: isRunning ? service.stop : service.start,
                      style: FilledButton.styleFrom(
                        backgroundColor: isRunning ? MeshTheme.catMedical : MeshTheme.meshTeal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isRunning ? 'Stop Radio' : 'Start Mesh',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (service.pendingCount > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(strokeWidth: 2, color: MeshTheme.meshCyan),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Handshaking with ${service.pendingCount} candidate peer...',
                        style: const TextStyle(fontSize: 11, color: MeshTheme.meshCyan),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // GPS / Location Warning Alert
          if (!service.gpsEnabled) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF451A03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: MeshTheme.catTrapped.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_off_rounded, color: MeshTheme.catTrapped, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Location / GPS is Turned Off',
                          style: TextStyle(
                            color: Color(0xFFFEF3C7),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Nearby Connections requires GPS to form offline radio links.',
                          style: TextStyle(color: Color(0xFFFDE68A), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: service.requestPermissions,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: MeshTheme.catTrapped,
                      side: const BorderSide(color: MeshTheme.catTrapped),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Fix GPS', style: TextStyle(fontSize: 11)),
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

class _GlowStatusDot extends StatelessWidget {
  const _GlowStatusDot({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? MeshTheme.ackGreen : MeshTheme.darkMuted,
        boxShadow: active
            ? [
                const BoxShadow(
                  color: MeshTheme.ackGreenGlow,
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
    );
  }
}
