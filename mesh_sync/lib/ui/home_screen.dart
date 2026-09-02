import 'package:flutter/material.dart';

import '../device_identity.dart';
import '../mesh_app.dart';
import '../messages/mesh_message.dart';
import 'mesh_status_card.dart';
import 'sos_sheet.dart';

/// One screen for both roles: mesh status, the SOS button, and the history of
/// everything this device holds.
///
/// Both roles relay identically — only the emphasis differs, so this is one
/// widget rather than two.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.app});

  final MeshApp app;

  Future<void> _compose(BuildContext context) async {
    final request = await showModalBottomSheet<SosRequest>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const SosSheet(),
    );
    if (request == null) return;

    final message = await app.sendSos(
      cat: request.cat,
      n: request.headcount,
      txt: request.text.isEmpty ? null : request.text,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('SOS ${message.id} created')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final responder = app.role == MeshRole.responder;
    // A responder's own alerts are rare; a victim's are the point. Show the
    // relevant set first, then everything else this device is carrying.
    final primary = responder ? app.incidents : app.myMessages;
    final secondary = responder ? app.myMessages : app.incidents;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        MeshStatusCard(app: app),
        const SizedBox(height: 16),
        _SosButton(onPressed: () => _compose(context)),
        const SizedBox(height: 24),
        _Section(
          title: responder ? 'Incidents received' : 'Your alerts',
          empty: responder ? 'No incidents received' : 'Nothing sent yet',
          messages: primary,
          app: app,
        ),
        const SizedBox(height: 8),
        _Section(
          title: responder ? 'Your alerts' : 'Carried from others',
          empty: responder
              ? 'You have not sent an alert'
              : 'Nothing received from other devices',
          messages: secondary,
          app: app,
        ),
      ],
    );
  }
}

class _SosButton extends StatelessWidget {
  const _SosButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 120,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: scheme.error,
          foregroundColor: scheme.onError,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sos, size: 44),
            SizedBox(height: 6),
            Text(
              'Send SOS',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 2),
            Text(
              'Shared with every device nearby',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.empty,
    required this.messages,
    required this.app,
  });

  final String title;
  final String empty;
  final List<MeshMessage> messages;
  final MeshApp app;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Text(title, style: theme.textTheme.titleSmall),
              const SizedBox(width: 6),
              if (messages.isNotEmpty)
                Text(
                  '${messages.length}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
            ],
          ),
        ),
        if (messages.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              empty,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor,
              ),
            ),
          )
        else
          for (final message in messages)
            IncidentTile(
              message: message,
              state: app.stateOf(message.id),
              peerCount: app.service.peers.length,
              mine: message.core.origin == app.origin,
              onClose: app.stateOf(message.id) == IncidentState.closed
                  ? null
                  : () => _confirmClose(context, message),
            ),
      ],
    );
  }

  /// Closing floods a CANCEL that purges the incident from every device that
  /// receives it, so it is confirmed rather than a single tap.
  Future<void> _confirmClose(BuildContext context, MeshMessage message) async {
    final mine = message.core.origin == app.origin;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(mine ? 'Mark yourself safe?' : 'Close this incident?'),
        content: Text(
          mine
              ? 'This tells every device in the mesh that you no longer need '
                    'help, and removes your alert from their storage.'
              : 'A CANCEL floods to every device in the mesh and deletes this '
                    'incident from their storage. It cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep open'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(mine ? 'I am safe' : 'Close incident'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await app.cancel(
        message.id,
        mine ? CancelReason.selfResolved : CancelReason.rescued,
      );
    }
  }
}

/// One incident, in whichever state this device believes it to be.
class IncidentTile extends StatelessWidget {
  const IncidentTile({
    super.key,
    required this.message,
    required this.state,
    required this.peerCount,
    required this.mine,
    required this.onClose,
  });

  final MeshMessage message;
  final IncidentState state;
  final int peerCount;
  final bool mine;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final core = message.core;
    final hops = message.env.hops;
    final closed = state == IncidentState.closed;

    // "Reached a responder" is the only state that means anything, and it is
    // styled unlike the rest: "relayed" guarantees nothing, and the copy must
    // not imply delivery.
    final (String status, Color color, IconData icon) = switch (state) {
      IncidentState.closed => ('Closed', theme.hintColor, Icons.task_alt),
      IncidentState.acknowledged => (
        mine ? 'Reached a responder' : 'Acknowledged',
        Colors.green.shade700,
        Icons.check_circle,
      ),
      IncidentState.open when mine && peerCount == 0 => (
        'Sending — no devices in range',
        theme.hintColor,
        Icons.radio_button_unchecked,
      ),
      IncidentState.open when mine => (
        'Relayed to $peerCount nearby device${peerCount == 1 ? '' : 's'}',
        theme.hintColor,
        Icons.wifi_tethering,
      ),
      IncidentState.open => (
        'Open',
        Colors.orange.shade800,
        Icons.error_outline,
      ),
    };

    return Opacity(
      opacity: closed ? 0.55 : 1,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: _colorFor(core.cat, theme),
          child: Text(
            '${core.n ?? '?'}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                core.txt ?? core.cat?.wire ?? 'SOS',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  decoration: closed ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(icon, size: 15, color: color),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              status,
              style: TextStyle(
                color: color,
                fontWeight: state == IncidentState.acknowledged
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
            Text(
              // Elapsed time is shown throughout so a long silence is visible
              // rather than ambiguous. hops is diagnostic only — nothing is
              // dropped for travelling far, but it hints at distance.
              '${_elapsed(core.ts)} · $hops hop${hops == 1 ? '' : 's'}'
              '${mine ? '' : ' · ${core.origin.substring(0, 6)}'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ],
        ),
        isThreeLine: true,
        trailing: onClose == null
            ? null
            : TextButton(
                onPressed: onClose,
                child: Text(mine ? 'I am safe' : 'Close'),
              ),
      ),
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
