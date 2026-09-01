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
    final isDark = theme.brightness == Brightness.dark;
    final allIncidents = app.incidents;

    final filteredIncidents = _filterCategory == null
        ? allIncidents
        : allIncidents.where((m) => m.core.cat == _filterCategory).toList();

    final totalPeople = allIncidents.fold<int>(0, (sum, m) => sum + (m.core.n ?? 1));
    final ackedCount = allIncidents.where((m) => app.isAcked(m.id)).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // --- SUMMARY METRICS ---
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(
            children: [
              _MetricItem(label: 'ACTIVE SOS', value: '${allIncidents.length}'),
              Container(width: 1, height: 30, color: theme.dividerColor),
              _MetricItem(label: 'PEOPLE AT RISK', value: '$totalPeople'),
              Container(width: 1, height: 30, color: theme.dividerColor),
              _MetricItem(label: 'ACK CONFIRMED', value: '$ackedCount'),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // --- FILTER CHIPS ---
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
                label: Text('All (${allIncidents.length})', style: const TextStyle(fontFamily: 'Arial', fontSize: 11)),
                selected: _filterCategory == null,
                onSelected: (_) => setState(() => _filterCategory = null),
              ),
              for (final cat in Category.values) ...[
                const SizedBox(width: 6),
                ChoiceChip(
                  label: Text('${cat.wire} (${allIncidents.where((m) => m.core.cat == cat).length})', style: const TextStyle(fontFamily: 'Arial', fontSize: 11)),
                  selected: _filterCategory == cat,
                  onSelected: (_) => setState(() => _filterCategory = cat),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 14),

        // --- INCIDENTS LIST ---
        if (filteredIncidents.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Center(
              child: Text(
                allIncidents.isEmpty
                    ? 'No distress signals in range. Scanning mesh...'
                    : 'No incidents in this category.',
                style: TextStyle(
                  fontFamily: 'Arial',
                  color: isDark ? MeshTheme.darkTextDim : MeshTheme.lightTextDim,
                  fontSize: 12,
                ),
              ),
            ),
          )
        else
          for (final incident in filteredIncidents) ...[
            _IncidentCard(
              message: incident,
              acked: app.isAcked(incident.id),
              onClose: () => app.cancel(incident.id, CancelReason.rescued),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _MetricItem extends StatelessWidget {
  const _MetricItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Arial',
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Arial',
              fontSize: 9,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
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
    final theme = Theme.of(context);
    final core = message.core;
    final hops = message.env.hops;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  MeshTheme.getCategoryLabel(core.cat),
                  style: const TextStyle(fontFamily: 'Arial', fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  '#${core.origin.substring(0, 6)} · ${_elapsed(core.ts)} · ${hops == 0 ? "Direct" : "$hops hops"}',
                  style: TextStyle(
                    fontFamily: 'Arial',
                    fontSize: 10,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
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
                  children: [
                    Text(
                      '${core.n ?? 1} ${(core.n ?? 1) == 1 ? "Person" : "People"}',
                      style: const TextStyle(fontFamily: 'Arial', fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    if (acked)
                      const Row(
                        children: [
                          Icon(Icons.check_circle, size: 12, color: MeshTheme.safeGreen),
                          SizedBox(width: 4),
                          Text('Auto-ACK Sent', style: TextStyle(fontFamily: 'Arial', fontSize: 10, color: MeshTheme.safeGreen, fontWeight: FontWeight.bold)),
                        ],
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
                    onPressed: () => _confirmClose(context),
                    child: const Text('Mark Rescued & Close', style: TextStyle(fontFamily: 'Arial', fontWeight: FontWeight.bold)),
                  ),
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
        title: const Text('Close this incident?', style: TextStyle(fontFamily: 'Arial', fontWeight: FontWeight.bold)),
        content: const Text(
          'Marking as RESCUED floods a cancel packet to clear this incident across all mesh devices.',
          style: TextStyle(fontFamily: 'Arial'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Arial')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm Rescued', style: TextStyle(fontFamily: 'Arial')),
          ),
        ],
      ),
    );
    if (confirmed == true) onClose();
  }
}

String _elapsed(int unixSeconds) {
  final seconds = DateTime.now().millisecondsSinceEpoch ~/ 1000 - unixSeconds;
  if (seconds < 60) return '${seconds}s ago';
  if (seconds < 3600) return '${seconds ~/ 60}m ago';
  return '${seconds ~/ 3600}h ago';
}
