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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      children: [
        // --- SUMMARY METRICS BAR ---
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(
            children: [
              _MetricItem(label: 'ACTIVE SOS', value: '${allIncidents.length}'),
              Container(width: 1, height: 32, color: theme.dividerColor),
              _MetricItem(label: 'PEOPLE AT RISK', value: '$totalPeople'),
              Container(width: 1, height: 32, color: theme.dividerColor),
              _MetricItem(label: 'ACK CONFIRMED', value: '$ackedCount'),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // --- FILTER CHIPS ---
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
                label: Text('All (${allIncidents.length})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                selected: _filterCategory == null,
                onSelected: (_) => setState(() => _filterCategory = null),
              ),
              for (final cat in Category.values) ...[
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text('${cat.wire} (${allIncidents.where((m) => m.core.cat == cat).length})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  selected: _filterCategory == cat,
                  onSelected: (_) => setState(() => _filterCategory = cat),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),

        // --- INCIDENTS LIST ---
        if (filteredIncidents.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.radar_outlined, size: 32, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                  const SizedBox(height: 10),
                  Text(
                    allIncidents.isEmpty
                        ? 'Mesh Frequencies Clear'
                        : 'No Incidents in Selected Category',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Listening for inbound emergency packets from survivor devices...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark ? MeshTheme.darkTextMuted : MeshTheme.lightTextMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
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
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
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
    final isDark = theme.brightness == Brightness.dark;
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
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                Text(
                  '#${core.origin.substring(0, 6)} · ${_elapsed(core.ts)} · ${hops == 0 ? "Direct link" : "$hops hops away"}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? MeshTheme.darkTextMuted : MeshTheme.lightTextMuted,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${core.n ?? 1} ${(core.n ?? 1) == 1 ? "Survivor" : "Survivors"}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    if (acked)
                      const Row(
                        children: [
                          Icon(Icons.check_circle_outline, size: 14, color: MeshTheme.safeGreen),
                          SizedBox(width: 4),
                          Text('Auto-ACK Dispatched', style: TextStyle(fontSize: 11, color: MeshTheme.safeGreen, fontWeight: FontWeight.w600)),
                        ],
                      ),
                  ],
                ),
                if (core.txt != null && core.txt!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Text(
                      core.txt!,
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _confirmClose(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('Mark Rescued & Close Incident', style: TextStyle(fontWeight: FontWeight.w600)),
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
        title: const Text('Close Incident?', style: TextStyle(fontWeight: FontWeight.w600)),
        content: const Text(
          'Floods a CANCEL packet with reason RESCUED to clear this distress signal across the entire mesh perimeter.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Open'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: MeshTheme.safeGreen),
            child: const Text('Confirm Rescued', style: TextStyle(fontWeight: FontWeight.w600)),
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
