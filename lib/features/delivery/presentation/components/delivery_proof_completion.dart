part of '../delivery_screen.dart';

class _ProofAndCompletionCard extends StatelessWidget {
  const _ProofAndCompletionCard({
    required this.task,
    required this.controller,
    required this.selectedPhoto,
    required this.selectionError,
    required this.isPicking,
    required this.canCancelUpload,
    required this.onChoosePhoto,
    required this.cameraSupported,
    required this.onCapturePhoto,
    required this.onDiscardPhoto,
    required this.onCancelUpload,
    required this.onOpenPolicies,
    required this.showPolicyAction,
  });

  final PickupTask task;
  final DeliveryController controller;
  final DeliveryPhotoSelection? selectedPhoto;
  final String? selectionError;
  final bool isPicking;
  final bool canCancelUpload;
  final VoidCallback onChoosePhoto;
  final bool cameraSupported;
  final VoidCallback onCapturePhoto;
  final VoidCallback onDiscardPhoto;
  final VoidCallback onCancelUpload;
  final VoidCallback onOpenPolicies;
  final bool showPolicyAction;

  @override
  Widget build(BuildContext context) {
    final actionStatus = controller.actionStatus(task);
    final actionError = controller.actionError(task);
    final completion = controller.completions[task.id];
    final proof = controller.proofs[task.id];
    final evidenceStatus = controller.evidenceStatusFor(task);
    final failedNewProof = actionError != null && proof == null;
    final evidenceId = failedNewProof
        ? null
        : proof?.proofId ?? completion?.evidenceId;
    final proofRejected = evidenceStatus == 'rejected';
    final proofStale = evidenceId != null && !controller.hasFreshProof(task);
    final completionPending =
        !failedNewProof && controller.isCompletionPending(task);
    final busy = controller.isActionBusy(task);
    final actionBlocked = !controller.canStartAction(task);
    final canChoosePhoto =
        !busy &&
        !actionBlocked &&
        !isPicking &&
        !controller.hasPendingProof(task) &&
        !completionPending &&
        (evidenceId == null || proofRejected || proofStale);

    return CourierSurfaceCard(
      // Keep each paragraph and action independently readable when scrolled.
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CourierSectionHeader(title: 'Proof of delivery'),
          const SizedBox(height: 8),
          const Text(
            'Capture package placement clearly at the customer doorstep or designated handoff spot.',
          ),
          const SizedBox(height: 6),
          Text(
            'Choose a JPEG, PNG, or WebP photo under 10 MiB. The server checks it for this delivery task.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (proofRejected) ...[
            const SizedBox(height: 12),
            Text(
              'Logistics rejected the previous photo. Choose a new photo and submit a new proof.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (proofStale && !completionPending) ...[
            const SizedBox(height: 12),
            const Text(
              'A fresh photo is required after a failed visit. Refresh to confirm photo freshness or submit a new photo.',
            ),
          ],
          if (canChoosePhoto && selectedPhoto == null) ...[
            const SizedBox(height: 12),
            if (cameraSupported)
              FilledButton.icon(
                onPressed: onCapturePhoto,
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Open camera for POD'),
              ),
            if (cameraSupported) const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onChoosePhoto,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(
                cameraSupported ? 'Choose photo file' : 'Choose photo',
              ),
            ),
          ],
          if (isPicking)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(),
            ),
          if (selectionError != null) ...[
            const SizedBox(height: 8),
            Text(
              selectionError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (selectedPhoto != null && canChoosePhoto) ...[
            const SizedBox(height: 12),
            Semantics(
              label: 'Selected proof photo preview',
              child: Image.memory(
                selectedPhoto!.bytes,
                height: 180,
                width: double.infinity,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) =>
                    const Text('Photo preview unavailable.'),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (cameraSupported)
                  OutlinedButton.icon(
                    onPressed: onCapturePhoto,
                    icon: const Icon(Icons.cameraswitch_outlined),
                    label: const Text('Retake photo'),
                  ),
                OutlinedButton.icon(
                  onPressed: onChoosePhoto,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Replace from files'),
                ),
                Semantics(
                  button: true,
                  label: 'Remove photo',
                  onTap: onDiscardPhoto,
                  child: SizedBox(
                    height: 48,
                    child: ExcludeSemantics(
                      child: TextButton.icon(
                        onPressed: onDiscardPhoto,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Remove photo'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (actionStatus == DeliveryActionStatus.proofSubmitting) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
            if (canCancelUpload)
              TextButton(
                onPressed: onCancelUpload,
                child: const Text('Cancel upload'),
              ),
          ],
          if (actionError != null) ...[
            const SizedBox(height: 12),
            Text(
              actionError,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            if (actionStatus == DeliveryActionStatus.consentRequired &&
                showPolicyAction)
              TextButton.icon(
                onPressed: onOpenPolicies,
                icon: const Icon(Icons.policy_outlined),
                label: const Text('Review policies'),
              ),
            if (_canRetry(actionStatus) ||
                actionStatus == DeliveryActionStatus.validationError)
              TextButton.icon(
                onPressed: busy || !controller.canRetryRateLimit
                    ? null
                    : () => controller.loadDetails(task),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh task'),
              ),
          ],
          if (evidenceId != null && !proofRejected) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(
                evidenceStatus == 'validated'
                    ? 'Photo proof validated by Logistics. Delivery is not complete until Logistics validates the completion intent.'
                    : 'Photo proof received. Awaiting Logistics validation; this does not mark the Order delivered.',
              ),
            ),
          ],
          if (evidenceId != null) ...[
            const SizedBox(height: 16),
            DeliveryProofPhotoPreview(
              title: proofRejected
                  ? 'Rejected submitted photo'
                  : 'Submitted photo',
              status:
                  controller.proofPhotoStatuses[evidenceId] ??
                  ProofPhotoLoadStatus.idle,
              photo: controller.proofPhotos[evidenceId],
              errorMessage: controller.proofPhotoErrors[evidenceId],
              onRetry: () => controller.loadProofPhoto(evidenceId, force: true),
              semanticLabel: proofRejected
                  ? 'Rejected proof of delivery photo'
                  : 'Submitted proof of delivery photo',
            ),
          ],
          if (controller.completionErrors[task.id] != null) ...[
            Text(
              controller.completionErrors[task.id]!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 8),
          ],
          if (completion?.isDelivered == true)
            const _DeliveredStatusText()
          else if (proofRejected)
            const Text('Submit a new photo proof after Logistics rejection.')
          else if (proofStale)
            const Text(
              'Refresh or submit a fresh photo before sending Delivered for review.',
            )
          else if (evidenceId != null ||
              selectedPhoto != null ||
              completionPending)
            const Text(
              'Submitting Delivered sends the photo proof and completion intent for Logistics validation.',
            ),
        ],
      ),
    );
  }
}
