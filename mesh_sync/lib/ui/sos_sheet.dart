import 'package:flutter/material.dart';

import '../messages/mesh_message.dart';

/// What the compose sheet collected.
class SosRequest {
  const SosRequest(this.cat, this.headcount, this.text);

  final Category cat;
  final int headcount;
  final String text;
}

class SosSheet extends StatefulWidget {
  const SosSheet({super.key});

  @override
  State<SosSheet> createState() => SosSheetState();
}

class SosSheetState extends State<SosSheet> {
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
          Text(
            'What is happening?',
            style: Theme.of(context).textTheme.titleMedium,
          ),
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
                SosRequest(_cat, _headcount, _text.text.trim()),
              ),
              child: const Text('Send'),
            ),
          ),
        ],
      ),
    );
  }
}
