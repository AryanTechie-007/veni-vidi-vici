import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../mesh_app.dart';
import '../messages/mesh_message.dart';
import 'address_text.dart';
import 'category_style.dart';
import 'update_sheet.dart';

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
    final core = message.core;
    final state = app.stateOf(message.id);
    final loc = core.loc;
    final updates = app.updatesFor(message.id);
    final replies = app.repliesFor(message.id);
    final latest = updates.isEmpty ? null : updates.last;
    final mine = core.origin == app.origin;

    return Scaffold(
      appBar: AppBar(
        title: Text('SOS ${core.id.substring(0, 6)}'),
        centerTitle: true,
        actions: [Center(child: _StateChip(state: state))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // A deteriorating situation is the single most important fact on
          // this screen, so it goes above everything rather than four scrolls
          // down among the history.
          if (latest?.status == UpdateStatus.worse)
            _WorseBanner(update: latest!),

          _SituationCard(app: app, message: message),
          const SizedBox(height: 14),
          _LocationCard(
            app: app,
            message: message,
            onMap: () => _openMap(loc!),
          ),

          if (updates.isNotEmpty || replies.isNotEmpty) ...[
            const SizedBox(height: 14),
            _ActivityCard(
              updates: updates,
              replies: replies,
              origin: app.origin,
            ),
          ],
        ],
      ),
      // The action sits outside the scroll view so it is always reachable, and
      // inside a SafeArea so the gesture bar does not sit on top of it.
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Whose incident it is decides what the actions are: the sender
            // revises their own situation and marks themselves safe; everyone
            // else replies and closes. A responder device already ACKs on
            // receipt, so a written reply is the useful act — a person saying
            // they have read it, which a device receipt cannot mean.
            FilledButton.icon(
              onPressed: state == IncidentState.closed
                  ? null
                  : () => mine ? _postUpdate(context) : _reply(context),
              icon: Icon(mine ? Icons.autorenew : Icons.reply),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              label: Text(mine ? 'Post an update' : 'Reply'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: state == IncidentState.closed
                  ? null
                  : () => _confirmClose(context),
              icon: const Icon(Icons.check_circle_outline),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              label: Text(mine ? 'I am safe' : 'Close incident'),
            ),
          ],
        ),
      ),
    );
  }

  /// Hands the coordinates to whatever maps app is installed.
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

  /// The sender revising their own situation, with optional text. The
  /// one-tap chips on the home card cover the common case; this is the longer
  /// form.
  Future<void> _postUpdate(BuildContext context) async {
    final wait = app.secondsUntilNextUpdate(message.id);
    if (wait > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You can update again in ${wait}s')),
      );
      return;
    }
    final request = await showModalBottomSheet<UpdateRequest>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const UpdateSheet(),
    );
    if (request == null) return;
    await app.sendUpdate(
      message.id,
      status: request.status,
      txt: request.text.isEmpty ? null : request.text,
    );
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
        title: Text(
          message.core.origin == app.origin
              ? 'Mark yourself safe?'
              : 'Close this incident?',
        ),
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
      await app.cancel(
        message.id,
        message.core.origin == app.origin
            ? CancelReason.selfResolved
            : CancelReason.rescued,
      );
    }
  }
}

/// The loudest thing on the screen, because it is the most important.
class _WorseBanner extends StatelessWidget {
  const _WorseBanner({required this.update});

