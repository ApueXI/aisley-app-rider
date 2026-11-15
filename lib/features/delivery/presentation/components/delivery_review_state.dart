part of '../delivery_screen.dart';

class _DeliveryPendingReviewCard extends StatelessWidget {
  const _DeliveryPendingReviewCard({
    required this.task,
    required this.controller,
  });

  final PickupTask task;
  final DeliveryController controller;

  @override
  Widget build(BuildContext context) {
    final completion = controller.completions[task.id];
    final evidenceId =
        controller.proofs[task.id]?.proofId ?? completion?.evidenceId;
    final evidenceStatus = controller.evidenceStatusFor(task);
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
