part of '../delivery_screen.dart';

class _DeliveryIdentity extends StatelessWidget {
  const _DeliveryIdentity({
    required this.task,
    required this.contextData,
    required this.contextStatus,
    required this.contextError,
    required this.onRetry,
  });

  final PickupTask task;
  final DeliveryContext? contextData;
  final DeliveryLoadStatus contextStatus;
  final String? contextError;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final area = contextData?.destination?.areaSummary;
    return CourierSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              Text(
                'Task reference',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              _DeliveryStatusPill(
                label: _deliveryTaskStatusBadgeLabel(task.rawStatus),
              ),
            ],
          ),
          const Divider(height: 28),
          Text(
            task.order?.reference ?? 'Order reference unavailable',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (area != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(area)),
              ],
            ),
          ],
          if (contextData case final data?) ...[
            if (data.destination case final destination?)
              _DeliveryDetailRow(
                label: 'Destination',
                value: destination.fullAddress == 'Address unavailable'
                    ? destination.areaSummary
                    : destination.fullAddress,
              ),
            if (data.recipientName != null)
              _DeliveryDetailRow(
                label: 'Recipient',
                value: data.recipientName!,
              ),
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
            if (data.hub?.name case final hubName?)
              _DeliveryDetailRow(label: 'Assigned hub', value: hubName),
            if (task.waybill?.reference case final waybill?)
              _DeliveryDetailRow(label: 'Waybill', value: waybill),
            if (data.hub?.fullAddress != null ||
                data.distanceKm != null ||
                data.estimatedDurationMinutes != null)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Hub & route details'),
                children: [
                  _DeliveryDetailRow(
                    label: 'Hub address',
                    value:
                        data.hub?.fullAddress ??
                        data.hub?.areaSummary ??
                        'Hub address unavailable',
                  ),
                  _RouteMetrics(contextData: data),
                ],
              ),
          ] else if (contextStatus == DeliveryLoadStatus.loading ||
              contextStatus == DeliveryLoadStatus.idle) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ] else ...[
            const SizedBox(height: 8),
            Text(contextError ?? 'Delivery details are unavailable.'),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh delivery details'),
              ),
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
