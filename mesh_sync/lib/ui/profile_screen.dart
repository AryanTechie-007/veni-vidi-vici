import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../device_identity.dart';
import '../mesh_app.dart';
import 'network_screen.dart';

/// Account, identity, and the way out.
///
/// Mesh state lives on Home and in the Network view — this page is about who
/// you are, not what the radio is doing.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.app});

  final MeshApp app;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final responder = app.role == MeshRole.responder;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: responder
                    ? Colors.blue.shade100
                    : theme.colorScheme.secondaryContainer,
                child: Icon(
                  responder
                      ? Icons.medical_services_outlined
                      : Icons.person_outline,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.username ?? 'Signed out',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(app.role.label, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 6),
                    // Shortened: the full origin is 16 hex characters and
                    // nobody reads it, but it is the only identity there is,
                    // so it stays copyable.
                    InkWell(
                      onTap: () => _copyId(context),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Device ID: ${_shortId(app.origin)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.hintColor,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.copy, size: 13, color: theme.hintColor),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        _Row(
          icon: Icons.badge_outlined,
          title: 'My role',
          trailing: app.role.label,
        ),
        _Row(
          icon: Icons.hub_outlined,
          title: 'Network',
          trailing: '${app.service.peers.length} peers',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => NetworkScreen(app: app)),
          ),
        ),
        _Row(
          icon: Icons.tag,
          title: 'Messages created',
          // seq is the message counter. It survives sign-out on purpose: ids
          // are hash(origin + seq), so restarting it would reuse the ids of
          // already-sent messages and the mesh would drop them as duplicates.
          trailing: '${app.seq}',
        ),
        _Row(
          icon: Icons.info_outline,
          title: 'About MeshSync',
          onTap: () => _showAbout(context),
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

  static String _shortId(String origin) =>
      '${origin.substring(0, 4)}…${origin.substring(origin.length - 4)}';

  Future<void> _copyId(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: app.origin));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Device ID copied')));
  }

  void _showAbout(BuildContext context) => showAboutDialog(
    context: context,
    applicationName: 'MeshSync',
    applicationVersion: '1.0.0',
    children: const [
      Text(
        'Sends an SOS device to device over short-range radio when there is '
        'no network. Messages hop from phone to phone until they reach a '
        'responder, and a phone that is simply carried from one place to '
        'another is a valid way to move them.',
      ),
    ],
  );

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

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(icon),
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null)
            Text(
              trailing!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor,
              ),
            ),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: theme.hintColor),
          ],
        ],
      ),
      onTap: onTap,
    );
  }
}
