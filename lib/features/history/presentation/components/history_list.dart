part of '../history_screen.dart';

class _HistoryListBody extends StatelessWidget {
  const _HistoryListBody({
    required this.controller,
    required this.onOpenItem,
    required this.onRetry,
    required this.onOpenPolicies,
    required this.showPolicyAction,
  });

  final HistoryController controller;
  final ValueChanged<DeliveryHistoryItem> onOpenItem;
  final VoidCallback onRetry;
  final VoidCallback onOpenPolicies;
  final bool showPolicyAction;

  @override
  Widget build(BuildContext context) {
    final status = controller.status;
    final items = controller.items;
    final blocking =
        status != HistoryLoadStatus.idle &&
        status != HistoryLoadStatus.loading &&
        status != HistoryLoadStatus.loaded &&
        status != HistoryLoadStatus.empty;

    return SingleChildScrollView(
      key: const PageStorageKey('delivery-history'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CourierSectionHeader(
            title: 'Delivery history',
            subtitle: 'Completed final-mile deliveries',
          ),
          const SizedBox(height: 16),
          _HistoryReferenceSearch(controller: controller),
          const SizedBox(height: 16),
          if ((status == HistoryLoadStatus.idle ||
                  status == HistoryLoadStatus.loading) &&
              items.isEmpty)
            const _HistoryLoadingCard()
          else if (blocking && items.isEmpty)
            _HistoryErrorCard(
              message:
                  controller.errorMessage ?? 'Delivery history is unavailable.',
              status: status,
              onRetry: onRetry,
              canRetry: controller.canRetryRateLimit,
              onOpenPolicies: onOpenPolicies,
              showPolicyAction: showPolicyAction,
            )
          else if (status == HistoryLoadStatus.empty || items.isEmpty)
            _HistoryEmptyCard(filtered: controller.activeReference != null)
          else ...[
            if (status == HistoryLoadStatus.loading) ...[
              Semantics(
                liveRegion: true,
                label: 'Refreshing delivery history',
                child: const LinearProgressIndicator(),
              ),
              const SizedBox(height: 12),
            ],
            for (final item in items) ...[
              _HistoryItemCard(item: item, onTap: () => onOpenItem(item)),
              const SizedBox(height: 10),
            ],
            if (controller.errorMessage != null)
              _HistoryInlineError(
                message: controller.errorMessage!,
                onRetry: onRetry,
                canRetry: controller.canRetryRateLimit,
              ),
            if (controller.hasMore) ...[
              const SizedBox(height: 12),
              Text(
                'More completed deliveries may be available. Search by the full order reference.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _HistoryItemCard extends StatelessWidget {
  const _HistoryItemCard({required this.item, required this.onTap});
  final DeliveryHistoryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CourierSurfaceCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.order?.displayReference ?? 'Order reference unavailable',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              CourierStatusBadge(
                label: _historyStatusLabel(item.status),
                tone: item.status == 'delivered'
                    ? CourierStatusTone.success
                    : CourierStatusTone.neutral,
              ),
              const CourierStatusBadge(
                label: 'Final mile',
                tone: CourierStatusTone.info,
              ),
              const CourierStatusBadge(label: 'Read-only'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.deliveredAt == null
                ? 'Delivered time unavailable'
                : 'Delivered ${_formatHistoryTimestamp(item.deliveredAt!)}',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(_areaRouteLabel(item))),
            ],
          ),
          if (item.itemCount != null || item.evidenceStatus != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                if (item.itemCount != null)
                  Text(
                    '${item.itemCount} ${item.itemCount == 1 ? 'item' : 'items'}',
                    style: theme.textTheme.bodySmall,
                  ),
                if (item.evidenceStatus != null)
                  Text(
                    item.evidenceStatus == 'validated'
                        ? 'Proof validated'
                        : 'Proof status unavailable',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
