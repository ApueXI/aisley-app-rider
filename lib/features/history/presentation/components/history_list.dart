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
          Text(
            'Completed deliveries',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Search completed deliveries by their full order reference.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
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
  Widget build(BuildContext context) => TaskRow(
    reference: item.order?.displayReference ?? 'Order reference unavailable',
    leg: 'Final mile',
    status: _historyStatusLabel(item.status),
    location: _areaRouteLabel(item),
    nextStep: item.deliveredAt == null
        ? 'Delivered time unavailable'
        : 'Delivered ${_formatHistoryTimestamp(item.deliveredAt!)}',
    onTap: onTap,
  );
}
