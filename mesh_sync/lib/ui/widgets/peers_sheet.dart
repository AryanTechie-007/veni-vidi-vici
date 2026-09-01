import 'package:flutter/material.dart';
import '../../mesh_app.dart';
import '../../mesh_service.dart';
import '../theme/mesh_theme.dart';

/// Modal bottom sheet displaying active mesh peer nodes in direct radio range.
class PeersSheet extends StatelessWidget {
  const PeersSheet({super.key, required this.app});

  final MeshApp app;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final peers = app.service.peers;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: MeshTheme.meshCyan.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.hub_rounded, color: MeshTheme.meshCyan, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connected Mesh Nodes',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${peers.length} directly reachable peer${peers.length == 1 ? '' : 's'} via P2P Cluster',
                      style: theme.textTheme.bodySmall?.copyWith(color: MeshTheme.darkTextDim),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (peers.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: MeshTheme.darkSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: MeshTheme.darkCardBorder),
              ),
              child: Column(
                children: [
                  Icon(Icons.wifi_tethering_off_rounded, size: 40, color: MeshTheme.darkMuted),
                  const SizedBox(height: 12),
                  const Text(
                    'No Devices in Direct Range',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your device is actively advertising and discovering. Any nearby phone with MeshSync will pair automatically.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: MeshTheme.darkTextDim, fontSize: 13),
                  ),
                ],
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
                      color: MeshTheme.darkSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isResponder
                            ? MeshTheme.catMedical.withValues(alpha: 0.4)
                            : MeshTheme.meshCyan.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: isResponder
                              ? MeshTheme.catMedical.withValues(alpha: 0.2)
                              : MeshTheme.meshCyan.withValues(alpha: 0.2),
                          child: Icon(
                            isResponder ? Icons.medical_services_rounded : Icons.phone_android_rounded,
                            color: isResponder ? MeshTheme.catMedical : MeshTheme.meshCyan,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    peer.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isResponder
                                          ? MeshTheme.catMedical.withValues(alpha: 0.2)
                                          : MeshTheme.darkCardBorder,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isResponder ? 'RESPONDER' : 'CITIZEN / RELAY',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isResponder ? MeshTheme.catMedical : MeshTheme.darkTextDim,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Endpoint: ${peer.endpointId} · Direct P2P link active',
                                style: const TextStyle(fontSize: 12, color: MeshTheme.darkMuted),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: MeshTheme.ackGreen,
                            boxShadow: [
                              BoxShadow(
                                color: MeshTheme.ackGreenGlow,
                                blurRadius: 6,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MeshTheme.darkSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 18, color: MeshTheme.meshCyan),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Store-and-forward relay: Packets hop seamlessly between nearby devices even if destination is miles away.',
                    style: TextStyle(fontSize: 12, color: MeshTheme.darkTextDim),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
