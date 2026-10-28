part of '../notification_screen.dart';

class _NotificationLoadingCard extends StatelessWidget {
  const _NotificationLoadingCard();

  @override
  Widget build(BuildContext context) {
    return CourierSurfaceCard(
      child: Semantics(
        liveRegion: true,
        label: 'Loading notifications',
        child: Padding(
          padding: EdgeInsets.all(8),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

class _NotificationEmptyCard extends StatelessWidget {
  const _NotificationEmptyCard();

  @override
  Widget build(BuildContext context) {
    return CourierSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.notifications_none_outlined, size: 32),
          const SizedBox(height: 12),
          Text(
            'No notifications yet',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'New pickup schedules and delivery offers will appear here after the server records them.',
          ),
        ],
      ),
    );
  }
}

class _NotificationErrorCard extends StatelessWidget {
  const _NotificationErrorCard({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      container: true,
      child: CourierSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.cloud_off_outlined, color: scheme.error),
            const SizedBox(height: 10),
            Text(message),
            if (onRetry != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: onRetry,
                  child: const Text('Retry'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NotificationStaleBanner extends StatelessWidget {
  const _NotificationStaleBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      container: true,
      label: 'Showing stale notifications. $message',
      child: CourierSurfaceCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.sync_problem_outlined, color: scheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Showing stale notifications. $message',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationInlineMessage extends StatelessWidget {
  const _NotificationInlineMessage({required this.message, required this.icon});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      container: true,
      label: message,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
