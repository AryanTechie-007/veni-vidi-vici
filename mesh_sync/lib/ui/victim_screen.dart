import 'dart:async';
import 'package:flutter/material.dart';

import '../mesh_app.dart';
import '../messages/mesh_message.dart';
import 'theme/mesh_theme.dart';

class VictimScreen extends StatefulWidget {
  const VictimScreen({super.key, required this.app});

  final MeshApp app;

  @override
  State<VictimScreen> createState() => _VictimScreenState();
}

class _VictimScreenState extends State<VictimScreen> {
  Timer? _tickerTimer;

  MeshApp get app => widget.app;

  @override
  void initState() {
    super.initState();
    _tickerTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    super.dispose();
  }

  Future<void> _compose(BuildContext context, {Category? initialCategory}) async {
    final request = await showModalBottomSheet<_SosRequest>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _SosSheet(initialCategory: initialCategory ?? Category.medical),
    );
    if (request == null) return;

    final message = await app.sendSos(
      cat: request.cat,
      n: request.headcount,
      txt: request.text.isEmpty ? null : request.text,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: MeshTheme.emergencyRed,
          behavior: SnackBarBehavior.floating,
          content: Text(
            'SOS broadcasted (ID: ${message.id.substring(0, 8)})',
            style: const TextStyle(fontFamily: 'Arial', fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mine = app.myMessages;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // --- MINIMALIST HERO SOS SECTION ---
        Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Column(
            children: [
              // Bold Pure Red SOS Button
              SizedBox(
                width: 140,
                height: 140,
                child: ElevatedButton(
                  onPressed: () => _compose(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MeshTheme.emergencyRed,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: const CircleBorder(),
                    padding: EdgeInsets.zero,
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sos, size: 48, color: Colors.white),
                      SizedBox(height: 2),
                      Text(
                        'SEND SOS',
                        style: TextStyle(
                          fontFamily: 'Arial',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Tap to broadcast emergency signal over offline mesh',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Arial',
                  color: isDark ? MeshTheme.darkTextDim : MeshTheme.lightTextDim,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              // Category Quick Presets
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _CategoryQuickBtn(
                    category: Category.medical,
                    label: 'Medical',
                    icon: Icons.medical_services,
                    onTap: () => _compose(context, initialCategory: Category.medical),
                  ),
                  _CategoryQuickBtn(
                    category: Category.trapped,
                    label: 'Trapped',
                    icon: Icons.person_pin_circle,
                    onTap: () => _compose(context, initialCategory: Category.trapped),
                  ),
                  _CategoryQuickBtn(
                    category: Category.fire,
                    label: 'Fire',
                    icon: Icons.local_fire_department,
                    onTap: () => _compose(context, initialCategory: Category.fire),
                  ),
                  _CategoryQuickBtn(
                    category: Category.supplies,
                    label: 'Supplies',
                    icon: Icons.inventory_2,
                    onTap: () => _compose(context, initialCategory: Category.supplies),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // --- ACTIVE DISTRESS SIGNALS ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Active Signals',
              style: TextStyle(
                fontFamily: 'Arial',
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (mine.isNotEmpty)
              Text(
                '${mine.length} active',
                style: const TextStyle(
                  fontFamily: 'Arial',
                  fontSize: 12,
                  color: MeshTheme.emergencyRed,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        if (mine.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Center(
              child: Text(
                'No active distress signals. Your device will automatically relay messages for other users.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Arial',
                  color: isDark ? MeshTheme.darkTextDim : MeshTheme.lightTextDim,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          )
        else
          for (final message in mine) ...[
            _SentSosCard(
              message: message,
              peerCount: app.service.peers.length,
              acked: app.isAcked(message.id),
              onSafe: () => _confirmSafe(context, message.id),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  Future<void> _confirmSafe(BuildContext context, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Safe?', style: TextStyle(fontFamily: 'Arial', fontWeight: FontWeight.bold)),
        content: const Text(
          'This will cancel the active SOS and notify responders that you are safe.',
          style: TextStyle(fontFamily: 'Arial'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Arial')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: MeshTheme.safeGreen),
            child: const Text('I Am Safe', style: TextStyle(fontFamily: 'Arial')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await app.cancel(id, CancelReason.selfResolved);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Distress signal marked as safe.', style: TextStyle(fontFamily: 'Arial')),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class _CategoryQuickBtn extends StatelessWidget {
  const _CategoryQuickBtn({
    required this.category,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final Category category;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        side: BorderSide(color: theme.dividerColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontFamily: 'Arial', fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _SentSosCard extends StatelessWidget {
  const _SentSosCard({
    required this.message,
    required this.peerCount,
    required this.acked,
    required this.onSafe,
  });

  final MeshMessage message;
  final int peerCount;
  final bool acked;
  final VoidCallback onSafe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final core = message.core;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: acked ? MeshTheme.safeGreen : theme.dividerColor,
          width: acked ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: acked ? MeshTheme.safeGreen.withValues(alpha: 0.1) : theme.scaffoldBackgroundColor,
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: Row(
              children: [
                Icon(
                  acked ? Icons.check_circle : Icons.radio_button_checked,
                  size: 14,
                  color: acked ? MeshTheme.safeGreen : MeshTheme.emergencyRed,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    acked ? 'Responder Acknowledged' : 'Relayed across $peerCount peers',
                    style: TextStyle(
                      fontFamily: 'Arial',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: acked ? MeshTheme.safeGreen : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                Text(
                  _elapsed(core.ts),
                  style: const TextStyle(fontFamily: 'Arial', fontSize: 10),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      MeshTheme.getCategoryLabel(core.cat),
                      style: const TextStyle(fontFamily: 'Arial', fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${core.n ?? 1} ${(core.n ?? 1) == 1 ? "Person" : "People"}',
                      style: const TextStyle(fontFamily: 'Arial', fontSize: 11),
                    ),
                  ],
                ),
                if (core.txt != null && core.txt!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    core.txt!,
                    style: const TextStyle(fontFamily: 'Arial', fontSize: 12),
                  ),
                ],
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onSafe,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: MeshTheme.safeGreen,
                      side: const BorderSide(color: MeshTheme.safeGreen),
                    ),
                    child: const Text('I Am Safe', style: TextStyle(fontFamily: 'Arial', fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _elapsed(int unixSeconds) {
  final seconds = DateTime.now().millisecondsSinceEpoch ~/ 1000 - unixSeconds;
  if (seconds < 60) return '${seconds}s ago';
  if (seconds < 3600) return '${seconds ~/ 60}m ago';
  return '${seconds ~/ 3600}h ago';
}

class _SosRequest {
  const _SosRequest(this.cat, this.headcount, this.text);

  final Category cat;
  final int headcount;
  final String text;
}

class _SosSheet extends StatefulWidget {
  const _SosSheet({required this.initialCategory});

  final Category initialCategory;

  @override
  State<_SosSheet> createState() => _SosSheetState();
}

class _SosSheetState extends State<_SosSheet> {
  late Category _cat;
  int _headcount = 1;
  final TextEditingController _text = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cat = widget.initialCategory;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Broadcast Emergency SOS',
            style: TextStyle(fontFamily: 'Arial', fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in Category.values)
                ChoiceChip(
                  label: Text(c.wire, style: const TextStyle(fontFamily: 'Arial', fontSize: 11)),
                  selected: _cat == c,
                  onSelected: (_) => setState(() => _cat = c),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('People Needing Help', style: TextStyle(fontFamily: 'Arial', fontSize: 13)),
              Row(
                children: [
                  IconButton.outlined(
                    onPressed: _headcount > 1 ? () => setState(() => _headcount--) : null,
                    icon: const Icon(Icons.remove, size: 16),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text('$_headcount', style: const TextStyle(fontFamily: 'Arial', fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  IconButton.outlined(
                    onPressed: () => setState(() => _headcount++),
                    icon: const Icon(Icons.add, size: 16),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _text,
            maxLength: kMaxTextLength,
            maxLines: 2,
            style: const TextStyle(fontFamily: 'Arial', fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'Details / Location info (optional)',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: () => Navigator.pop(
                context,
                _SosRequest(_cat, _headcount, _text.text.trim()),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: MeshTheme.emergencyRed,
                foregroundColor: Colors.white,
              ),
              child: const Text('BROADCAST SOS', style: TextStyle(fontFamily: 'Arial', fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }
}
