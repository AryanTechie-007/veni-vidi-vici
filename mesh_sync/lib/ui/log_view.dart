import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../mesh_service.dart';
import 'theme/mesh_theme.dart';

/// Tactical diagnostics and raw radio transport log terminal.
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
          return text.contains('connected') || text.contains('disconnected') || text.contains('found');
        case 'RADIO':
          return text.contains('<--') || text.contains('bytes') || text.contains('payload') || text.contains('started');
        case 'PERMS':
          return text.contains('perm') || text.contains('gps') || text.contains('location');
        case 'WARNING':
          return text.contains('warning') || text.contains('fail') || text.contains('error');
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredEntries();

    return Column(
      children: [
        // Controls & Search Bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          color: MeshTheme.darkSurface,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(fontSize: 13),
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: InputDecoration(
                          hintText: 'Filter log output...',
                          prefixIcon: const Icon(Icons.search_rounded, size: 18),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: () {
                      final allText = widget.entries.map((e) => e.toString()).join('\n');
                      Clipboard.setData(ClipboardData(text: allText));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Log copied to clipboard'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_all_rounded, size: 18),
                    tooltip: 'Copy all logs',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Category filter pills
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _LogFilterChip(
                      label: 'All (${widget.entries.length})',
                      selected: _filterTag == 'ALL',
                      onSelected: () => setState(() => _filterTag = 'ALL'),
                    ),
                    const SizedBox(width: 6),
                    _LogFilterChip(
                      label: 'Connections',
                      selected: _filterTag == 'CONNECTED',
                      onSelected: () => setState(() => _filterTag = 'CONNECTED'),
                    ),
                    const SizedBox(width: 6),
                    _LogFilterChip(
                      label: 'Radio / Packets',
                      selected: _filterTag == 'RADIO',
                      onSelected: () => setState(() => _filterTag = 'RADIO'),
                    ),
                    const SizedBox(width: 6),
                    _LogFilterChip(
                      label: 'Permissions',
                      selected: _filterTag == 'PERMS',
                      onSelected: () => setState(() => _filterTag = 'PERMS'),
                    ),
                    const SizedBox(width: 6),
                    _LogFilterChip(
                      label: 'Warnings / Errors',
                      color: MeshTheme.catMedical,
                      selected: _filterTag == 'WARNING',
                      onSelected: () => setState(() => _filterTag = 'WARNING'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Log Entries Terminal
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.terminal_rounded, size: 40, color: MeshTheme.darkMuted),
                      const SizedBox(height: 8),
                      const Text(
                        'No matching log entries',
                        style: TextStyle(color: MeshTheme.darkTextDim, fontSize: 14),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) => _LogEntryTile(entry: filtered[i]),
                ),
        ),
      ],
    );
  }
}

class _LogFilterChip extends StatelessWidget {
  const _LogFilterChip({
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
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? activeColor.withValues(alpha: 0.2) : MeshTheme.darkCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? activeColor : MeshTheme.darkCardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? activeColor : MeshTheme.darkTextDim,
          ),
        ),
      ),
    );
  }
}

class _LogEntryTile extends StatelessWidget {
  const _LogEntryTile({required this.entry});

  final MeshLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final text = entry.text;
    final String tag;
    final Color tagColor;

    if (text.contains('CONNECTED to')) {
      tag = 'PEER';
      tagColor = MeshTheme.ackGreen;
    } else if (text.contains('disconnected')) {
      tag = 'DISC';
      tagColor = MeshTheme.catMedical;
    } else if (text.startsWith('<--')) {
      tag = 'RECV';
      tagColor = MeshTheme.meshCyan;
    } else if (text.contains('WARNING') || text.contains('failed') || text.contains('error')) {
      tag = 'WARN';
      tagColor = MeshTheme.catTrapped;
    } else if (text.contains('perm ')) {
      tag = 'PERM';
      tagColor = Colors.purpleAccent;
    } else if (text.contains('role →')) {
      tag = 'ROLE';
      tagColor = MeshTheme.meshTealGlow;
    } else {
      tag = 'INFO';
      tagColor = MeshTheme.darkMuted;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timestamp pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: MeshTheme.darkSurface,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: MeshTheme.darkCardBorder),
            ),
            child: Text(
              entry.stamp,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                color: MeshTheme.darkTextDim,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Tag Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: tagColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: tagColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              tag,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: tagColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: tagColor == MeshTheme.darkMuted ? MeshTheme.darkText : tagColor,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
