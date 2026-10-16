part of '../dashboard_screen.dart';

class _DashboardErrorBanner extends StatelessWidget {
  const _DashboardErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.cloud_off_outlined, color: scheme.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: TextStyle(color: scheme.onErrorContainer),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: onRetry,
                      child: Text(
                        'Retry',
                        style: TextStyle(color: scheme.onErrorContainer),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegacyWorkStatus extends StatelessWidget {
  const _LegacyWorkStatus({
    required this.snapshot,
    required this.loading,
    required this.stale,
    required this.hasPreviews,
  });
  final DashboardSnapshot? snapshot;
  final bool loading, stale, hasPreviews;

  @override
  Widget build(BuildContext context) {
    final data = snapshot;
    if (data == null) {
      return loading
          ? const Column(
              children: [
                Text('Checking work…'),
                SizedBox(height: 12),
                LinearProgressIndicator(),
              ],
            )
          : const SizedBox.shrink();
    }
    final unavailable =
        const ['active_tasks', 'available_tasks', 'notifications'].every(
          (key) => data.section(key).state == DashboardSectionState.unavailable,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (loading) const Text('Refreshing work…'),
        if (stale)
          const Text(
            'Showing earlier work information. Refresh before acting.',
          ),
        if (unavailable)
          Semantics(
            liveRegion: true,
            child: Text(
              hasPreviews
                  ? 'Work summaries are unavailable. Showing limited work previews.'
                  : 'Work summaries are unavailable. Open a work list for current tasks.',
            ),
          )
        else
          for (final key in const [
            'active_tasks',
            'available_tasks',
            'notifications',
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(switch (key) {
                    'active_tasks' => 'Active work',
                    'available_tasks' => 'Available work',
                    _ => 'Notifications',
                  }, style: Theme.of(context).textTheme.titleMedium),
                  Text(switch (data.section(key).state) {
                    DashboardSectionState.unavailable => 'Unavailable',
                    DashboardSectionState.failed => 'Could not load',
                    DashboardSectionState.stale => 'Needs refresh',
                    DashboardSectionState.empty => 'Nothing to show',
                    DashboardSectionState.available => 'Ready',
                    _ => 'Availability not checked',
                  }),
                ],
              ),
            ),
      ],
    );
  }
}
