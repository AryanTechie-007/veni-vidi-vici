import 'package:flutter/material.dart';

import '../device_identity.dart';
import '../mesh_app.dart';

/// Account, device identity, radio controls, and the way out.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.app});

  final MeshApp app;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final responder = app.role == MeshRole.responder;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      children: [
        Center(
          child: CircleAvatar(
            radius: 40,
            backgroundColor: responder
                ? Colors.blue.shade100
                : theme.colorScheme.secondaryContainer,
            child: Icon(
              responder
                  ? Icons.medical_services_outlined
                  : Icons.person_outline,
              size: 40,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            app.username ?? 'Signed out',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Chip(
            label: Text(app.role.label),
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(height: 28),

        _Group(
          title: 'Device identity',
          children: [
            ListTile(
              leading: const Icon(Icons.fingerprint),
              title: const Text('Origin'),
              subtitle: Text(app.origin),
            ),
            ListTile(
              leading: const Icon(Icons.tag),
              title: const Text('Messages created'),
              // seq is the message counter. It survives sign-out on purpose:
              // ids are hash(origin + seq), so restarting it would reuse the ids
              // of already-sent messages and the mesh would drop them.
              subtitle: const Text('Counter is kept across sign-out'),
              trailing: Text('${app.seq}'),
            ),
          ],
        ),
        const SizedBox(height: 28),

        OutlinedButton.icon(
          onPressed: () => _confirmSignOut(context),
          icon: const Icon(Icons.logout),
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.error,
            minimumSize: const Size.fromHeight(50),
          ),
          label: const Text('Log out'),
        ),
        const SizedBox(height: 12),
        Text(
          'Logging out stops the mesh. Messages this device is carrying for '
          'other people are kept.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
        ),
      ],
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'The mesh stops and this device stops relaying for others until you '
          'log back in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed == true) await app.signOut();
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(title, style: theme.textTheme.titleSmall),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Column(children: children),
        ),
      ],
    );
  }
}
