import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../mesh_service.dart';

/// Minimalist diagnostics and raw radio transport log terminal.
class LogView extends StatefulWidget {
  const LogView({super.key, required this.entries});

  final List<MeshLogEntry> entries;

  @override
  State<LogView> createState() => _LogViewState();
}

class _LogViewState extends State<LogView> {
  String _filterTag = 'ALL';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MeshLogEntry> _filteredEntries() {
    return widget.entries.where((entry) {
      final text = entry.text.toLowerCase();
      if (_searchQuery.isNotEmpty && !text.contains(_searchQuery.toLowerCase())) {
        return false;
      }
      switch (_filterTag) {
        case 'CONNECTED':
          return text.contains('connected') || text.contains('disconnected');
        case 'RADIO':
          return text.contains('<--') || text.contains('bytes') || text.contains('payload');
        case 'PERMS':
          return text.contains('perm') || text.contains('gps');
        case 'WARNING':
          return text.contains('warning') || text.contains('fail') || text.contains('error');
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filteredEntries();

    return Column(
      children: [
        // Filter & Search
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(fontFamily: 'Arial', fontSize: 12),
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: const InputDecoration(
                          hintText: 'Search logs...',
                          prefixIcon: Icon(Icons.search, size: 16),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    onPressed: () {
                      final allText = widget.entries.map((e) => e.toString()).join('\n');
                      Clipboard.setData(ClipboardData(text: allText));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Logs copied', style: TextStyle(fontFamily: 'Arial'))),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    tooltip: 'Copy all',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: Text('All (${widget.entries.length})', style: const TextStyle(fontFamily: 'Arial', fontSize: 10)),
                      selected: _filterTag == 'ALL',
                      onSelected: (_) => setState(() => _filterTag = 'ALL'),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: const Text('Connections', style: TextStyle(fontFamily: 'Arial', fontSize: 10)),
                      selected: _filterTag == 'CONNECTED',
                      onSelected: (_) => setState(() => _filterTag = 'CONNECTED'),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: const Text('Radio / Packets', style: TextStyle(fontFamily: 'Arial', fontSize: 10)),
                      selected: _filterTag == 'RADIO',
                      onSelected: (_) => setState(() => _filterTag = 'RADIO'),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: const Text('Permissions', style: TextStyle(fontFamily: 'Arial', fontSize: 10)),
                      selected: _filterTag == 'PERMS',
                      onSelected: (_) => setState(() => _filterTag = 'PERMS'),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: const Text('Warnings', style: TextStyle(fontFamily: 'Arial', fontSize: 10)),
                      selected: _filterTag == 'WARNING',
                      onSelected: (_) => setState(() => _filterTag = 'WARNING'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Log Items
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text('No log entries match filter.', style: TextStyle(fontFamily: 'Arial', fontSize: 12)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final e = filtered[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '${e.stamp}  ${e.text}',
                        style: const TextStyle(
                          fontFamily: 'Arial',
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
