part of '../dashboard_screen.dart';

class _WorkDestinations extends StatelessWidget {
  const _WorkDestinations({
    this.onPickups,
    this.onDeliveries,
    this.onBatches,
    this.onHistory,
  });
  final VoidCallback? onPickups, onDeliveries, onBatches, onHistory;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Work')),
    body: ListView(
      key: const PageStorageKey('work-menu'),
      padding: const EdgeInsets.all(16),
      children: [
        _DestinationRow(
          icon: Icons.inventory_2_outlined,
          title: 'Pickup orders',
          subtitle: 'Seller pickups and hub handoff',
          onTap: onPickups,
        ),
        _DestinationRow(
          icon: Icons.local_shipping_outlined,
          title: 'Delivery work',
          subtitle: 'Movement, evidence and delivery review',
          onTap: onDeliveries,
        ),
        _DestinationRow(
          icon: Icons.view_list_outlined,
          title: 'Final-mile batches',
          subtitle: 'Review and accept dispatch batches',
          onTap: onBatches,
        ),
        _DestinationRow(
          icon: Icons.history_outlined,
          title: 'Delivery history',
          subtitle: 'Completed deliveries',
          onTap: onHistory,
        ),
      ],
    ),
  );
}

class _AccountDestinations extends StatelessWidget {
  const _AccountDestinations({
    required this.name,
    this.onProfile,
    this.onSecurity,
    this.onVehicle,
    this.onPolicies,
    this.onSupport,
    this.onSignOut,
  });
  final String name;
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
        Text(name, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        _DestinationRow(
          icon: Icons.manage_accounts_outlined,
          title: 'Profile',
          subtitle: 'Personal details and profile photo',
          onTap: onProfile,
        ),
        _DestinationRow(
          icon: Icons.lock_outline,
          title: 'Security',
          subtitle: 'Change your password',
          onTap: onSecurity,
        ),
        _DestinationRow(
          icon: Icons.two_wheeler_outlined,
          title: 'Vehicle and documents',
          subtitle: 'Vehicle details, official receipt and registration',
          onTap: onVehicle,
        ),
        _DestinationRow(
          icon: Icons.policy_outlined,
          title: 'Policies',
          subtitle: 'Current versions and consent history',
          onTap: onPolicies,
        ),
        _DestinationRow(
          icon: Icons.support_agent_outlined,
          title: 'Support tickets',
          subtitle: 'Contact platform support',
          onTap: onSupport,
        ),
        const SizedBox(height: 24),
        TextButton.icon(
          onPressed: onSignOut,
          icon: const Icon(Icons.logout),
          label: const Text('Sign out'),
        ),
      ],
    ),
  );
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
  Widget build(BuildContext context) => Column(
    children: [
      ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(onTap == null ? '$subtitle · Unavailable' : subtitle),
        trailing: onTap == null ? null : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
      const Divider(height: 1),
    ],
  );
}
