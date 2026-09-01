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

class _VictimScreenState extends State<VictimScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  Timer? _tickerTimer;

  MeshApp get app => widget.app;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Refresh elapsed time every 10 seconds
    _tickerTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _compose(BuildContext context, {Category? initialCategory}) async {
    final request = await showModalBottomSheet<_SosRequest>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
          backgroundColor: MeshTheme.catMedical,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: [
              const Icon(Icons.emergency_share_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'SOS Broadcasted! ID: ${message.id.substring(0, 8)}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mine = app.myMessages;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // --- HERO SOS TRIGGER CARD ---
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1E1014),
                MeshTheme.darkCard,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: MeshTheme.catMedical.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: MeshTheme.catMedical.withValues(alpha: 0.15),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: MeshTheme.catMedical.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: MeshTheme.catMedical.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.wifi_tethering_rounded, size: 14, color: MeshTheme.catMedical),
                        SizedBox(width: 6),
                        Text(
                          'OFFLINE EMERGENCY BEACON',
                          style: TextStyle(
                            color: MeshTheme.catMedical,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // Pulsating Emergency SOS Button
              ScaleTransition(
                scale: _pulseAnimation,
                child: SizedBox(
                  width: 140,
                  height: 140,
                  child: ElevatedButton(
                    onPressed: () => _compose(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MeshTheme.catMedical,
                      foregroundColor: Colors.white,
                      elevation: 12,
                      shadowColor: MeshTheme.catMedical.withValues(alpha: 0.6),
                      shape: const CircleBorder(),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sos_rounded, size: 48, color: Colors.white),
                        SizedBox(height: 2),
                        Text(
                          'SEND SOS',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Tap to alert nearby search & rescue teams and mesh nodes',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: MeshTheme.darkTextDim,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              // Quick Emergency Category Presets
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _QuickCategoryBtn(
                    category: Category.medical,
                    label: 'Medical',
                    icon: Icons.medical_services_rounded,
                    onTap: () => _compose(context, initialCategory: Category.medical),
                  ),
                  _QuickCategoryBtn(
                    category: Category.trapped,
                    label: 'Trapped',
                    icon: Icons.person_pin_circle_rounded,
                    onTap: () => _compose(context, initialCategory: Category.trapped),
                  ),
                  _QuickCategoryBtn(
                    category: Category.fire,
                    label: 'Fire',
                    icon: Icons.local_fire_department_rounded,
                    onTap: () => _compose(context, initialCategory: Category.fire),
                  ),
                  _QuickCategoryBtn(
                    category: Category.supplies,
                    label: 'Supplies',
                    icon: Icons.inventory_2_rounded,
                    onTap: () => _compose(context, initialCategory: Category.supplies),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // --- SENT INCIDENTS LIST / EMPTY GUIDE ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Your Active Distress Signals',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: MeshTheme.darkText,
              ),
            ),
            if (mine.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: MeshTheme.catMedical.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${mine.length} Active',
                  style: const TextStyle(
                    color: MeshTheme.catMedical,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        if (mine.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: MeshTheme.darkSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: MeshTheme.darkCardBorder),
            ),
            child: Column(
              children: [
                Icon(Icons.shield_outlined, size: 40, color: MeshTheme.meshTealGlow),
                const SizedBox(height: 12),
                const Text(
                  'No Distress Signals Sent',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'When you trigger an SOS, it automatically propagates across peer-to-peer devices even without cell service or Internet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: MeshTheme.darkTextDim, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Mesh Survival Tip Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MeshTheme.darkCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: MeshTheme.darkCardBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: MeshTheme.meshCyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.share_location_rounded, color: MeshTheme.meshCyan, size: 20),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Passive Relay Active',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Even while idle, your device carries and relays encrypted SOS packets for others in your vicinity.',
                        style: TextStyle(color: MeshTheme.darkTextDim, fontSize: 12, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
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
      ],
    );
  }

  Future<void> _confirmSafe(BuildContext context, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.health_and_safety_rounded, color: MeshTheme.catSafe, size: 36),
        title: const Text('Mark Yourself as Safe?'),
        content: const Text(
          'This will flood a CANCEL message to all connected mesh nodes and responders, clearing your emergency status.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Emergency Active'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: MeshTheme.catSafe),
            child: const Text('I am Safe (Resolve)'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await app.cancel(id, CancelReason.selfResolved);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incident cancelled and marked self-resolved.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class _QuickCategoryBtn extends StatelessWidget {
  const _QuickCategoryBtn({
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
    final color = MeshTheme.getCategoryColor(category);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
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
    final core = message.core;
    final catColor = MeshTheme.getCategoryColor(core.cat);
    final catIcon = MeshTheme.getCategoryIcon(core.cat);

    final String statusText;
    final Color statusColor;
    final IconData statusIcon;

    if (acked) {
      statusText = 'RESPONDER ACKNOWLEDGED — Help is incoming!';
      statusColor = MeshTheme.ackGreen;
      statusIcon = Icons.verified_rounded;
    } else if (peerCount == 0) {
      statusText = 'Broadcasting offline · Searching for nearby peers';
      statusColor = MeshTheme.catTrapped;
      statusIcon = Icons.wifi_find_rounded;
    } else {
      statusText = 'Relayed across $peerCount nearby device${peerCount == 1 ? '' : 's'}';
      statusColor = MeshTheme.meshCyan;
      statusIcon = Icons.wifi_tethering_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: MeshTheme.darkCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: acked
              ? MeshTheme.ackGreen.withValues(alpha: 0.6)
              : MeshTheme.darkCardBorder,
          width: acked ? 1.5 : 1.0,
        ),
        boxShadow: acked
            ? [
                BoxShadow(
                  color: MeshTheme.ackGreen.withValues(alpha: 0.15),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
              border: Border(
                bottom: BorderSide(color: statusColor.withValues(alpha: 0.2)),
              ),
            ),
            child: Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  _elapsed(core.ts),
                  style: const TextStyle(
                    color: MeshTheme.darkTextDim,
                    fontSize: 11,
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: catColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(catIcon, color: catColor, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            MeshTheme.getCategoryLabel(core.cat),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: MeshTheme.darkText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: MeshTheme.darkSurface,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${core.n ?? 1} ${(core.n ?? 1) == 1 ? "Person" : "People"}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: MeshTheme.darkTextDim,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'ID: ${core.id.substring(0, 8)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: MeshTheme.darkMuted,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (core.txt != null && core.txt!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: MeshTheme.darkSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: MeshTheme.darkCardBorder),
                    ),
                    child: Text(
                      core.txt!,
                      style: const TextStyle(fontSize: 13, color: MeshTheme.darkText),
                    ),
                  ),
                ],

                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onSafe,
                    icon: const Icon(Icons.health_and_safety_outlined, size: 18, color: MeshTheme.catSafe),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: MeshTheme.catSafe.withValues(alpha: 0.5)),
                      foregroundColor: MeshTheme.catSafe,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    label: const Text('I Am Safe (Cancel Distress)'),
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
  if (seconds < 10) return 'Just now';
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
    final theme = Theme.of(context);

    return Container(
      decoration: const BoxDecoration(
        color: MeshTheme.darkCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: MeshTheme.darkCardBorder)),
      ),
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
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: MeshTheme.darkCardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: MeshTheme.catMedical.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.sos_rounded, color: MeshTheme.catMedical, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Broadcast Emergency SOS',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const Text(
                      'Select category and details to broadcast over mesh',
                      style: TextStyle(color: MeshTheme.darkTextDim, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          const Text(
            'Emergency Category',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: MeshTheme.darkTextDim),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in Category.values)
                _CategoryChip(
                  category: c,
                  selected: _cat == c,
                  onSelected: () => setState(() => _cat = c),
                ),
            ],
          ),

          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MeshTheme.darkSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MeshTheme.darkCardBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.people_alt_rounded, color: MeshTheme.meshCyan, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'People in Danger',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        'Headcount needing assistance',
                        style: TextStyle(color: MeshTheme.darkTextDim, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: _headcount > 1 ? () => setState(() => _headcount--) : null,
                  icon: const Icon(Icons.remove_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: MeshTheme.darkCard,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    '$_headcount',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: MeshTheme.meshCyan),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: () => setState(() => _headcount++),
                  icon: const Icon(Icons.add_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: MeshTheme.darkCard,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          TextField(
            controller: _text,
            maxLength: kMaxTextLength,
            maxLines: 2,
            style: const TextStyle(fontSize: 14),
            decoration: const InputDecoration(
              labelText: 'Specific Details / Landmarks (optional)',
              hintText: 'e.g. 2nd floor, stairwell blocked, need water',
              alignLabelWithHint: true,
            ),
          ),

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: () => Navigator.pop(
                context,
                _SosRequest(_cat, _headcount, _text.text.trim()),
              ),
              icon: const Icon(Icons.emergency_share_rounded, size: 22),
              style: FilledButton.styleFrom(
                backgroundColor: MeshTheme.catMedical,
                foregroundColor: Colors.white,
              ),
              label: const Text(
                'BROADCAST DISTRESS SIGNAL',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onSelected,
  });

  final Category category;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final color = MeshTheme.getCategoryColor(category);
    final icon = MeshTheme.getCategoryIcon(category);

    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.25) : MeshTheme.darkSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : MeshTheme.darkCardBorder,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? color : MeshTheme.darkTextDim),
            const SizedBox(width: 6),
            Text(
              category.wire,
              style: TextStyle(
                color: selected ? color : MeshTheme.darkText,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
