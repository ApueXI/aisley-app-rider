part of '../dashboard_screen.dart';

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.courier, this.profilePhoto});

  final CourierIdentity courier;
  final ProfilePhotoData? profilePhoto;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final organization = courier.organizationName;
    final hub = courier.hubName;
    final affiliation = [?organization, ?hub].join(' · ');
    final photoBytes = profilePhoto?.bytes;

    return CourierSurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: scheme.surfaceContainerHighest,
            foregroundColor: scheme.onSurface,
            child: photoBytes == null || photoBytes.isEmpty
                ? Text(_initials(courier.displayName))
                : ClipOval(
                    child: Image.memory(
                      photoBytes,
                      key: const ValueKey<String>('dashboard-profile-photo'),
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      semanticLabel: '${courier.displayName} profile photo',
                      errorBuilder: (context, error, stack) =>
                          Text(_initials(courier.displayName)),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  courier.displayName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (affiliation.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    affiliation,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkShortcuts extends StatelessWidget {
  const _WorkShortcuts({this.onOpenPickups, this.onOpenDeliveries});

  final VoidCallback? onOpenPickups, onOpenDeliveries;

  @override
  Widget build(BuildContext context) {
    final shortcuts = [
      if (onOpenPickups != null)
        _WorkShortcut(
          icon: Icons.inventory_2_outlined,
          label: 'Pickup orders',
          onTap: onOpenPickups!,
        ),
      if (onOpenDeliveries != null)
        _WorkShortcut(
          icon: Icons.local_shipping_outlined,
          label: 'Delivery work',
          onTap: onOpenDeliveries!,
        ),
    ];

    if (shortcuts.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final stack =
            constraints.maxWidth < 340 ||
            !constraints.maxWidth.isFinite ||
            textScale > 1.25;

        if (stack) {
          return Column(
            children: [
              for (var index = 0; index < shortcuts.length; index++) ...[
                if (index > 0) const SizedBox(height: 8),
                SizedBox(width: double.infinity, child: shortcuts[index]),
              ],
            ],
          );
        }

        return Row(
          children: [
            for (var index = 0; index < shortcuts.length; index++) ...[
              if (index > 0) const SizedBox(width: 8),
              Expanded(child: shortcuts[index]),
            ],
          ],
        );
      },
    );
  }
}

class _WorkShortcut extends StatelessWidget {
  const _WorkShortcut({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CourierSurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: scheme.primary, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.titleSmall),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

String _initials(String value) {
  final parts = value.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) {
    return '?';
  }
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
      .toUpperCase();
}
