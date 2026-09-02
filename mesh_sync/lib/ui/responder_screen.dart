import 'package:flutter/material.dart';

import '../mesh_app.dart';
import '../messages/mesh_message.dart';
import 'category_style.dart';
import 'incident_detail_screen.dart';
import 'mesh_status_card.dart';

/// The responder's working view: how many incidents still need attention, and
/// the list to work through.
class ResponderScreen extends StatelessWidget {
  const ResponderScreen({super.key, required this.app});

  final MeshApp app;

  @override
  Widget build(BuildContext context) {
    final incidents = app.incidents;
    final active = [
      for (final m in incidents)
        if (app.stateOf(m.id) == IncidentState.open) m,
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        MeshStatusCard(app: app),
        const SizedBox(height: 16),
        _ActiveCard(count: active.length),
        const SizedBox(height: 20),
        if (incidents.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 48,
                  color: Theme.of(context).hintColor,
                ),
                const SizedBox(height: 12),
                Text(
                  'No incidents received',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Alerts appear here as they reach this device.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
                ),
              ],
            ),
          )
        else ...[
          Text('Nearby SOS', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          for (final message in incidents)
            _IncidentRow(
              message: message,
              state: app.stateOf(message.id),
              latestUpdate: app.updatesFor(message.id).lastOrNull,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      IncidentDetailScreen(app: app, messageId: message.id),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _ActiveCard extends StatelessWidget {
  const _ActiveCard({required this.count});

  /// Incidents nobody has acknowledged yet.
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quiet = count == 0;
    final background = quiet ? Colors.green.shade700 : theme.colorScheme.error;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quiet ? 'All clear' : 'Active SOS',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$count',
                      style: theme.textTheme.displayMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      quiet ? 'nothing waiting' : 'needs attention',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(
            quiet ? Icons.check_circle_outline : Icons.notifications_active,
            size: 52,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ],
      ),
    );
  }
}

class _IncidentRow extends StatelessWidget {
  const _IncidentRow({
    required this.message,
    required this.state,
    required this.latestUpdate,
    required this.onTap,
  });

  final MeshMessage message;
  final IncidentState state;

  /// The sender's most recent status change, if any. Shown instead of the
  /// category, since it is the more current fact.
  final IncidentUpdate? latestUpdate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final core = message.core;
    final closed = state == IncidentState.closed;

    return Opacity(
      opacity: closed ? 0.55 : 1,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 4),
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: categoryColor(core.cat, theme),
          child: Text(
            '${core.n ?? '?'}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          'SOS ${core.id.substring(0, 6)}',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration: closed ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${core.cat?.wire ?? 'UNKNOWN'} · ${_elapsed(core.ts)} · '
              '${message.env.hops} hop${message.env.hops == 1 ? '' : 's'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (latestUpdate != null)
              Text(
                '${latestUpdate!.status?.label ?? 'Update'} · '
                '${_elapsed(latestUpdate!.ts)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        isThreeLine: latestUpdate != null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state == IncidentState.acknowledged)
              Icon(Icons.check_circle, size: 16, color: Colors.green.shade700)
            else if (state == IncidentState.open)
              Icon(
                Icons.error_outline,
                size: 16,
                color: theme.colorScheme.error,
              ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, color: theme.hintColor),
          ],
        ),
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
