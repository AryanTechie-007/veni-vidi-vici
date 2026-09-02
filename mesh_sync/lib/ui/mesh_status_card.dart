import 'package:flutter/material.dart';

import '../mesh_app.dart';

/// Mesh state and the switch to bring it up.
///
/// Shared because both roles need it: a responder that never starts the radio
/// receives nothing at all.
class MeshStatusCard extends StatelessWidget {
  const MeshStatusCard({super.key, required this.app});

  final MeshApp app;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = app.service;
    final peers = service.peers.length;
    final active = service.isRunning;

    final background = active
        ? Colors.green.shade700
        : theme.colorScheme.surfaceContainerHighest;
    final foreground = active ? Colors.white : theme.colorScheme.onSurface;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            active ? Icons.wifi_tethering : Icons.wifi_tethering_off,
            color: foreground,
            size: 32,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  active ? 'Mesh network active' : 'Mesh network off',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  active
                      ? '$peers peer${peers == 1 ? '' : 's'} nearby'
                            '${service.pendingCount == 0 ? '' : ' · ${service.pendingCount} connecting'}'
                      : 'Not advertising or discovering',
                  style: theme.textTheme.bodySmall?.copyWith(color: foreground),
                ),
              ],
            ),
          ),
          // Stopping matters as much as starting: the radio is the main
          // battery cost, and a user may want it off deliberately.
          active
              ? OutlinedButton(
                  onPressed: service.stop,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: foreground,
                    side: BorderSide(color: foreground.withValues(alpha: 0.6)),
                  ),
                  child: const Text('Stop'),
                )
              : FilledButton(
                  onPressed: service.start,
                  child: const Text('Start'),
                ),
        ],
      ),
    );
  }
}
