import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../mesh_app.dart';
import '../messages/mesh_message.dart';

/// One incident in full, with the actions a responder can take on it.
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
    final loc = core.loc;
    final updates = app.updatesFor(message.id);
    final replies = app.repliesFor(message.id);

    return Scaffold(
      appBar: AppBar(
        title: Text('SOS ${core.id.substring(0, 6)}'),
        centerTitle: true,
        actions: [
          Center(child: _StateChip(state: state)),
          // Closing is destructive and rare, so it lives behind the menu
          // rather than competing with the two primary actions.
          PopupMenuButton<void>(
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: state != IncidentState.closed,
                onTap: () => _confirmClose(context),
                child: const Text('Close incident'),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _Card(
            children: [
              _Row(
                icon: Icons.access_time,
                label: core.cat?.label ?? 'Unknown',
                trailing: _elapsed(core.ts),
              ),
              const SizedBox(height: 14),
              _Row(
                icon: Icons.place_outlined,
                label: loc == null
                    ? 'No location attached'
                    : '${loc.lat.toStringAsFixed(4)}, '
                          '${loc.lon.toStringAsFixed(4)}',
                trailing: loc == null ? null : 'View on Map',
                onTrailingTap: loc == null ? null : () => _openMap(loc),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _Card(
            children: [
              Text(
                'Details',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                core.txt ?? 'No description given',
                style: core.txt == null
                    ? theme.textTheme.bodyLarge?.copyWith(
                        color: theme.hintColor,
                      )
                    : theme.textTheme.bodyLarge,
              ),
              const Divider(height: 28),
              IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: _Stat(
                        label: 'People Affected',
                        value: '${core.n ?? '—'}',
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _Stat(label: 'Status', value: _stateLabel(state)),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (updates.isNotEmpty) ...[
            const SizedBox(height: 16),
            _UpdatesCard(updates: updates),
          ],
          if (replies.isNotEmpty) ...[
            const SizedBox(height: 16),
            _RepliesCard(replies: replies),
          ],

          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  // A responder device already ACKs on receipt, so the useful
                  // action here is a written reply: a person saying they have
                  // read it, which a device receipt cannot mean.
                  onPressed: state == IncidentState.closed
                      ? null
                      : () => _reply(context),
                  icon: const Icon(Icons.check),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  label: const Text('Reply'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: loc == null ? null : () => _openMap(loc),
                  icon: const Icon(Icons.navigation),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  label: const Text('Navigate'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Hands the coordinates to whatever maps app is installed.
  ///
  /// This is the one place the app wants the internet, and it is also the one
  /// place it does not matter: a responder either has coverage here or does
  /// not, and the incident is readable either way.
  Future<void> _openMap(GeoPoint loc) async {
    final uri = Uri.parse('geo:${loc.lat},${loc.lon}?q=${loc.lat},${loc.lon}');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await launchUrl(
        Uri.parse(
          'https://www.google.com/maps/search/?api=1'
          '&query=${loc.lat},${loc.lon}',
        ),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  /// Sends a written acknowledgement. Travels as an ordinary ACK.
  Future<void> _reply(BuildContext context) async {
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _ReplySheet(),
    );
    if (text == null || text.isEmpty) return;
    await app.acknowledge(message.id, txt: text);
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

class _UpdatesCard extends StatelessWidget {
  const _UpdatesCard({required this.updates});

  final List<IncidentUpdate> updates;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Card(
      children: [
        Text(
          'Sender updates',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        // Newest first: the current situation matters more than the history.
        for (final update in updates.reversed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_iconFor(update.status), size: 18, color: theme.hintColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        update.status?.label ?? 'Unrecognised status',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (update.text != null) Text(update.text!),
                      Text(
                        _elapsed(update.ts),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static IconData _iconFor(UpdateStatus? status) => switch (status) {
    UpdateStatus.stillHere => Icons.hourglass_empty,
    UpdateStatus.worse => Icons.trending_down,
    UpdateStatus.better => Icons.trending_up,
    UpdateStatus.moved => Icons.directions_walk,
    null => Icons.help_outline,
  };
}

class _RepliesCard extends StatelessWidget {
  const _RepliesCard({required this.replies});

  final List<ResponderReply> replies;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Card(
      children: [
        Text(
          'Responder replies',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        for (final reply in replies)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reply.text, style: theme.textTheme.bodyLarge),
                Text(
                  _elapsed(reply.ts),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ReplySheet extends StatefulWidget {
  const _ReplySheet();

  @override
  State<_ReplySheet> createState() => _ReplySheetState();
}

class _ReplySheetState extends State<_ReplySheet> {
  final TextEditingController _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reply to this incident',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Floods to every device, so the sender sees it even without a '
            'direct link to you.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            autofocus: true,
            maxLength: kMaxTextLength,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Help is on the way, stay where you are',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, _text.text.trim()),
              child: const Text('Send reply'),
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
  const _Row({
    required this.icon,
    required this.label,
    this.trailing,
    this.onTrailingTap,
  });

  final IconData icon;
  final String label;
  final String? trailing;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.hintColor),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
        if (trailing != null)
          onTrailingTap == null
              ? Text(
                  trailing!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                )
              : TextButton(onPressed: onTrailingTap, child: Text(trailing!)),
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
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
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
