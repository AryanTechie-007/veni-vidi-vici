import 'package:flutter/material.dart';

import '../mesh_service.dart';

/// The one sensible next step for each fault, shared by the banner and the
/// dialog so they can never disagree about what the fix is.
VoidCallback? faultAction(MeshService service) => switch (service.fault) {
  MeshFault.permissionsDenied => () async {
    if (await service.requestPermissions()) await service.start();
  },
  MeshFault.permissionsBlocked => service.openSettings,
  MeshFault.radioUnavailable => service.start,
  // Only the user can flip the system location toggle.
  MeshFault.locationOff || MeshFault.none => null,
};

/// Supporting detail: which permissions are missing, and the raw error.
String faultDetail(MeshService service) => [
  if (service.missingPermissions.isNotEmpty)
    'Missing: ${service.missingPermissions.join(', ')}',
  if (service.faultDetail != null) service.faultDetail!,
].join('\n');

/// Raised when the mesh fails to come up.
///
/// A failed start is otherwise silent — the app looks idle rather than broken —
/// so it is worth interrupting for. The banner stays behind it as the
/// persistent reminder once this is dismissed.
Future<void> showMeshFaultDialog(
  BuildContext context,
  MeshService service,
) async {
  final fault = service.fault;
  if (fault == MeshFault.none) return;

  final theme = Theme.of(context);
  final action = faultAction(service);
  final detail = faultDetail(service);

  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.wifi_tethering_off),
      title: const Text('Mesh could not start'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(fault.message),
          if (fault == MeshFault.locationOff) ...[
            const SizedBox(height: 12),
            Text(
              'Turn it on in Android quick settings, then press Start on the '
              'home screen.',
              style: theme.textTheme.bodyMedium,
            ),
          ],
          if (detail.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              detail,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(action == null ? 'OK' : 'Not now'),
        ),
        if (action != null && fault.actionLabel != null)
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              action();
            },
            child: Text(fault.actionLabel!),
          ),
      ],
    ),
  );
}
