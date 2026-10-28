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
      padding: const EdgeInsets.all(16),
      children: [
        CourierSectionHeader(
          title: 'Work lists',
          subtitle: 'Choose a list to review current work.',
        ),
        const SizedBox(height: 12),
        CourierSurfaceCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _DestinationRow(
                icon: Icons.inventory_2_outlined,
                title: 'Pickup orders',
                subtitle: 'Seller pickups and hub handoff',
                onTap: onPickups,
              ),
              const Divider(height: 1),
              _DestinationRow(
                icon: Icons.local_shipping_outlined,
                title: 'Delivery work',
                subtitle: 'Movement, evidence and delivery review',
                onTap: onDeliveries,
              ),
              const Divider(height: 1),
              _DestinationRow(
                icon: Icons.view_list_outlined,
                title: 'Final-mile batches',
                subtitle: 'Review individual parcel decisions',
                onTap: onBatches,
              ),
              const Divider(height: 1),
              _DestinationRow(
                icon: Icons.route_outlined,
                title: 'Linehaul jobs',
                subtitle: 'Assigned hub transfers and company-truck routes',
                onTap: onLinehaul,
              ),
              const Divider(height: 1),
              _DestinationRow(
                icon: Icons.history_outlined,
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
      padding: const EdgeInsets.all(16),
      children: [
        CourierSurfaceCard(child: _AccountIdentity(courier: courier)),
        const SizedBox(height: 20),
        CourierSectionHeader(title: 'Account settings'),
        const SizedBox(height: 12),
        CourierSurfaceCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _DestinationRow(
                icon: Icons.manage_accounts_outlined,
                title: 'Profile',
                subtitle: 'Personal details and profile photo',
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
                subtitle: 'Vehicle details, official receipt and registration',
                onTap: onVehicle,
              ),
              const Divider(height: 1),
              _DestinationRow(
                icon: Icons.policy_outlined,
                title: 'Policies',
                subtitle: 'Current versions and consent history',
                onTap: onPolicies,
              ),
              const Divider(height: 1),
              _DestinationRow(
                icon: Icons.support_agent_outlined,
                title: 'Support tickets',
                subtitle: 'Contact platform support',
                onTap: onSupport,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
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
    final name = courier.displayName;
    final email = courier.email;
    final affiliation = courier.logistics;
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
              radius: 24,
              backgroundColor: scheme.surfaceContainerHighest,
              foregroundColor: scheme.onSurface,
              child: Text(_initials(name)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleMedium),
                  if (email != name) ...[
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            CourierStatusBadge(
              label: _accountStatusLabel(courier.status),
              tone: courier.status == CourierAccountStatus.active
                  ? CourierStatusTone.success
                  : CourierStatusTone.neutral,
            ),
            if (affiliation != null)
              CourierStatusBadge(
                label: _affiliationStatusLabel(affiliation.status),
                tone: switch (affiliation.status) {
                  CourierAffiliationStatus.approved =>
                    CourierStatusTone.success,
                  CourierAffiliationStatus.pending => CourierStatusTone.warning,
                  CourierAffiliationStatus.rejected ||
                  CourierAffiliationStatus.revoked =>
                    CourierStatusTone.critical,
                },
              ),
          ],
        ),
        if (affiliationNames.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            affiliationNames,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

class _DestinationRow extends StatelessWidget {
  const _DestinationRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title, subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      minVerticalPadding: 8,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, color: scheme.primary),
      title: Text(title),
      subtitle: Text(onTap == null ? '$subtitle · Unavailable' : subtitle),
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
