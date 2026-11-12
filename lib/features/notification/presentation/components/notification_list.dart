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
        _NotificationFilterBar(controller: controller),
        const SizedBox(height: 12),
        _NotificationCategoryBar(controller: controller),
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
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final filter in NotificationFilter.values)
            ChoiceChip(
              key: ValueKey('notification-filter-${filter.apiValue}'),
              label: Text(
                filter == NotificationFilter.unread &&
                        controller.unreadCount != null
                    ? 'Unread (${controller.unreadCount})'
                    : filter.label,
              ),
              selected: controller.filter == filter,
              onSelected: (_) => controller.setFilter(filter),
            ),
        ],
      ),
    );
  }
}

class _NotificationCategoryBar extends StatelessWidget {
  const _NotificationCategoryBar({required this.controller});

  final NotificationController controller;

  @override
  Widget build(BuildContext context) {
    final selectedCategory = controller.categories.firstWhere(
      (category) => category.key == controller.category,
      orElse: () => const NotificationCategory(key: 'other', label: 'Other'),
    );
    return Semantics(
      container: true,
      label: 'Filter notifications by category',
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: PopupMenuButton<String>(
          key: const ValueKey('notification-category-filter'),
          tooltip: 'Choose a notification category',
          onSelected: controller.setCategory,
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              key: const ValueKey('notification-category-all'),
              value: 'all',
              child: _CategoryMenuLabel(
                label: 'All categories',
                selected: controller.category == 'all',
              ),
            ),
            for (final category in controller.categories)
              PopupMenuItem<String>(
                key: ValueKey('notification-category-${category.key}'),
                value: category.key,
                child: _CategoryMenuLabel(
                  label: category.label,
                  selected: controller.category == category.key,
                ),
              ),
          ],
          child: LayoutBuilder(
            builder: (context, constraints) => SizedBox(
              width: constraints.maxWidth,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Category filters',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              if (controller.category != 'all')
                                Text(
                                  selectedCategory.label,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.expand_more),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryMenuLabel extends StatelessWidget {
  const _CategoryMenuLabel({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (selected) ...[
          Icon(
            Icons.check,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
        ],
        Expanded(child: Text(label, softWrap: true)),
      ],
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});
  final CourierNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => CourierSurfaceCard(
    onTap: onTap,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _notificationIcon(notification.category),
              color: Theme.of(context).colorScheme.primary,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  CourierStatusBadge(
                    label: notification.categoryLabel,
                    tone: CourierStatusTone.neutral,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatNotificationDate(context, notification.createdAt),
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  CourierStatusBadge(
                    label: notification.isRead ? 'Read' : 'Unread',
                    tone: notification.isRead
                        ? CourierStatusTone.neutral
                        : CourierStatusTone.warning,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          notification.title,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(notification.summary),
      ],
    ),
  );
}

IconData _notificationIcon(String category) => switch (category) {
  'pickups' => Icons.inventory_2_outlined,
  'deliveries' => Icons.local_shipping_outlined,
  'linehaul' => Icons.swap_horiz,
  'support' => Icons.support_agent_outlined,
  _ => Icons.notifications_none_outlined,
};

String _formatNotificationDate(BuildContext context, DateTime value) {
  final local = value.toLocal();
  final date = MaterialLocalizations.of(context).formatMediumDate(local);
  final time = MaterialLocalizations.of(context)
      .formatTimeOfDay(TimeOfDay.fromDateTime(local));
  return '$date at $time';
}
