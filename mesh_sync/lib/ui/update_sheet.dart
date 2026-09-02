import 'package:flutter/material.dart';

import '../messages/mesh_message.dart';

/// What the update sheet collected.
class UpdateRequest {
  const UpdateRequest(this.status, this.text);

  final UpdateStatus status;
  final String text;
}

/// Revising an open incident.
///
/// Mostly taps: someone one-handed under rubble with a dying phone is not
/// going to type, so the status carries the meaning and the text is optional.
class UpdateSheet extends StatefulWidget {
  const UpdateSheet({super.key});

  @override
  State<UpdateSheet> createState() => _UpdateSheetState();
}

class _UpdateSheetState extends State<UpdateSheet> {
  UpdateStatus? _status;
  final TextEditingController _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          Text('Update your situation', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'This does not replace your alert — it travels alongside it.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final status in UpdateStatus.values)
                ChoiceChip(
                  label: Text(status.label),
                  selected: _status == status,
                  onSelected: (_) => setState(() => _status = status),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _text,
            maxLength: kMaxTextLength,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Anything to add (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              // A status is the whole point, so there is nothing to send
              // without one.
              onPressed: _status == null
                  ? null
                  : () => Navigator.pop(
                      context,
                      UpdateRequest(_status!, _text.text.trim()),
                    ),
              child: const Text('Send update'),
            ),
          ),
        ],
      ),
    );
  }
}