  final IncidentUpdate update;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.error,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.trending_down, color: scheme.onError),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Situation is getting worse',
                  style: TextStyle(
                    color: scheme.onError,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '${update.text == null ? '' : '${update.text} · '}'
                  '${_elapsed(update.ts)}',
                  style: TextStyle(color: scheme.onError, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Category, description and headcount — what a responder needs first.
class _SituationCard extends StatelessWidget {
  const _SituationCard({required this.app, required this.message});

  final MeshApp app;
  final MeshMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final core = message.core;
    final colour = categoryColor(core.cat, theme);
    final received = app.receivedAt(message.id);

    return _Card(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colour.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(categoryIcon(core.cat), color: colour, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    core.cat?.label ?? 'Unknown',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colour,
                    ),
                  ),
                  // core.ts is the sender's clock, which the spec calls
                  // unreliable offline — so say which clock each time is from.
                  Text(
                    'Sent ${_elapsed(core.ts)}'
                    '${received == null ? '' : ' · received ${_since(received)}'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          core.txt ?? 'No description given',
          style: core.txt == null
              ? theme.textTheme.bodyLarge?.copyWith(color: theme.hintColor)
              : theme.textTheme.bodyLarge,
        ),
        const Divider(height: 26),
        Row(
          children: [
            Icon(Icons.groups_outlined, size: 20, color: theme.hintColor),
            const SizedBox(width: 10),
            Text('People affected', style: theme.textTheme.bodyMedium),
            const Spacer(),
            Text(
              '${core.n ?? '—'}',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.app,
    required this.message,
    required this.onMap,
  });

  final MeshApp app;
  final MeshMessage message;
  final VoidCallback onMap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = message.core.loc;
    final hops = message.env.hops;

    return _Card(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.place_outlined, size: 20, color: theme.hintColor),
            const SizedBox(width: 12),
            Expanded(
              child: loc == null
                  ? Text(
                      'No location attached',
                      style: theme.textTheme.bodyLarge,
                    )
                  : AddressText(point: loc, location: app.location),
            ),
            if (loc != null)
              TextButton(onPressed: onMap, child: const Text('View on Map')),
          ],
        ),
        const SizedBox(height: 8),
        // hops is diagnostic, but it is the only distance cue there is: it
        // tells a responder roughly how far away the sender might be.
        Text(
          '$hops relay hop${hops == 1 ? '' : 's'} from the sender',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
        ),
      ],
    );
  }
}

/// One incident, one timeline.
///
/// Sender updates and responder replies are separate message types, but that
/// is an implementation fact, not something a reader cares about. What they
/// care about is the order: "getting worse" after "help is on the way" means
/// something different from "getting worse" before it, and two parallel lists
/// hide exactly that.
class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.updates,
    required this.replies,
    required this.origin,
  });

  final List<IncidentUpdate> updates;
  final List<ResponderReply> replies;

  /// This device's identity, so its own replies read as "You".
  final String origin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final entries = <_Entry>[
      for (final u in updates)
        _Entry(
          ts: u.ts,
          fromSender: true,
          icon: updateIcon(u.status),
          title: u.status?.label ?? 'Unrecognised status',
          body: u.text,
          who: 'Sender',
        ),
      for (final r in replies)
        _Entry(
          ts: r.ts,
          fromSender: false,
          icon: Icons.reply,
          title: r.text,
          body: null,
          who: r.from == origin ? 'You' : r.from.substring(0, 6),
        ),
    ]..sort((a, b) => b.ts.compareTo(a.ts));

    return _Card(
      children: [
        Text(
          'Activity',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        // Newest first: in an emergency the current state matters more than
        // reading the thread from the beginning.
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  entry.icon,
                  size: 18,
                  color: entry.fromSender
                      ? theme.colorScheme.error
                      : Colors.green.shade700,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: entry.fromSender
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      if (entry.body != null) Text(entry.body!),
                      Text(
                        '${entry.who} · ${_elapsed(entry.ts)}',
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
}

class _Entry {
  const _Entry({
    required this.ts,
    required this.fromSender,
    required this.icon,
    required this.title,
    required this.body,
    required this.who,
  });

  final int ts;

  /// Which direction this came from, which decides the colour.
  final bool fromSender;

  final IconData icon;
  final String title;
  final String? body;
  final String who;
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

String _since(DateTime when) {
  final seconds = DateTime.now().difference(when).inSeconds;
  if (seconds < 60) return '${seconds}s ago';
  if (seconds < 3600) return '${seconds ~/ 60} min ago';
  return '${seconds ~/ 3600} h ago';
}
