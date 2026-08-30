import 'package:flutter/material.dart';

import '../mesh_app.dart';
import '../messages/mesh_message.dart';

class VictimScreen extends StatelessWidget {
  const VictimScreen({super.key, required this.app});

  final MeshApp app;

  Future<void> _compose(BuildContext context) async {
    final request = await showModalBottomSheet<_SosRequest>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _SosSheet(),
    );
    if (request == null) return;

    final message = await app.sendSos(
      cat: request.cat,
      n: request.headcount,
      txt: request.text.isEmpty ? null : request.text,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('SOS ${message.id} created')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mine = app.myMessages;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: 72,
            child: FilledButton.icon(
              onPressed: () => _compose(context),
              icon: const Icon(Icons.sos, size: 28),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              label: const Text('Send SOS',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
        if (mine.isEmpty)
          const Expanded(
            child: Center(child: Text('Nothing sent yet')),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: mine.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, i) => _SentTile(
                message: mine[i],
                peerCount: app.service.peers.length,
              ),
            ),
          ),
      ],
    );
  }
}

class _SentTile extends StatelessWidget {
  const _SentTile({required this.message, required this.peerCount});

  final MeshMessage message;
  final int peerCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Wording matters. Without ACK there is no delivery confirmation, so this
    // must not imply one — "relayed" guarantees nothing. When ACK lands, the
    // genuine "Reached a responder" state needs to look clearly different.
    final status = peerCount == 0
        ? 'Sending — no devices in range'
        : 'Relayed to $peerCount nearby device${peerCount == 1 ? '' : 's'}';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(message.core.txt ?? message.core.cat?.wire ?? 'SOS'),
      subtitle: Text('$status · ${_elapsed(message.core.ts)}'),
      trailing: Text(
        message.id.substring(0, 6),
        style: theme.textTheme.bodySmall
            ?.copyWith(fontFamily: 'monospace', color: theme.hintColor),
      ),
    );
  }
}

/// Elapsed time is shown throughout so that a long silence is visible rather
/// than ambiguous.
String _elapsed(int unixSeconds) {
  final seconds =
      DateTime.now().millisecondsSinceEpoch ~/ 1000 - unixSeconds;
  if (seconds < 60) return '${seconds}s ago';
  if (seconds < 3600) return '${seconds ~/ 60} min ago';
  return '${seconds ~/ 3600} h ago';
}

class _SosRequest {
  const _SosRequest(this.cat, this.headcount, this.text);

  final Category cat;
  final int headcount;
  final String text;
}

class _SosSheet extends StatefulWidget {
  const _SosSheet();

  @override
  State<_SosSheet> createState() => _SosSheetState();
}

class _SosSheetState extends State<_SosSheet> {
  Category _cat = Category.medical;
  int _headcount = 1;
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
          Text('What is happening?',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final c in Category.values)
                ChoiceChip(
                  label: Text(c.wire),
                  selected: _cat == c,
                  onSelected: (_) => setState(() => _cat = c),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('People at this location'),
              const Spacer(),
              IconButton(
                onPressed: _headcount > 1
                    ? () => setState(() => _headcount--)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('$_headcount', style: const TextStyle(fontSize: 18)),
              IconButton(
                onPressed: () => setState(() => _headcount++),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _text,
            maxLength: kMaxTextLength,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Details (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(
                context,
                _SosRequest(_cat, _headcount, _text.text.trim()),
              ),
              child: const Text('Send'),
            ),
          ),
        ],
      ),
    );
  }
}
