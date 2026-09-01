import 'package:flutter/material.dart';
import '../../mesh_app.dart';

/// Modal bottom sheet displaying active mesh peer nodes in direct radio range.
class PeersSheet extends StatelessWidget {
  const PeersSheet({super.key, required this.app});

  final MeshApp app;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final peers = app.service.peers;

    return Container(
      padding: const EdgeInsets.all(20),
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
                    'Connected Mesh Nodes',
                    style: TextStyle(fontFamily: 'Arial', fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${peers.length} reachable devices in direct radio range',
                    style: TextStyle(fontFamily: 'Arial', fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, size: 18),
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
              child: const Text(
                'No peer devices currently in direct range. Searching...',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Arial', fontSize: 12),
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
                              style: const TextStyle(fontFamily: 'Arial', fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              'Endpoint: ${peer.endpointId}',
                              style: TextStyle(fontFamily: 'Arial', fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isResponder ? Colors.red.withValues(alpha: 0.1) : theme.dividerColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isResponder ? 'RESPONDER' : 'CITIZEN',
                            style: TextStyle(
                              fontFamily: 'Arial',
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isResponder ? Colors.red : theme.colorScheme.onSurface,
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
