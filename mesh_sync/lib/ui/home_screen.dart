import 'package:flutter/material.dart';

import '../mesh_app.dart';
import '../messages/mesh_message.dart';
import 'category_style.dart';
import 'incident_detail_screen.dart';
import 'mesh_status_card.dart';
import 'network_screen.dart';
import 'send_sos_screen.dart';

/// The victim's home.
///
/// Deliberately two different screens rather than one list. Before an alert
/// exists the only thing that matters is sending one; afterwards the only
/// thing that matters is whether anyone is coming. A list of rows answers
/// neither question well.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.app});

  final MeshApp app;

  Future<void> _compose(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (context) => SendSosScreen(app: app)));

  void _openNetwork(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (context) => NetworkScreen(app: app)));

  @override
  Widget build(BuildContext context) {
    final open = [
      for (final m in app.myMessages)
        if (app.stateOf(m.id) != IncidentState.closed) m,
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        MeshStatusCard(app: app, onTap: () => _openNetwork(context)),
        const SizedBox(height: 16),

        // The SOS button is always here. It shrinks once an alert is live so
        // the status can lead, but it never moves or disappears — it is the
        // one control someone must be able to find without looking.
        _SosButton(onPressed: () => _compose(context), large: open.isEmpty),

        if (open.isEmpty)
          const _Explainer()
        else ...[
          const SizedBox(height: 16),
          // Only the newest alert gets the full card. Stacking several is what
          // made this unreadable.
          _ActiveAlertCard(app: app, message: open.first),
          for (final message in open.skip(1)) ...[
            const SizedBox(height: 16),
            _ActiveAlertCard(app: app, message: message),
          ],
        ],
      ],
    );
  }
}

/// Always on screen, in one of two sizes.
class _SosButton extends StatelessWidget {
  const _SosButton({required this.onPressed, required this.large});

  final VoidCallback onPressed;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: large ? 180 : 74,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: scheme.error,
          foregroundColor: scheme.onError,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(large ? 24 : 16),
          ),
        ),
        child: large
            ? const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sos, size: 62),
                  SizedBox(height: 10),
                  Text(
                    'Send SOS',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sos, size: 30),
                  SizedBox(width: 12),
                  Text(
                    'Send another SOS',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
      ),
    );
  }
}

class _Explainer extends StatelessWidget {
  const _Explainer();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Text(
        'Works with no signal. Your alert hops phone to phone until it '
        'reaches a responder.',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
      ),
    );
  }
}

/// An alert that is still open. The status is the whole point of the card.
class _ActiveAlertCard extends StatelessWidget {
  const _ActiveAlertCard({required this.app, required this.message});

  final MeshApp app;
  final MeshMessage message;

