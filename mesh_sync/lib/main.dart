// MeshSync — offline SOS relay over Google Nearby Connections, P2P_CLUSTER.
//
// This file is UI only. The radio lives in mesh_service.dart, the propagation
// rules in messages/mesh_router.dart, and mesh_app.dart wires them together.

import 'package:flutter/material.dart';

import 'device_identity.dart';
import 'mesh_app.dart';
import 'ui/log_view.dart';
import 'ui/responder_screen.dart';
import 'ui/victim_screen.dart';

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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('MeshSync'),
          backgroundColor: theme.colorScheme.inversePrimary,
          bottom: const TabBar(
            tabs: [Tab(text: 'Mesh'), Tab(text: 'Log')],
          ),
        ),
        // One builder covers both notifiers: the coordinator for messages and
        // role, the service for connection and log changes.
        body: ListenableBuilder(
          listenable: Listenable.merge([_app, _app.service]),
          builder: (context, _) => TabBarView(
            children: [
              Column(
                children: [
                  _StatusBar(app: _app),
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

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.app});

  final MeshApp app;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = app.service;
    final peers = service.peers.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<MeshRole>(
            segments: const [
              ButtonSegment(
                value: MeshRole.victim,
                label: Text('Victim'),
                icon: Icon(Icons.person_outline),
              ),
              ButtonSegment(
                value: MeshRole.responder,
                label: Text('Responder'),
                icon: Icon(Icons.medical_services_outlined),
              ),
            ],
            selected: {app.role},
            onSelectionChanged: (selection) => app.setRole(selection.first),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _StatusDot(active: service.isRunning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${service.nickname}'
                  ' · ${service.isRunning ? 'advertising + discovering' : 'idle'}'
                  ' · $peers peer${peers == 1 ? '' : 's'}'
                  '${service.pendingCount == 0 ? '' : ' · ${service.pendingCount} pending'}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
          if (!service.gpsEnabled)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Location services are off. Nearby will connect unreliably or '
                'not at all until you turn GPS on.',
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton(
                onPressed: service.requestPermissions,
                child: const Text('Permissions'),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: service.isRunning ? service.stop : service.start,
                child: Text(service.isRunning ? 'Stop' : 'Start mesh'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? Colors.green : Colors.grey,
      ),
    );
  }
}
