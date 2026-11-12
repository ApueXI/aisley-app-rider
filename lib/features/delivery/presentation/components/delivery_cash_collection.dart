part of '../delivery_screen.dart';

class _DeliveryCashCollectionCard extends StatelessWidget {
  const _DeliveryCashCollectionCard({
    required this.contextData,
    required this.isReviewPending,
    required this.cashAcknowledged,
    required this.canAcknowledge,
    required this.onCashAcknowledged,
  });

  final DeliveryContext? contextData;
  final bool isReviewPending;
  final bool cashAcknowledged;
  final bool canAcknowledge;
  final ValueChanged<bool> onCashAcknowledged;

  @override
  Widget build(BuildContext context) {
    final collection = contextData?.codCollection;
    return CourierSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CourierSectionHeader(title: 'Cash collection'),
          if (collection == null) ...[
            const SizedBox(height: 12),
            const Text(
              'The authorized cash amount is unavailable. Refresh delivery details before submitting Delivered.',
            ),
          ] else ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Amount to collect',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    collection.displayAmount,
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (isReviewPending)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                leading: const Icon(Icons.pending_outlined),
                title: Text('${collection.displayAmount} submitted for review'),
                subtitle: const Text(
                  'The cash declaration was included with the Delivered intent and is awaiting Logistics validation.',
                ),
              )
            else ...[
              const SizedBox(height: 8),
              MergeSemantics(
                child: InkWell(
                  onTap: canAcknowledge
                      ? () => onCashAcknowledged(!cashAcknowledged)
                      : null,
                  canRequestFocus: false,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: cashAcknowledged,
                          onChanged: canAcknowledge
                              ? (value) => onCashAcknowledged(value == true)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'I collected ${collection.displayAmount} in full.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Confirm physical receipt of the exact cash amount before handoff.',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(12),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Submission goes to Logistics review before completion.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
