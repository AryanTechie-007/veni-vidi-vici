import 'package:flutter/material.dart';
import '../../mesh_app.dart';
import '../theme/mesh_theme.dart';

/// Modal bottom sheet displaying active mesh peer nodes in direct radio range.
class PeersSheet extends StatelessWidget {
  const PeersSheet({super.key, required this.app});

  final MeshApp app;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final peers = app.service.peers;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Direct Radio Peers',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${peers.length} active node${peers.length == 1 ? '' : 's'} in peer cluster',
                    style: TextStyle(fontSize: 12, color: isDark ? MeshTheme.darkTextMuted : MeshTheme.lightTextMuted),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (peers.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Text(
                'No peer devices currently in direct radio range. Searching nearby frequencies...',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: isDark ? MeshTheme.darkTextMuted : MeshTheme.lightTextMuted),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: peers.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final peer = peers[i];
                  final isResponder = peer.name.startsWith('R|');
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.cardTheme.color,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              peer.name,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Endpoint ID: ${peer.endpointId}',
                              style: TextStyle(fontSize: 11, color: isDark ? MeshTheme.darkTextMuted : MeshTheme.lightTextMuted),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isResponder ? MeshTheme.emergencyRed.withValues(alpha: 0.15) : theme.dividerColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isResponder ? 'RESPONDER' : 'CITIZEN',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isResponder ? MeshTheme.emergencyRed : theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
