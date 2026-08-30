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
      itemBuilder: (context, i) => _IncidentTile(message: incidents[i]),
    );
  }
}

class _IncidentTile extends StatelessWidget {
  const _IncidentTile({required this.message});

  final MeshMessage message;

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
      title: Text(core.cat?.wire ?? 'UNKNOWN'),
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
    );
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
