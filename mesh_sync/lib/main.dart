// MeshSync — a spike to prove out Google Nearby Connections in P2P_CLUSTER mode.
//
// This file is UI only. The transport lives in mesh_service.dart and is
// observed through a ChangeNotifier.

import 'package:flutter/material.dart';

import 'mesh_service.dart';

void main() => runApp(const MeshSyncApp());

class MeshSyncApp extends StatelessWidget {
  const MeshSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MeshSync',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const MeshHomePage(),
    );
  }
}

class MeshHomePage extends StatefulWidget {
  const MeshHomePage({super.key});

  @override
  State<MeshHomePage> createState() => _MeshHomePageState();
}

class _MeshHomePageState extends State<MeshHomePage> {
  final MeshService _mesh = MeshService();
  final TextEditingController _input = TextEditingController();

  @override
  void dispose() {
    _mesh.dispose();
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    final sent = await _mesh.sendText(text);
    // Keep the text if it went nowhere, so it isn't silently lost.
    if (sent > 0) _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('MeshSync'),
        backgroundColor: theme.colorScheme.inversePrimary,
      ),
      body: ListenableBuilder(
        listenable: _mesh,
        builder: (context, _) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  _StatusDot(active: _mesh.isRunning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_statusLine(), style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
            if (!_mesh.gpsEnabled)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  OutlinedButton(
                    onPressed: _mesh.requestPermissions,
                    child: const Text('Permissions'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _mesh.isRunning ? _mesh.stop : _mesh.start,
                    child: Text(_mesh.isRunning ? 'Stop' : 'Start mesh'),
                  ),
                ],
              ),
            ),
            if (_mesh.peers.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final peer in _mesh.peers)
                        Chip(
                          label: Text(peer.name),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ),
              ),
            const Divider(height: 20),
            Expanded(child: _buildLog()),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        onSubmitted: (_) => _send(),
                        textInputAction: TextInputAction.send,
                        decoration: const InputDecoration(
                          hintText: 'Message to broadcast',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _send,
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusLine() {
    final peers = _mesh.peers.length;
    final pending = _mesh.pendingCount;
    return '${_mesh.nickname}'
        ' · ${_mesh.isRunning ? 'advertising + discovering' : 'idle'}'
        ' · $peers peer${peers == 1 ? '' : 's'}'
        '${pending == 0 ? '' : ' · $pending pending'}';
  }

  Widget _buildLog() {
    final entries = _mesh.log;
    if (entries.isEmpty) {
      return const Center(child: Text('No activity yet'));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: entries.length,
      itemBuilder: (context, i) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          entries[i].toString(),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
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
