part of '../dashboard_screen.dart';

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.courier});

  final CourierIdentity courier;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final organization = courier.organizationName;
    final hub = courier.hubName;
    final affiliation = [?organization, ?hub].join(' · ');

    return CourierSurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  courier.displayName,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (affiliation.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    affiliation,
                    style: Theme.of(context).textTheme.bodyLarge
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
        _WorkShortcut(label: 'Pickup orders', onTap: onOpenPickups!),
      if (onOpenDeliveries != null)
        _WorkShortcut(label: 'Delivery work', onTap: onOpenDeliveries!),
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
  const _WorkShortcut({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CourierSurfaceCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: SizedBox(
        height: 48,
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
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
