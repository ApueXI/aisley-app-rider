part of '../dashboard_screen.dart';

class _WorkDestinations extends StatelessWidget {
  const _WorkDestinations({
    this.onPickups,
    this.onDeliveries,
    this.onBatches,
    this.onHistory,
    this.onLinehaul,
  });

  final VoidCallback? onPickups, onDeliveries, onBatches, onHistory, onLinehaul;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Work')),
    body: ListView(
      key: const PageStorageKey('work-menu'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        CourierSurfaceCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _DestinationRow(
                title: 'Pickup orders',
                subtitle: 'Seller pickups and hub handoff',
                onTap: onPickups,
              ),
              const Divider(height: 1),
              _DestinationRow(
                title: 'Delivery work',
                subtitle: 'Photo proof and delivery review',
                onTap: onDeliveries,
              ),
              const Divider(height: 1),
              _DestinationRow(
                title: 'Final-mile batches',
                subtitle: 'Review individual parcel decisions',
                onTap: onBatches,
              ),
              const Divider(height: 1),
              _DestinationRow(
                title: 'Linehaul jobs',
                subtitle: 'Assigned hub transfers and company-truck routes',
                onTap: onLinehaul,
              ),
              const Divider(height: 1),
              _DestinationRow(
                title: 'Delivery history',
                subtitle: 'Completed deliveries',
                onTap: onHistory,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _AccountDestinations extends StatelessWidget {
  const _AccountDestinations({
    required this.courier,
    this.onProfile,
    this.onSecurity,
    this.onVehicle,
    this.onPolicies,
    this.onSupport,
    this.onSignOut,
  });

  final CourierIdentity courier;
  final VoidCallback? onProfile,
      onSecurity,
      onVehicle,
      onPolicies,
      onSupport,
      onSignOut;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Account')),
    body: ListView(
      key: const PageStorageKey('account-menu'),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      children: [
        CourierSurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: _AccountIdentity(courier: courier),
        ),
        const SizedBox(height: 16),
        CourierSurfaceCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _DestinationRow(
                icon: Icons.manage_accounts_outlined,
                title: 'Profile',
                onTap: onProfile,
              ),
              const Divider(height: 1),
              _DestinationRow(
                icon: Icons.lock_outline,
                title: 'Security',
                subtitle: 'Change your password',
                onTap: onSecurity,
              ),
              const Divider(height: 1),
              _DestinationRow(
                icon: Icons.two_wheeler_outlined,
                title: 'Vehicle and documents',
                onTap: onVehicle,
              ),
              const Divider(height: 1),
              const AppearanceTile(),
              const Divider(height: 1),
              _DestinationRow(
                icon: Icons.policy_outlined,
                title: 'Policies',
                onTap: onPolicies,
              ),
              const Divider(height: 1),
              _DestinationRow(
                icon: Icons.support_agent_outlined,
                title: 'Support tickets',
                onTap: onSupport,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: onSignOut,
          icon: const Icon(Icons.logout),
          label: const Text('Sign out'),
        ),
      ],
    ),
  );
}

class _AccountIdentity extends StatelessWidget {
  const _AccountIdentity({required this.courier});

  final CourierIdentity courier;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final affiliation = courier.logistics;
    final name = courier.displayName;
    final email = courier.email;
    final affiliationNames = [
      _nonEmpty(courier.organizationName),
      _nonEmpty(courier.hubName),
    ].whereType<String>().join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: scheme.primaryContainer,
              foregroundColor: scheme.onPrimaryContainer,
              child: Text(
                _initials(name),
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (email != name) ...[
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                  if (affiliationNames.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.hub_outlined,
                          size: 20,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            affiliationNames,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Divider(height: 1, color: scheme.outlineVariant),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            CourierStatusBadge(
              label: _accountStatusLabel(courier.status),
              tone: CourierStatusTone.neutral,
            ),
            if (affiliation != null)
              CourierStatusBadge(
                label: _affiliationStatusLabel(affiliation.status),
                tone: switch (affiliation.status) {
                  CourierAffiliationStatus.approved =>
                    CourierStatusTone.neutral,
                  CourierAffiliationStatus.pending => CourierStatusTone.warning,
                  CourierAffiliationStatus.rejected ||
                  CourierAffiliationStatus.revoked =>
                    CourierStatusTone.critical,
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _DestinationRow extends StatelessWidget {
  const _DestinationRow({
    required this.title,
    this.icon,
    this.subtitle,
    this.onTap,
  });

  final IconData? icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      minTileHeight: icon == null
          ? 65.5
          : subtitle == null
          ? 56
          : 64,
      minVerticalPadding: 10,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      leading: icon == null ? null : Icon(icon, color: scheme.onSurfaceVariant),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontWeight: icon == null ? FontWeight.w600 : null),
      ),
      subtitle: subtitle == null
          ? (onTap == null ? const Text('Unavailable') : null)
          : Text(
              onTap == null ? '$subtitle · Unavailable' : subtitle!,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontSize: 12),
            ),
      trailing: onTap == null
          ? null
          : Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
      onTap: onTap,
    );
  }
}

String? _nonEmpty(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String _accountStatusLabel(CourierAccountStatus status) => switch (status) {
  CourierAccountStatus.pending => 'Pending',
  CourierAccountStatus.active => 'Active',
  CourierAccountStatus.rejected => 'Rejected',
  CourierAccountStatus.suspended => 'Suspended',
  CourierAccountStatus.deactivated => 'Deactivated',
};

String _affiliationStatusLabel(CourierAffiliationStatus status) =>
    switch (status) {
      CourierAffiliationStatus.pending => 'Affiliation pending',
      CourierAffiliationStatus.approved => 'Affiliation approved',
      CourierAffiliationStatus.rejected => 'Affiliation rejected',
      CourierAffiliationStatus.revoked => 'Affiliation revoked',
    };
