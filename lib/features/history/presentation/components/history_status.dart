part of '../history_screen.dart';

class _HistoryStatusPill extends StatelessWidget {
  const _HistoryStatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return CourierStatusBadge(
      label: label,
      tone: label == 'Delivered'
          ? CourierStatusTone.success
          : CourierStatusTone.neutral,
    );
  }
}

class _HistoryLoadingCard extends StatelessWidget {
  const _HistoryLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Loading delivery history',
      child: const CourierSurfaceCard(
        child: Padding(
          padding: EdgeInsets.all(8),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

class _HistoryEmptyCard extends StatelessWidget {
  const _HistoryEmptyCard({required this.filtered});

  final bool filtered;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: CourierSurfaceCard(
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Text(
            filtered
                ? 'No completed deliveries match this order reference.'
                : 'No completed final-mile deliveries are available.',
          ),
        ),
      ),
    );
  }
}

class _HistoryErrorCard extends StatelessWidget {
  const _HistoryErrorCard({
    required this.message,
    required this.status,
    required this.onRetry,
    required this.onOpenPolicies,
    required this.showPolicyAction,
    this.canRetry = true,
  });

  final String message;
  final HistoryLoadStatus status;
  final VoidCallback onRetry;
  final VoidCallback onOpenPolicies;
  final bool showPolicyAction;
  final bool canRetry;

  @override
  Widget build(BuildContext context) {
    return CourierSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              if (_historyCanRetry(status))
                OutlinedButton.icon(
                  onPressed: canRetry ? onRetry : null,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              if (status == HistoryLoadStatus.consentRequired &&
                  showPolicyAction)
                FilledButton.icon(
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
}

class _HistoryInlineError extends StatelessWidget {
  const _HistoryInlineError({
    required this.message,
    required this.onRetry,
    required this.canRetry,
  });

  final String message;
  final VoidCallback onRetry;
  final bool canRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message),
        TextButton(
          onPressed: canRetry ? onRetry : null,
          child: const Text('Retry'),
        ),
      ],
    );
  }
}

bool _historyCanRetry(HistoryLoadStatus status) {
  return status == HistoryLoadStatus.offline ||
      status == HistoryLoadStatus.timeout ||
      status == HistoryLoadStatus.failed ||
      status == HistoryLoadStatus.rateLimited;
}

String _historyStatusLabel(String status) {
  return switch (status) {
    'delivered' => 'Delivered',
    _ => 'Status unavailable',
  };
}

String _areaRouteLabel(DeliveryHistoryItem item) {
  final pickup = item.pickupArea?.areaSummary;
  final destination = item.destinationArea?.areaSummary;
  if (pickup == null || pickup == 'Location unavailable') {
    return destination == null || destination == 'Location unavailable'
        ? 'Pickup and destination areas unavailable'
        : 'To $destination';
  }
  if (destination == null || destination == 'Location unavailable') {
    return 'From $pickup';
  }
  return 'From $pickup · To $destination';
}

String _formatHistoryTimestamp(DateTime timestamp) {
  final value = timestamp.toLocal();
  final hour = value.hour == 0
      ? 12
      : value.hour > 12
      ? value.hour - 12
      : value.hour;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour >= 12 ? 'PM' : 'AM';
  return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} $hour:$minute $period';
}
