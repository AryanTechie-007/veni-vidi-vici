import 'package:flutter/material.dart';

import '../mesh_app.dart';
import '../messages/mesh_message.dart';
import 'address_text.dart';

/// The compose form, as a full screen rather than a sheet — it is the single
/// most important thing this app does.
class SendSosScreen extends StatefulWidget {
  const SendSosScreen({super.key, required this.app});

  final MeshApp app;

  @override
  State<SendSosScreen> createState() => _SendSosScreenState();
}

class _SendSosScreenState extends State<SendSosScreen> {
  Category _cat = Category.trapped;
  int _headcount = 1;
  final TextEditingController _text = TextEditingController();

  GeoPoint? _loc;
  bool _locating = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // The cached fix, which returns instantly. Sending never waits on GPS —
    // a stale position beats no message.
    widget.app.location.lastKnown().then((loc) {
      if (mounted) setState(() => _loc = loc);
    });
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _refreshLocation() async {
    setState(() => _locating = true);
    final loc = await widget.app.location.refresh();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (loc != null) _loc = loc;
    });
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() => _sending = true);
    final message = await widget.app.sendSos(
      cat: _cat,
      n: _headcount,
      txt: _text.text.trim().isEmpty ? null : _text.text.trim(),
      loc: _loc,
    );
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('SOS ${message.id.substring(0, 6)} sent')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Send SOS'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _Header(),
          const SizedBox(height: 24),

          _Label('Location'),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.place_outlined, size: 20, color: theme.hintColor),
              const SizedBox(width: 8),
              Expanded(
                child: _loc == null
                    ? Text(
                        'No location available',
                        style: theme.textTheme.bodyLarge,
                      )
                    : AddressText(point: _loc!, location: widget.app.location),
              ),
              if (_locating)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                TextButton(
                  onPressed: _refreshLocation,
                  child: const Text('Refresh'),
                ),
            ],
          ),
          const SizedBox(height: 20),

          _Label('Type of Emergency'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in Category.values)
                ChoiceChip(
                  label: Text(category.label),
                  selected: _cat == category,
                  selectedColor: theme.colorScheme.error,
                  labelStyle: TextStyle(
                    color: _cat == category
                        ? theme.colorScheme.onError
                        : theme.colorScheme.onSurface,
                  ),
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _cat = category),
                ),
            ],
          ),
          const SizedBox(height: 24),

          _Label('Details', optional: true),
          const SizedBox(height: 8),
          TextField(
            controller: _text,
            maxLength: kMaxTextLength,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Describe your situation...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          _Label('People Affected', optional: true, suffix: '(approx.)'),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton.outlined(
                onPressed: _headcount > 1
                    ? () => setState(() => _headcount--)
                    : null,
                icon: const Icon(Icons.remove),
              ),
              SizedBox(
                width: 56,
                child: Text(
                  '$_headcount',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              IconButton.outlined(
                onPressed: () => setState(() => _headcount++),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 28),

          SizedBox(
            height: 60,
            child: FilledButton.icon(
              onPressed: _sending ? null : _send,
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.campaign),
              label: const Text(
                'Send SOS',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.error,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white.withValues(alpha: 0.25),
            child: Text(
              'SOS',
              style: TextStyle(
                color: scheme.onError,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'I need help!',
                  style: TextStyle(
                    color: scheme.onError,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your alert will be shared with nearby devices.',
                  style: TextStyle(color: scheme.onError, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {this.optional = false, this.suffix});

  final String text;
  final bool optional;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          text,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        if (optional || suffix != null) ...[
          const SizedBox(width: 6),
          Text(
            suffix ?? '(optional)',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ],
      ],
    );
  }
}
