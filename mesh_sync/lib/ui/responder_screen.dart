import 'dart:async';
import 'package:flutter/material.dart';

import '../mesh_app.dart';
import '../messages/mesh_message.dart';
import 'theme/mesh_theme.dart';

/// Search & Rescue Command View for Responder Mode.
class ResponderScreen extends StatefulWidget {
  const ResponderScreen({super.key, required this.app});

  final MeshApp app;

  @override
  State<ResponderScreen> createState() => _ResponderScreenState();
}

class _ResponderScreenState extends State<ResponderScreen> {
  Category? _filterCategory;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allIncidents = app.incidents;

    final filteredIncidents = _filterCategory == null
        ? allIncidents
        : allIncidents.where((m) => m.core.cat == _filterCategory).toList();

    // Summary calculations
    final totalPeople = allIncidents.fold<int>(
      0,
      (sum, m) => sum + (m.core.n ?? 1),
    );
    final ackedCount = allIncidents.where((m) => app.isAcked(m.id)).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // --- SEARCH & RESCUE COMMAND METRICS ---
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: MeshTheme.darkCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: MeshTheme.darkCardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: MeshTheme.meshCyan.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.emergency_rounded, size: 18, color: MeshTheme.meshCyan),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'TACTICAL TRIAGE DASHBOARD',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: MeshTheme.meshCyan,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _MetricBox(
                    label: 'ACTIVE SOS',
                    value: '${allIncidents.length}',
                    color: MeshTheme.catMedical,
                    icon: Icons.notifications_active_rounded,
                  ),
                  const SizedBox(width: 8),
                  _MetricBox(
                    label: 'PEOPLE AT RISK',
                    value: '$totalPeople',
                    color: MeshTheme.catTrapped,
                    icon: Icons.people_rounded,
                  ),
                  const SizedBox(width: 8),
                  _MetricBox(
                    label: 'ACK CONFIRMED',
                    value: '$ackedCount',
                    color: MeshTheme.ackGreen,
                    icon: Icons.check_circle_rounded,
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // --- CATEGORY FILTER CHIPS ---
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                label: 'All (${allIncidents.length})',
                selected: _filterCategory == null,
                onSelected: () => setState(() => _filterCategory = null),
              ),
              for (final cat in Category.values) ...[
                const SizedBox(width: 8),
                _FilterChip(
                  label: '${cat.wire} (${allIncidents.where((m) => m.core.cat == cat).length})',
                  color: MeshTheme.getCategoryColor(cat),
                  selected: _filterCategory == cat,
                  onSelected: () => setState(() => _filterCategory = cat),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),

        // --- INCIDENTS LIST / EMPTY STATE ---
        if (filteredIncidents.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
            decoration: BoxDecoration(
              color: MeshTheme.darkSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: MeshTheme.darkCardBorder),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: MeshTheme.meshCyan.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.radar_rounded,
                    size: 48,
                    color: MeshTheme.meshCyan,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  allIncidents.isEmpty
                      ? 'Mesh Frequencies Clear'
                      : 'No Incidents in Selected Category',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Your node is actively scanning for offline distress packets. Any SOS broadcast within hop radius will display here immediately.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: MeshTheme.darkTextDim,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          )
        else
          for (final incident in filteredIncidents) ...[
            _IncidentCard(
              message: incident,
              acked: app.isAcked(incident.id),
              onClose: () => app.cancel(incident.id, CancelReason.rescued),
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _MetricBox extends StatelessWidget {
  const _MetricBox({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: MeshTheme.darkSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: MeshTheme.darkTextDim,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? MeshTheme.meshCyan;
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? activeColor.withValues(alpha: 0.2) : MeshTheme.darkSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? activeColor : MeshTheme.darkCardBorder,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? activeColor : MeshTheme.darkTextDim,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _IncidentCard extends StatelessWidget {
  const _IncidentCard({
    required this.message,
    required this.acked,
    required this.onClose,
  });

  final MeshMessage message;
  final bool acked;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final core = message.core;
    final hops = message.env.hops;
    final catColor = MeshTheme.getCategoryColor(core.cat);
    final catIcon = MeshTheme.getCategoryIcon(core.cat);

    return Container(
      decoration: BoxDecoration(
        color: MeshTheme.darkCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MeshTheme.darkCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: catColor.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
              border: Border(bottom: BorderSide(color: catColor.withValues(alpha: 0.2))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(catIcon, color: catColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        MeshTheme.getCategoryLabel(core.cat),
                        style: TextStyle(
                          color: catColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Origin: #${core.origin.substring(0, 6)} · ${_elapsed(core.ts)}',
                        style: const TextStyle(fontSize: 11, color: MeshTheme.darkTextDim),
                      ),
                    ],
                  ),
                ),
                // Hop Count Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: MeshTheme.darkSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: MeshTheme.darkCardBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hops == 0 ? Icons.sensors_rounded : Icons.route_rounded,
                        size: 13,
                        color: hops == 0 ? MeshTheme.meshCyan : MeshTheme.darkTextDim,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        hops == 0 ? 'Direct link' : '$hops hop${hops == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: hops == 0 ? MeshTheme.meshCyan : MeshTheme.darkTextDim,
                        ),
                      ),
                    ],
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
                // Headcount & ACK status
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: MeshTheme.darkSurface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.people_alt_rounded, size: 14, color: MeshTheme.catTrapped),
                          const SizedBox(width: 6),
                          Text(
                            '${core.n ?? 1} ${(core.n ?? 1) == 1 ? "Person" : "People"}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: MeshTheme.darkText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (acked)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: MeshTheme.ackGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: MeshTheme.ackGreen.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_rounded, size: 13, color: MeshTheme.ackGreen),
                            SizedBox(width: 4),
                            Text(
                              'Auto-ACK Sent',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: MeshTheme.ackGreen,
                              ),
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
                      style: const TextStyle(fontSize: 13, color: MeshTheme.darkText, height: 1.4),
                    ),
                  ),
                ],

                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _confirmClose(context),
                        icon: const Icon(Icons.check_box_outlined, size: 18),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: MeshTheme.catSafe,
                          side: BorderSide(color: MeshTheme.catSafe.withValues(alpha: 0.5)),
                        ),
                        label: const Text('Mark Rescued & Close'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClose(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.verified_user_rounded, color: MeshTheme.catSafe, size: 36),
        title: const Text('Resolve and Close Incident?'),
        content: const Text(
          'Marking this incident as RESCUED floods a CANCEL packet across all mesh devices to remove this distress beacon from the network.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: MeshTheme.catSafe),
            child: const Text('Confirm Rescued'),
          ),
        ],
      ),
    );
    if (confirmed == true) onClose();
  }
}

String _elapsed(int unixSeconds) {
  final seconds = DateTime.now().millisecondsSinceEpoch ~/ 1000 - unixSeconds;
  if (seconds < 10) return 'Just now';
  if (seconds < 60) return '${seconds}s ago';
  if (seconds < 3600) return '${seconds ~/ 60}m ago';
  return '${seconds ~/ 3600}h ago';
}
