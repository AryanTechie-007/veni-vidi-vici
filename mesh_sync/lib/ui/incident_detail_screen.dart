import 'package:flutter/material.dart';

import '../mesh_app.dart';
import '../messages/mesh_message.dart';

/// One incident in full, with the two actions a responder can take on it.
class IncidentDetailScreen extends StatelessWidget {
  const IncidentDetailScreen({
    super.key,
    required this.app,
    required this.messageId,
  });

  final MeshApp app;
  final String messageId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        // Held by id rather than by value: a CANCEL can purge it while this
        // page is open, and an ACK changes its state underneath us.
        final message = app.messageById(messageId);
        if (message == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Incident')),
            body: const Center(child: Text('This incident is no longer held')),
          );
        }
        return _Detail(app: app, message: message);
      },
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.app, required this.message});

  final MeshApp app;
  final MeshMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final core = message.core;
    final state = app.stateOf(message.id);
    final closed = state == IncidentState.closed;

    return Scaffold(
      appBar: AppBar(
        title: Text('SOS ${core.id.substring(0, 6)}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(child: _StateChip(state: state)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _Card(
            children: [
              _Row(
                icon: Icons.category_outlined,
                label: core.cat?.wire ?? 'UNKNOWN',
                trailing: _elapsed(core.ts),
              ),
              const Divider(height: 20),
              _Row(
                icon: Icons.place_outlined,
                label: core.loc == null
                    ? 'No location attached'
                    : '${core.loc!.lat.toStringAsFixed(4)}, '
                          '${core.loc!.lon.toStringAsFixed(4)}',
                trailing: core.loc?.acc == null
                    ? null
                    : '±${core.loc!.acc!.round()} m',
              ),
              const Divider(height: 20),
              _Row(
                icon: Icons.route_outlined,
                label:
                    '${message.env.hops} hop'
                    '${message.env.hops == 1 ? '' : 's'} away',
                // hops is diagnostic only — nothing is dropped for travelling
                // far, but it hints at how distant the sender is.
                trailing: 'relay depth',
              ),
            ],
          ),
          const SizedBox(height: 16),

          _Card(
            children: [
              Text('Details', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Text(
                core.txt ?? 'No description given',
                style: core.txt == null
                    ? theme.textTheme.bodyMedium?.copyWith(
                        color: theme.hintColor,
                      )
                    : theme.textTheme.bodyLarge,
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _Stat(
                      label: 'People affected',
                      value: '${core.n ?? '—'}',
                    ),
                  ),
                  Expanded(
                    child: _Stat(label: 'Status', value: _stateLabel(state)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          _Card(
            children: [
              Text('Sender', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              // Until the responder directory is pre-cached, a UID is all there
              // is — there is no name to resolve it to offline.
              SelectableText(core.origin, style: theme.textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(
                'Message ${core.id} · seq ${core.seq}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          if (closed)
            const _ClosedNotice()
          else
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: state == IncidentState.acknowledged
                        ? null
                        : () => app.acknowledge(message.id),
                    icon: const Icon(Icons.check),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    label: Text(
                      state == IncidentState.acknowledged
                          ? 'Acknowledged'
                          : 'Acknowledge',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmClose(context),
                    icon: const Icon(Icons.task_alt),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    label: const Text('Close'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// Closing floods a CANCEL that purges the incident from every device that
  /// receives it, so it is confirmed rather than a single tap.
  Future<void> _confirmClose(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close this incident?'),
        content: const Text(
          'A CANCEL floods to every device in the mesh and deletes this '
          'incident from their storage. It cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep open'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Close incident'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await app.cancel(message.id, CancelReason.rescued);
    }
  }
}

class _ClosedNotice extends StatelessWidget {
  const _ClosedNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.task_alt, color: theme.hintColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Closed. This device kept a record, but the incident was purged '
              'from the mesh and will not be accepted again.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.state});

  final IncidentState state;

  @override
  Widget build(BuildContext context) {
    final (Color background, Color foreground) = switch (state) {
      IncidentState.open => (Colors.red.shade100, Colors.red.shade900),
      IncidentState.acknowledged => (
        Colors.green.shade100,
        Colors.green.shade900,
      ),
      IncidentState.closed => (
        Theme.of(context).colorScheme.surfaceContainerHighest,
        Theme.of(context).hintColor,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _stateLabel(state).toUpperCase(),
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, this.trailing});

  final IconData icon;
  final String label;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.hintColor),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
        if (trailing != null)
          Text(
            trailing!,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
        ),
        const SizedBox(height: 4),
        Text(value, style: theme.textTheme.headlineSmall),
      ],
    );
  }
}

String _stateLabel(IncidentState state) => switch (state) {
  IncidentState.open => 'Active',
  IncidentState.acknowledged => 'Acknowledged',
  IncidentState.closed => 'Closed',
};

String _elapsed(int unixSeconds) {
  final seconds = DateTime.now().millisecondsSinceEpoch ~/ 1000 - unixSeconds;
  if (seconds < 60) return '${seconds}s ago';
  if (seconds < 3600) return '${seconds ~/ 60} min ago';
  return '${seconds ~/ 3600} h ago';
}
