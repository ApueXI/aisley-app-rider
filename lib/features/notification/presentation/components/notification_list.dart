part of '../notification_screen.dart';

class _NotificationListBody extends StatelessWidget {
  const _NotificationListBody({
    required this.controller,
    required this.onOpenNotification,
  });

  final NotificationController controller;
  final ValueChanged<CourierNotification> onOpenNotification;

  @override
  Widget build(BuildContext context) {
    final items = controller.items;
    final hasBlockingError =
        items.isEmpty &&
        controller.listStatus != NotificationLoadStatus.idle &&
        controller.listStatus != NotificationLoadStatus.loading &&
        controller.listStatus != NotificationLoadStatus.empty &&
        controller.listStatus != NotificationLoadStatus.loaded;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(
          'Courier inbox',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Updates about your scheduled and offered work.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        _NotificationFilterBar(controller: controller),
        const SizedBox(height: 16),
        if (controller.unreadCount != null)
          _UnreadCountSummary(count: controller.unreadCount!),
        if (controller.countErrorMessage != null) ...[
          const SizedBox(height: 12),
          _NotificationInlineMessage(
            message: controller.countErrorMessage!,
            icon: Icons.info_outline,
          ),
        ],
        if (controller.hasStaleItems &&
            controller.listErrorMessage != null) ...[
          const SizedBox(height: 12),
          _NotificationStaleBanner(message: controller.listErrorMessage!),
        ],
        const SizedBox(height: 12),
        if ((controller.listStatus == NotificationLoadStatus.idle ||
                controller.listStatus == NotificationLoadStatus.loading) &&
            items.isEmpty)
          const _NotificationLoadingCard()
        else if (hasBlockingError)
          _NotificationErrorCard(
            message:
                controller.listErrorMessage ?? 'Notifications are unavailable.',
            onRetry: controller.canRetryRateLimit ? controller.refresh : null,
          )
        else if (controller.listStatus == NotificationLoadStatus.empty ||
            items.isEmpty)
          const _NotificationEmptyCard()
        else ...[
          for (final notification in items) ...[
            _NotificationCard(
              notification: notification,
              onTap: () => onOpenNotification(notification),
            ),
            const SizedBox(height: 10),
          ],
          if (controller.loadMoreErrorMessage != null)
            _NotificationInlineMessage(
              message: controller.loadMoreErrorMessage!,
              icon: Icons.cloud_off_outlined,
            ),
          if (controller.canLoadMore) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: controller.isLoadingMore ? null : controller.loadMore,
              icon: controller.isLoadingMore
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more),
              label: const Text('Load older notifications'),
            ),
          ],
        ],
      ],
    );
  }
}

class _NotificationFilterBar extends StatelessWidget {
  const _NotificationFilterBar({required this.controller});

  final NotificationController controller;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Notification filter',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final filter in NotificationFilter.values) ...[
              FilterChip(
                label: Text(filter.label),
                selected: controller.filter == filter,
                onSelected: (_) => controller.setFilter(filter),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _UnreadCountSummary extends StatelessWidget {
  const _UnreadCountSummary({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: '$count unread notification${count == 1 ? '' : 's'}',
      child: Text(
        '$count unread notification${count == 1 ? '' : 's'}',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});
  final CourierNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        title: Text(
          notification.title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(notification.summary),
            const SizedBox(height: 8),
            Text(
              '${notification.isRead ? 'Read' : 'Unread'} · ${_formatNotificationDate(context, notification.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
      const Divider(height: 1),
    ],
  );
}

String _formatNotificationDate(BuildContext context, DateTime value) {
  final local = value.toLocal();
  final date = MaterialLocalizations.of(context).formatMediumDate(local);
  final time = MaterialLocalizations.of(context)
      .formatTimeOfDay(TimeOfDay.fromDateTime(local));
  return '$date at $time';
}
