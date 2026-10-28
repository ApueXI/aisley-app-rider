part of '../delivery_screen.dart';

class _DeliveryPendingReviewCard extends StatelessWidget {
  const _DeliveryPendingReviewCard({
    required this.task,
    required this.controller,
    required this.contextData,
    required this.canRefresh,
    required this.onRefresh,
    required this.onBackToWork,
  });

  final PickupTask task;
  final DeliveryController controller;
  final DeliveryContext? contextData;
  final bool canRefresh;
  final VoidCallback onRefresh;
  final VoidCallback onBackToWork;

  @override
  Widget build(BuildContext context) {
    final completion = controller.completions[task.id];
    final evidenceId =
        controller.proofs[task.id]?.proofId ?? completion?.evidenceId;
    final evidenceStatus = controller.evidenceStatusFor(task);
    final cod = contextData?.paymentMethod == 'cod';
    final codCollection = contextData?.codCollection;

    return CourierSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CourierSectionHeader(
            title: 'Awaiting Logistics validation',
            subtitle: task.order?.reference ?? 'Order reference unavailable',
            trailing: const CourierStatusBadge(
              label: 'In review',
              tone: CourierStatusTone.info,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'The photo proof and Delivered intent were submitted. The order is not marked delivered until Logistics validates the completion intent.',
          ),
          const SizedBox(height: 12),
          _ReviewStatusRow(
            label: 'Photo proof',
            value: _reviewEvidenceLabel(evidenceStatus),
          ),
          _ReviewStatusRow(
            label: 'Delivered intent',
            value: 'Awaiting Logistics validation',
          ),
          if (cod) ...[
            const Divider(height: 28),
            const CourierSectionHeader(title: 'Cash declaration'),
            const SizedBox(height: 4),
            if (codCollection == null)
              const Text(
                'The current cash amount is unavailable. Refresh delivery details to review it.',
              )
            else ...[
              Text(
                'Cash due ${codCollection.displayAmount}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              const Text(
                'The cash collection declaration was sent with the Delivered intent and is awaiting Logistics validation.',
              ),
            ],
          ],
          if (evidenceId != null) ...[
            const SizedBox(height: 16),
            DeliveryProofPhotoPreview(
              title: 'Submitted photo proof',
              status:
                  controller.proofPhotoStatuses[evidenceId] ??
                  ProofPhotoLoadStatus.idle,
              photo: controller.proofPhotos[evidenceId],
              errorMessage: controller.proofPhotoErrors[evidenceId],
              onRetry: () => controller.loadProofPhoto(evidenceId, force: true),
              semanticLabel: 'Submitted proof of delivery photo',
            ),
          ],
          if (controller.completionErrors[task.id] case final error?) ...[
            const SizedBox(height: 12),
            Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: canRefresh ? onRefresh : null,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh completion status'),
          ),
          TextButton.icon(
            onPressed: onBackToWork,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to delivery work'),
          ),
        ],
      ),
    );
  }
}

class _ReviewStatusRow extends StatelessWidget {
  const _ReviewStatusRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        Text(value),
      ],
    ),
  );
}

String _reviewEvidenceLabel(String? status) => switch (status) {
  'awaiting_validation' => 'Awaiting Logistics validation',
  'validated' => 'Validated',
  'rejected' => 'Rejected',
  null => 'Status unavailable',
  _ => 'Status unavailable',
};
