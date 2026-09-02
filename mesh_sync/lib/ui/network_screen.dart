import 'package:flutter/material.dart';

import '../mesh_app.dart';
import '../messages/mesh_message.dart';
import 'category_style.dart';

/// What the radio is doing, and what this device is carrying for other people.
///
/// The relayed list is the point: it is the only place the store-and-forward
/// mechanism becomes visible. Every row is somebody else's message that this
/// phone accepted, is holding, and will hand to the next device it meets — and
/// the hop count shows how far it has already travelled to get here.
class NetworkScreen extends StatelessWidget {
  const NetworkScreen({super.key, required this.app});

  final MeshApp app;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([app, app.service]),
      builder: (context, _) {
        final service = app.service;
        final carried = app.carriedForOthers;

        return Scaffold(
          appBar: AppBar(title: const Text('Network'), centerTitle: true),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _StatusBanner(app: app),
              const SizedBox(height: 20),

              _Heading('Connected peers', count: service.peers.length),
              if (service.peers.isEmpty)
                const _Empty('No devices in range')
              else
                for (final peer in service.peers)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.smartphone),
                    title: Text(peer.name),
                    subtitle: const Text('Connected'),
                    trailing: Icon(
                      Icons.circle,
                      size: 10,
                      color: Colors.green.shade600,
                    ),
                  ),

              const SizedBox(height: 20),
              _Heading('Carried for others', count: carried.length),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Messages from people this device has never met, held until '
                  'it meets someone who can take them further.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (carried.isEmpty)
                const _Empty('Nothing being carried yet')
              else
                for (final message in carried) _CarriedRow(message: message),
            ],
          ),
        );
      },
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.app});

  final MeshApp app;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = app.service;
    final active = service.isRunning;
    final peers = service.peers.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: active
            ? Colors.green.shade50
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            active ? Icons.wifi_tethering : Icons.wifi_tethering_off,
            size: 32,
            color: active ? Colors.green.shade700 : theme.hintColor,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  active ? 'Mesh network active' : 'Mesh network off',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: active ? Colors.green.shade800 : null,
                  ),
                ),
                Text(
                  active
                      ? '$peers peer${peers == 1 ? '' : 's'} connected · '
                            'advertising as ${service.nickname}'
                      : 'Not advertising or discovering',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: active ? service.stop : service.start,
            child: Text(active ? 'Stop' : 'Start'),
          ),
        ],
      ),
    );
  }
}

/// One message being relayed on somebody else's behalf.
class _CarriedRow extends StatelessWidget {
  const _CarriedRow({required this.message});

  final MeshMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final core = message.core;
    final hops = message.env.hops;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: categoryColor(
              core.cat,
              theme,
            ).withValues(alpha: 0.15),
            child: Icon(
              _iconFor(core.type, core.cat),
              size: 16,
              color: categoryColor(core.cat, theme),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${core.typeWire} ${core.id.substring(0, 6)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'from ${core.origin.substring(0, 6)} · ${_elapsed(core.ts)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ],
            ),
          ),
          // The hop count is the whole story: this message reached here by
          // passing through that many other phones.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$hops hop${hops == 1 ? '' : 's'}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static IconData _iconFor(MessageType type, Category? cat) => switch (type) {
    MessageType.sos => categoryIcon(cat),
    MessageType.ack => Icons.check,
    MessageType.cancel => Icons.task_alt,
    MessageType.update => Icons.autorenew,
    MessageType.unknown => Icons.help_outline,
  };
}

class _Heading extends StatelessWidget {
  const _Heading(this.text, {required this.count});

  final String text;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            text,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
      ),
    );
  }
}

String _elapsed(int unixSeconds) {
  final seconds = DateTime.now().millisecondsSinceEpoch ~/ 1000 - unixSeconds;
  if (seconds < 60) return '${seconds}s ago';
  if (seconds < 3600) return '${seconds ~/ 60} min ago';
  return '${seconds ~/ 3600} h ago';
}
