import 'package:flutter/material.dart';

import '../mesh_service.dart';

/// Raw transport and router activity, newest first.
///
/// This has been the debugging workhorse since the first spike and carries
/// router lines too now. Session durations in the disconnect lines are the
/// quickest way to tell ordinary churn from a real fault.
class LogView extends StatelessWidget {
  const LogView({super.key, required this.entries});

  final List<MeshLogEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(child: Text('No activity yet'));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: entries.length,
      itemBuilder: (context, i) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          entries[i].toString(),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
      ),
    );
  }
}
