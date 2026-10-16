part of '../delivery_screen.dart';

class _DeliveryListBody extends StatelessWidget {
  const _DeliveryListBody({
    required this.controller,
    required this.onOpenTask,
    required this.onRetry,
    required this.onOpenPolicies,
    required this.showPolicyAction,
  });

  final DeliveryController controller;
  final ValueChanged<PickupTask> onOpenTask;
  final VoidCallback onRetry;
  final VoidCallback onOpenPolicies;
  final bool showPolicyAction;

  @override
  Widget build(BuildContext context) {
    final status = controller.loadStatus;
    final tasks = controller.tasks;
    final isBlocking =
        status != DeliveryLoadStatus.idle &&
        status != DeliveryLoadStatus.loading &&
        status != DeliveryLoadStatus.loaded &&
        status != DeliveryLoadStatus.empty;
    return ListView(
      key: const PageStorageKey('delivery-work'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(
          'Final-mile deliveries',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const SizedBox(height: 16),
        if ((status == DeliveryLoadStatus.idle ||
                status == DeliveryLoadStatus.loading) &&
            tasks.isEmpty)
          const _DeliveryLoadingCard()
        else if (isBlocking && tasks.isEmpty)
          _DeliveryErrorCard(
            message: controller.errorMessage ?? 'Delivery work is unavailable.',
            status: status,
            onRetry: onRetry,
            onOpenPolicies: onOpenPolicies,
            showPolicyAction: showPolicyAction,
          )
        else if (status == DeliveryLoadStatus.empty || tasks.isEmpty)
          const _DeliveryEmptyCard()
        else ...[
          for (final task in tasks) ...[
            _DeliveryTaskCard(task: task, onTap: () => onOpenTask(task)),
            const SizedBox(height: 10),
          ],
          if (controller.errorMessage != null)
            _DeliveryInlineError(
              message: controller.errorMessage!,
              onRetry: onRetry,
            ),
        ],
      ],
    );
  }
}

class _DeliveryTaskCard extends StatelessWidget {
  const _DeliveryTaskCard({required this.task, required this.onTap});
  final PickupTask task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TaskRow(
    reference: task.order?.reference ?? 'Order reference unavailable',
    leg: 'Final mile',
    status: _deliveryStatusLabel(task.rawStatus),
    location:
        'To ${task.destinationArea?.areaSummary ?? 'Destination area unavailable'}',
    nextStep: switch (task.status) {
      PickupTaskStatus.deliveryAssigned => 'Review the final-mile batch',
      PickupTaskStatus.deliveryAccepted => 'Complete hub handoff first',
      PickupTaskStatus.pickedUpFromHub => 'Start transit',
      PickupTaskStatus.inTransit => 'Continue to out for delivery',
      PickupTaskStatus.outForDelivery => 'Photo proof and delivery intent',
      PickupTaskStatus.delivered => 'Delivery completed',
      _ => 'Open to review current work',
    },
    onTap: onTap,
  );
}
