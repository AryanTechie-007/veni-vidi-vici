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
          backgroundColor: MeshTheme.terracottaRed,
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Emergency broadcast dispatched (ID: #${message.id.substring(0, 6)})',
            style: const TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.bold, color: Colors.white),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        // --- PRIMARY FOCAL ACTION: HERO SOS SECTION ---
        Container(
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Column(
            children: [
              Text(
                'Emergency Broadcast',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Radio beacon relays over offline mesh to search teams',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: isDark ? MeshTheme.darkTextMuted : MeshTheme.lightTextMuted,
                ),
              ),
              const SizedBox(height: 32),

              // Prominent Terracotta Red Primary Button
              SizedBox(
                width: 160,
                height: 160,
                child: ElevatedButton(
                  onPressed: () => _compose(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MeshTheme.terracottaRed,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: const CircleBorder(),
                    padding: EdgeInsets.zero,
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sos_outlined, size: 52, color: Colors.white),
                      SizedBox(height: 4),
                      Text(
                        'SEND SOS',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Secondary Category Quick Filters
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _CategoryQuickBtn(
                    category: Category.medical,
                    label: 'Medical',
                    icon: Icons.medical_services_outlined,
                    onTap: () => _compose(context, initialCategory: Category.medical),
                  ),
                  _CategoryQuickBtn(
                    category: Category.trapped,
                    label: 'Trapped',
                    icon: Icons.person_pin_circle_outlined,
                    onTap: () => _compose(context, initialCategory: Category.trapped),
                  ),
                  _CategoryQuickBtn(
                    category: Category.fire,
                    label: 'Fire',
                    icon: Icons.local_fire_department_outlined,
                    onTap: () => _compose(context, initialCategory: Category.fire),
                  ),
                  _CategoryQuickBtn(
                    category: Category.supplies,
                    label: 'Supplies',
                    icon: Icons.inventory_2_outlined,
                    onTap: () => _compose(context, initialCategory: Category.supplies),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // --- ACTIVE DISTRESS SIGNALS SECTION ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              'Active Distress Signals',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            if (mine.isNotEmpty)
              Text(
                '${mine.length} active',
                style: const TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 13,
                  color: MeshTheme.terracottaRed,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),

        if (mine.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Column(
              children: [
                Icon(Icons.shield_outlined, size: 36, color: MeshTheme.sageGreen),
                const SizedBox(height: 12),
                Text(
                  'No Distress Signals Active',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your phone automatically acts as an offline packet courier for nearby survivors.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    color: isDark ? MeshTheme.darkTextMuted : MeshTheme.lightTextMuted,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
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
            const SizedBox(height: 12),
          ],
      ],
    );
  }

  Future<void> _confirmSafe(BuildContext context, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Safe?', style: TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.bold)),
        content: const Text(
          'This will cancel your active SOS beacon and broadcast that you have self-resolved to all rescue nodes.',
          style: TextStyle(fontFamily: 'Georgia', fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Active', style: TextStyle(fontFamily: 'Georgia')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: MeshTheme.sageGreen),
            child: const Text('Confirm Safe', style: TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await app.cancel(id, CancelReason.selfResolved);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Distress signal marked as safe.', style: TextStyle(fontFamily: 'Georgia')),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        side: BorderSide(color: theme.dividerColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontFamily: 'Georgia', fontSize: 11, fontWeight: FontWeight.bold)),
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
    final isDark = theme.brightness == Brightness.dark;
    final core = message.core;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: acked ? MeshTheme.sageGreen : theme.dividerColor,
          width: acked ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: acked ? MeshTheme.sageGreen.withValues(alpha: 0.1) : theme.scaffoldBackgroundColor,
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: Row(
              children: [
                Icon(
                  acked ? Icons.check_circle_outline : Icons.radio_button_checked,
                  size: 16,
                  color: acked ? MeshTheme.sageGreen : MeshTheme.terracottaRed,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    acked ? 'Responder Confirmed Receipt' : 'Relayed across $peerCount mesh nodes',
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: acked ? MeshTheme.sageGreen : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                Text(
                  _elapsed(core.ts),
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 11,
                    color: isDark ? MeshTheme.darkTextMuted : MeshTheme.lightTextMuted,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      MeshTheme.getCategoryLabel(core.cat),
                      style: const TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${core.n ?? 1} ${(core.n ?? 1) == 1 ? "Person" : "People"}',
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 12,
                        color: isDark ? MeshTheme.darkTextMuted : MeshTheme.lightTextMuted,
                      ),
                    ),
                  ],
                ),
                if (core.txt != null && core.txt!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    core.txt!,
                    style: const TextStyle(fontFamily: 'Georgia', fontSize: 13, height: 1.4),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onSafe,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: MeshTheme.sageGreen,
                      side: const BorderSide(color: MeshTheme.sageGreen),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('I Am Safe (Resolve)', style: TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.bold)),
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
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Broadcast Emergency SOS',
            style: TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in Category.values)
                ChoiceChip(
                  label: Text(c.wire, style: const TextStyle(fontFamily: 'Georgia', fontSize: 12)),
                  selected: _cat == c,
                  onSelected: (_) => setState(() => _cat = c),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Casualty / Survivor Count', style: TextStyle(fontFamily: 'Georgia', fontSize: 14)),
              Row(
                children: [
                  IconButton.outlined(
                    onPressed: _headcount > 1 ? () => setState(() => _headcount--) : null,
                    icon: const Icon(Icons.remove, size: 16),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('$_headcount', style: const TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  IconButton.outlined(
                    onPressed: () => setState(() => _headcount++),
                    icon: const Icon(Icons.add, size: 16),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _text,
            maxLength: kMaxTextLength,
            maxLines: 2,
            style: const TextStyle(fontFamily: 'Georgia', fontSize: 14),
            decoration: const InputDecoration(
              labelText: 'Details / Landmark info (optional)',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: () => Navigator.pop(
                context,
                _SosRequest(_cat, _headcount, _text.text.trim()),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: MeshTheme.terracottaRed,
                foregroundColor: Colors.white,
              ),
              child: const Text('BROADCAST DISTRESS SIGNAL', style: TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }
}