  Future<void> _update(BuildContext context, UpdateStatus status) async {
    final wait = app.secondsUntilNextUpdate(message.id);
    if (wait > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You can update again in ${wait}s')),
      );
      return;
    }
    final sent = await app.sendUpdate(message.id, status: status);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sent ? 'Update sent: ${status.label}' : 'Update not sent',
        ),
      ),
    );
  }

  Future<void> _safe(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark yourself safe?'),
        content: const Text(
          'This tells every device in the mesh that you no longer need help, '
          'and removes your alert from their storage.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep open'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('I am safe'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await app.cancel(message.id, CancelReason.selfResolved);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = app.stateOf(message.id);
    final replies = app.repliesFor(message.id);
    final peers = app.service.peers.length;
    final acked = state == IncidentState.acknowledged;

    // "Reached a responder" is the only state that means anything. The others
    // are worded so they cannot be mistaken for delivery.
    final (String headline, String? detail, Color colour, IconData icon) = acked
        ? (
            'Reached a responder',
            // The headline already says it; a second sentence is padding.
            null,
            Colors.green.shade700,
            Icons.check_circle,
          )
        : peers == 0
        ? (
            'No devices in range',
            'Still trying — it goes out the moment a phone comes near.',
            theme.colorScheme.error,
            Icons.wifi_tethering_off,
          )
        : (
            'Relayed to $peers nearby device${peers == 1 ? '' : 's'}',
            'Passed on, not yet confirmed by a responder.',
            Colors.orange.shade800,
            Icons.wifi_tethering,
          );

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) =>
              IncidentDetailScreen(app: app, messageId: message.id),
        ),
      ),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colour.withValues(alpha: 0.08),
          border: Border.all(color: colour.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colour, size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headline,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colour,
                        ),
                      ),
                      // Elapsed time is shown prominently so a long silence is
                      // visible rather than ambiguous.
                      Text(
                        'Sent ${_elapsed(message.core.ts)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                // The whole card opens the full history; "Full history" as a
                // text button was too quiet to find.
                Icon(Icons.chevron_right, color: theme.hintColor),
              ],
            ),
            // Which emergency this is, so several open alerts can be told
            // apart at a glance rather than by their timestamps.
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: categoryColor(
                      message.core.cat,
                      theme,
                    ).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        categoryIcon(message.core.cat),
                        size: 14,
                        color: categoryColor(message.core.cat, theme),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        message.core.cat?.label ?? 'SOS',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: categoryColor(message.core.cat, theme),
                        ),
                      ),
                    ],
                  ),
                ),
                if (message.core.n != null) ...[
                  const SizedBox(width: 10),
                  Icon(Icons.groups_outlined, size: 15, color: theme.hintColor),
                  const SizedBox(width: 4),
                  Text(
                    '${message.core.n}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                ],
              ],
            ),
            if (message.core.txt != null) ...[
              const SizedBox(height: 8),
              Text(message.core.txt!, style: theme.textTheme.bodyLarge),
            ],
            if (detail != null) ...[
              const SizedBox(height: 10),
              Text(detail, style: theme.textTheme.bodyMedium),
            ],

            if (replies.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.reply,
                          size: 15,
                          color: Colors.green.shade700,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Responder said',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(replies.last.text, style: theme.textTheme.bodyLarge),
                  ],
                ),
              ),
            ],

            ...[
              const Divider(height: 28),
              Text(
                'Tell them how you are',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              // One tap, on the card. Someone one-handed under rubble is not
              // going to work through a button, a sheet and a chip.
              // A fixed 2x2 grid rather than a Wrap: four chips of differing
              // widths wrapped into three ragged rows, which was most of the
              // clutter on this card.
              for (var row = 0; row < 2; row++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      for (final status
                          in UpdateStatus.values.skip(row * 2).take(2))
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: status == UpdateStatus.values[row * 2]
                                  ? 8
                                  : 0,
                            ),
                            child: OutlinedButton.icon(
                              onPressed: () => _update(context, status),
                              icon: Icon(_iconFor(status), size: 16),
                              label: Text(status.shortLabel),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
              // Marking yourself safe ends the incident everywhere, so it gets a
              // real button rather than a low-contrast bit of text in a corner.
              OutlinedButton.icon(
                onPressed: () => _safe(context),
                icon: const Icon(Icons.check_circle_outline),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: Colors.green.shade800,
                  side: BorderSide(color: Colors.green.shade600),
                ),
                label: const Text(
                  'I am safe',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static IconData _iconFor(UpdateStatus status) => switch (status) {
    UpdateStatus.stillHere => Icons.hourglass_empty,
    UpdateStatus.worse => Icons.trending_down,
    UpdateStatus.better => Icons.trending_up,
    UpdateStatus.moved => Icons.directions_walk,
  };
}

String _elapsed(int unixSeconds) {
  final seconds = DateTime.now().millisecondsSinceEpoch ~/ 1000 - unixSeconds;
  if (seconds < 60) return '${seconds}s ago';
  if (seconds < 3600) return '${seconds ~/ 60} min ago';
  return '${seconds ~/ 3600} h ago';
}
