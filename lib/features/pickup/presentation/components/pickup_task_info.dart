part of '../pickup_screen.dart';

class _TaskIdentity extends StatelessWidget {
  const _TaskIdentity({required this.task});

  final PickupTask task;

  @override
  Widget build(BuildContext context) {
    if (task.isFirstMile && task.status == PickupTaskStatus.accepted) {
      final scheme = Theme.of(context).colorScheme;
      final pickupName = task.pickup?.name?.trim();
      final pickupCity = task.pickup?.cityMunicipality?.trim();
      final location = [
        if (pickupName != null && pickupName.isNotEmpty) pickupName,
        if (pickupCity != null && pickupCity.isNotEmpty) pickupCity,
      ].join(' · ');

      return CourierSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final stack =
                    constraints.maxWidth < 330 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.25;
                final heading = Row(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Order reference',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                );
                const status = CourierStatusBadge(
                  label: 'First mile · Pickup accepted',
                  tone: CourierStatusTone.neutral,
                );
                return stack
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [heading, const SizedBox(height: 8), status],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: heading),
                          const SizedBox(width: 8),
                          const Flexible(child: status),
                        ],
                      );
              },
            ),
            const SizedBox(height: 8),
            Text(
              task.order?.displayReference ?? 'Order reference unavailable',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'First-mile seller collection',
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (location.isNotEmpty) ...[
              const SizedBox(height: 16),
              Divider(height: 1, color: scheme.outlineVariant),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.storefront_outlined,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(location)),
                ],
              ),
            ],
          ],
        ),
      );
    }

    return CourierSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CourierSectionHeader(
            title: _taskLegLabel(task),
            subtitle:
                task.order?.displayReference ?? 'Order reference unavailable',
          ),
          if (task.waybill?.displayReference case final reference?) ...[
            const SizedBox(height: 8),
            Text('Waybill $reference'),
          ],
          const SizedBox(height: 12),
          _PickupStatusLabel(status: task.rawStatus),
        ],
      ),
    );
  }
}

class _TaskDetails extends StatelessWidget {
  const _TaskDetails({required this.task});

  final PickupTask task;

  @override
  Widget build(BuildContext context) {
    final pickup = task.pickup;
    final showFullAddress = task.isAccepted || task.hasBeenPickedUp;
    final schedule = task.schedule;
    final rows = <Widget>[
      _DetailRow(
        label: task.isFirstMile ? 'Pickup origin' : 'Pickup location',
        value: pickup?.name ?? _taskLegLabel(task),
      ),
      _DetailRow(
        label: 'Pickup area',
        value: pickup?.areaSummary ?? 'Location unavailable',
      ),
      if (showFullAddress)
        _DetailRow(
          label: 'Authorized pickup address',
          value: pickup?.fullAddress ?? 'Address unavailable',
        ),
      _DetailRow(
        label: 'Destination area',
        value: task.destinationArea?.areaSummary ?? 'Location unavailable',
      ),
      if (task.distanceKm != null)
        _DetailRow(
          label: 'Advisory distance',
          value: '${task.distanceKm!.toStringAsFixed(1)} km',
        ),
      if (task.estimatedDurationMinutes != null)
        _DetailRow(
          label: 'Advisory duration',
          value: '${task.estimatedDurationMinutes} minutes',
        ),
      if (schedule?.startsAt != null)
        _DetailRow(
          label: 'Pickup window',
          value: _formatWindow(schedule) ?? 'Time unavailable',
        ),
    ];

    return CourierSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CourierSectionHeader(title: 'Pickup details'),
          const SizedBox(height: 8),
          ...rows,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Semantics(
        label: '$label: $value',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(value),
          ],
        ),
      ),
    );
  }
}

class _CompletedPickup extends StatelessWidget {
  const _CompletedPickup({
    required this.task,
    required this.controller,
    this.onOpenDelivery,
  });

  final PickupTask task;
  final PickupController controller;
  final VoidCallback? onOpenDelivery;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final firstResult = controller.lastFirstMilePickup;
    final finalResult = controller.lastFinalMilePickup;
    final isAwaitingValidation =
        task.isFinalMile &&
        task.status == PickupTaskStatus.deliveryAccepted &&
        controller.actionStatus(task) ==
            PickupTaskActionStatus.awaitingValidation &&
        finalResult?.taskId == task.id;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isAwaitingValidation
                  ? Icons.hourglass_top_outlined
                  : Icons.check_circle_outline,
              color: scheme.primary,
              size: 32,
            ),
            const SizedBox(height: 10),
            Text(
              isAwaitingValidation
                  ? 'Awaiting Logistics validation'
                  : 'Pickup confirmed',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              isAwaitingValidation
                  ? 'Your hub handoff evidence was submitted. The server has not yet recorded physical custody.'
                  : task.isFirstMile
                  ? 'The server recorded physical pickup from the Seller.'
                  : 'The server recorded the current pickup state for this task.',
            ),
            if (firstResult?.taskId == task.id && firstResult?.nextStep != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text('Next step: ${firstResult!.nextStep}'),
              ),
            if (task.pickedUpAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Recorded ${_formatManilaTimestamp(task.pickedUpAt!)}',
                ),
              ),
            if (task.isFinalMile && onOpenDelivery != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onOpenDelivery,
                icon: const Icon(Icons.route_outlined),
                label: const Text('Open delivery work'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
