part of '../dashboard_screen.dart';

class _DashboardAggregate extends StatelessWidget {
  const _DashboardAggregate({
    required this.snapshot,
    required this.stale,
    required this.onOpenPickups,
    required this.onOpenDeliveries,
    this.onOpenNotifications,
    this.onOpenBatches,
  });
  final DashboardSnapshot snapshot;
  final bool stale;
  final VoidCallback onOpenPickups, onOpenDeliveries;
  final VoidCallback? onOpenNotifications, onOpenBatches;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final key in const [
        'active_tasks',
        'available_tasks',
        'notifications',
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(switch (key) {
                'notifications' => 'Recent notifications',
                'available_tasks' => 'Available work',
                _ => 'Active work',
              }, style: Theme.of(context).textTheme.titleMedium),
              if (stale ||
                  snapshot.section(key).state == DashboardSectionState.stale)
                const Text('Showing earlier results. Refresh before acting.'),
              if (snapshot.section(key).generatedAt != null)
                Text(
                  'Updated ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(DateTime.parse(snapshot.section(key).generatedAt!).toLocal()))}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (snapshot.section(key).state == DashboardSectionState.failed)
                const Text(
                  'This section could not be loaded. Refresh to retry.',
                ),
              if (snapshot.section(key).state == DashboardSectionState.empty)
                Text(
                  key == 'active_tasks'
                      ? 'No active work.'
                      : key == 'available_tasks'
                      ? 'No available work.'
                      : 'No recent notifications.',
                ),
              for (final row in snapshot.section(key).items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    key == 'notifications'
                        ? row['title'] as String
                        : row['order_reference'] as String? ?? 'Courier task',
                  ),
                  subtitle: Text(
                    key == 'notifications'
                        ? row['summary'] as String
                        : '${row['leg'] == 'first_mile' ? 'First mile' : 'Final mile'} · ${(row['status'] as String).replaceAll('_', ' ')}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: key == 'notifications'
                      ? onOpenNotifications
                      : row['leg'] == 'first_mile'
                      ? onOpenPickups
                      : row['status'] == 'delivery_assigned'
                      ? onOpenBatches
                      : onOpenDeliveries,
                ),
              if (snapshot.section(key).hasMore)
                const Text(
                  'Showing the first 5. Open the work screen for more.',
                ),
            ],
          ),
        ),
    ],
  );
}
