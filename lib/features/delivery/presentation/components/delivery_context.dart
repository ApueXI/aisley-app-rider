part of '../delivery_screen.dart';

class _DeliveryIdentity extends StatelessWidget {
  const _DeliveryIdentity({required this.task});

  final PickupTask task;

  @override
  Widget build(BuildContext context) {
    return CourierSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CourierSectionHeader(
            title: 'Final-mile delivery',
            subtitle: task.order?.reference ?? 'Order reference unavailable',
          ),
          if (task.waybill?.reference case final reference?) ...[
            const SizedBox(height: 8),
            Text('Waybill $reference'),
          ],
          const SizedBox(height: 12),
          _DeliveryStatusPill(label: _deliveryStatusLabel(task.rawStatus)),
        ],
      ),
    );
  }
}

class _DeliveryContextCard extends StatelessWidget {
  const _DeliveryContextCard({
    required this.contextData,
    required this.status,
    required this.error,
    required this.onRetry,
    required this.codCollection,
    required this.cashAcknowledged,
    required this.canAcknowledgeCash,
    required this.onCashAcknowledged,
    required this.isReviewPending,
  });

  final DeliveryContext? contextData;
  final DeliveryLoadStatus status;
  final String? error;
  final VoidCallback onRetry;
  final DeliveryCodCollection? codCollection;
  final bool cashAcknowledged;
  final bool canAcknowledgeCash;
  final ValueChanged<bool> onCashAcknowledged;
  final bool isReviewPending;

  @override
  Widget build(BuildContext context) {
    final collection = codCollection;
    if ((status == DeliveryLoadStatus.idle ||
            status == DeliveryLoadStatus.loading) &&
        contextData == null) {
      return const _DeliveryLoadingCard();
    }
    if (contextData == null) {
      return _DeliveryErrorCard(
        message: error ?? 'Delivery context is unavailable.',
        status: status,
        onRetry: onRetry,
        onOpenPolicies: () {},
        showPolicyAction: false,
      );
    }
    final data = contextData!;
    final destination = data.destination;
    final hub = data.hub;
    return CourierSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CourierSectionHeader(title: 'Delivery details'),
          const SizedBox(height: 8),
          _DeliveryDetailRow(
            label: 'Pickup hub',
            value: hub?.fullAddress ?? hub?.areaSummary ?? 'Hub unavailable',
          ),
          _DeliveryDetailRow(
            label: 'Destination',
            value:
                destination?.fullAddress ??
                destination?.areaSummary ??
                'Destination unavailable',
          ),
          if (data.recipientName != null)
            _DeliveryDetailRow(label: 'Recipient', value: data.recipientName!),
          if (data.recipientPhone != null)
            _DeliveryDetailRow(
              label: 'Contact number',
              value: data.recipientPhone!,
            ),
          if (data.deliveryInstructions != null)
            _DeliveryDetailRow(
              label: 'Delivery instructions',
              value: data.deliveryInstructions!,
            ),
          const SizedBox(height: 6),
          _RouteMetrics(contextData: data),
          if (data.paymentMethod == 'cod') ...[
            const Divider(height: 28),
            const CourierSectionHeader(title: 'Cash due'),
            if (collection == null) ...[
              const SizedBox(height: 6),
              const Text(
                'The cash amount cannot be confirmed. Refresh delivery details before submitting Delivered.',
              ),
            ] else ...[
              const SizedBox(height: 4),
              Text(
                collection.displayAmount,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (isReviewPending) ...[
                const SizedBox(height: 8),
                const Text(
                  'The cash collection declaration was included with the submitted Delivered intent. Logistics validation is pending.',
                ),
              ] else ...[
                const SizedBox(height: 4),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: cashAcknowledged,
                  onChanged: canAcknowledgeCash
                      ? (value) => onCashAcknowledged(value == true)
                      : null,
                  title: Text(
                    'I collected ${collection.displayAmount} in full.',
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ],
          ],
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}

class _RouteMetrics extends StatelessWidget {
  const _RouteMetrics({required this.contextData});

  final DeliveryContext contextData;

  @override
  Widget build(BuildContext context) {
    final metrics = <String>[
      if (contextData.distanceKm != null)
        'Advisory distance: ${contextData.distanceKm!.toStringAsFixed(1)} km',
      if (contextData.estimatedDurationMinutes != null)
        'Advisory duration: ${contextData.estimatedDurationMinutes} minutes',
    ];
    final routeStatus = contextData.routeStatus;
    final hasMetrics = metrics.isNotEmpty;
    final calculatedAt = contextData.calculatedAt;
    return Semantics(
      label: hasMetrics
          ? [
              ...metrics,
              if (calculatedAt != null)
                'calculated ${_formatTimestamp(calculatedAt)}',
            ].join('. ')
          : 'Route metrics unavailable',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasMetrics) ...[
            for (final metric in metrics) Text(metric),
            if (calculatedAt != null)
              Text(
                'Calculated ${_formatTimestamp(calculatedAt)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ] else
            Text(
              routeStatus == 'stale'
                  ? 'Route metrics are stale and advisory. Refresh before relying on them.'
                  : 'Route metrics unavailable. Continue with the authorized destination details.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}
