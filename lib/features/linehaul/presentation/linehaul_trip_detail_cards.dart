part of 'linehaul_trip_detail.dart';

class _LinehaulJobSummary extends StatelessWidget {
  const _LinehaulJobSummary({required this.trip});

  final LinehaulTrip trip;

  @override
  Widget build(BuildContext context) {
    final status = trip.status == 'in_transfer'
        ? 'In transfer'
        : _linehaulStatusLabel(trip.status);
    return CourierSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(
                Icons.local_shipping_outlined,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              Text('Job ID: ${trip.id}'),
              CourierStatusBadge(
                label: status,
                tone: trip.status == 'rejected' || trip.status == 'cancelled'
                    ? CourierStatusTone.critical
                    : CourierStatusTone.info,
              ),
            ],
          ),
          const Divider(height: 28),
          _HubStop(
            icon: Icons.radio_button_unchecked,
            label: 'Origin',
            value: trip.fromHub,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 11),
            child: Container(
              width: 2,
              height: 20,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          _HubStop(
            icon: Icons.location_on_outlined,
            label: 'Destination',
            value: trip.toHub,
          ),
        ],
      ),
    );
  }
}

class _HubStop extends StatelessWidget {
  const _HubStop({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    ],
  );
}

class _ArrivalReportedCard extends StatelessWidget {
  const _ArrivalReportedCard({required this.arrivedAt});

  final DateTime arrivedAt;

  @override
  Widget build(BuildContext context) => CourierSurfaceCard(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.flag_outlined, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Arrival reported',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(formatTripDate(arrivedAt)),
            ],
          ),
        ),
        const Icon(Icons.check_circle_outline),
      ],
    ),
  );
}

class _WaitForLogisticsCard extends StatelessWidget {
  const _WaitForLogisticsCard();

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: const Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Wait for Logistics to receive the cargo. Your arrival report does not record receipt or change custody.',
            ),
          ),
        ],
      ),
    ),
  );
}

class _ArrivalNeededCard extends StatelessWidget {
  const _ArrivalNeededCard();

  @override
  Widget build(BuildContext context) => const CourierSurfaceCard(
    child: Text(
      'Report arrival after reaching the destination hub. Logistics confirms cargo receipt separately.',
    ),
  );
}

class _LogisticsReceivingCard extends StatelessWidget {
  const _LogisticsReceivingCard();

  @override
  Widget build(BuildContext context) => const CourierSurfaceCard(
    child: Text('Logistics is receiving the cargo.'),
  );
}

class _LogisticsReceivedCard extends StatelessWidget {
  const _LogisticsReceivedCard();

  @override
  Widget build(BuildContext context) => const CourierSurfaceCard(
    child: Text('Logistics confirmed cargo receipt for this trip.'),
  );
}

class _LinehaulErrorCard extends StatelessWidget {
  const _LinehaulErrorCard({
    required this.message,
    required this.onRetry,
    this.onOpenPolicies,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback? onOpenPolicies;

  @override
  Widget build(BuildContext context) => CourierSurfaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(liveRegion: true, child: Text(message)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
            if (onOpenPolicies != null)
              TextButton.icon(
                onPressed: onOpenPolicies,
                icon: const Icon(Icons.policy_outlined),
                label: const Text('Review policies'),
              ),
          ],
        ),
      ],
    ),
  );
}
