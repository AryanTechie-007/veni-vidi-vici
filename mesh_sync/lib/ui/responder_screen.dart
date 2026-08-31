import 'package:flutter/material.dart';

import '../mesh_app.dart';
import '../messages/mesh_message.dart';

/// Incidents received from other devices.
///
/// Both roles relay everything identically — only the view differs. Without
/// ACK yet, viewing an incident sends nothing back.
class ResponderScreen extends StatelessWidget {
  const ResponderScreen({super.key, required this.app});

  final MeshApp app;

  @override
  Widget build(BuildContext context) {
    final incidents = app.incidents;
    if (incidents.isEmpty) {
      return const Center(child: Text('No incidents received'));
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: incidents.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, i) => _IncidentTile(
        message: incidents[i],
        acked: app.isAcked(incidents[i].id),
        onClose: () => app.cancel(incidents[i].id, CancelReason.rescued),
      ),
    );
  }
}

class _IncidentTile extends StatelessWidget {
  const _IncidentTile({
    required this.message,
    required this.acked,
    required this.onClose,
  });

  final MeshMessage message;

  /// This device ACKs automatically on receipt, so this is normally true —
  /// it is shown so an unacknowledged incident stands out.
  final bool acked;

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final core = message.core;
    final hops = message.env.hops;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _colorFor(core.cat, theme),
        child: Text(
          '${core.n ?? '?'}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      title: Row(
        children: [
          Text(core.cat?.wire ?? 'UNKNOWN'),
          if (acked) ...[
            const SizedBox(width: 6),
            Icon(Icons.check_circle, size: 14, color: Colors.green.shade700),
          ],
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (core.txt != null) Text(core.txt!),
          Text(
            // hops is diagnostic only — nothing is dropped for travelling far,
            // but it tells a responder roughly how distant the sender is.
            '${_elapsed(core.ts)} · $hops hop${hops == 1 ? '' : 's'} · '
            '${core.origin.substring(0, 6)}',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ],
      ),
      isThreeLine: core.txt != null,
      trailing: TextButton(
        onPressed: () => _confirmClose(context),
        child: const Text('Close'),
      ),
    );
  }

  /// Closing an incident purges it from every device that receives the CANCEL,
  /// so it is confirmed rather than a single tap.
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
    if (confirmed == true) onClose();
  }

  static Color _colorFor(Category? cat, ThemeData theme) => switch (cat) {
        Category.medical => Colors.red.shade300,
        Category.trapped => Colors.orange.shade300,
        Category.fire => Colors.deepOrange.shade300,
        Category.supplies => Colors.blue.shade300,
        Category.safe => Colors.green.shade300,
        null => theme.disabledColor,
      };
}

String _elapsed(int unixSeconds) {
  final seconds = DateTime.now().millisecondsSinceEpoch ~/ 1000 - unixSeconds;
  if (seconds < 60) return '${seconds}s ago';
  if (seconds < 3600) return '${seconds ~/ 60} min ago';
  return '${seconds ~/ 3600} h ago';
}
