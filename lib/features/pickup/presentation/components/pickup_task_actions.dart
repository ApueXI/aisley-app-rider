part of '../pickup_screen.dart';

extension _PickupTaskActions on _PickupTaskDetailScreenState {
  Widget _buildRejected(BuildContext context, PickupTask task) {
    final scheme = Theme.of(context).colorScheme;
    final actionStatus = _pickupController.actionStatus(task);
    final error = _pickupController.actionError(task);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.assignment_returned_outlined),
            const SizedBox(height: 10),
            Text(
              'Offer rejected',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              task.rejectionReason == null
                  ? 'Logistics may offer this task again.'
                  : 'Reason: ${task.rejectionReason}',
            ),
            if (task.offerRespondedAt != null) ...[
              const SizedBox(height: 6),
              Text(
                'Recorded ${_formatManilaTimestamp(task.offerRespondedAt!)}',
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error, style: TextStyle(color: scheme.error)),
              if (_canRetryAction(actionStatus) &&
                  _pickupController.hasPendingRejection(task))
                TextButton.icon(
                  onPressed: () => _retryRejection(task),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry same rejection'),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAcceptance(BuildContext context, PickupTask task) {
    if (task.isFinalMile) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dispatch batch offer',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Review each parcel in its dispatch batch, then accept or reject it individually.',
              ),
              if (_onOpenBatches != null) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _onOpenBatches,
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('Review dispatch batches'),
                ),
              ],
            ],
          ),
        ),
      );
    }
    final controller = _pickupController;
    final actionStatus = controller.actionStatus(task);
    final error = controller.actionError(task);
    final busy = controller.isActionBusy(task);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Accept before pickup',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Opening this task does not accept it. Confirm that you are taking responsibility for this assigned ${task.isFirstMile ? 'Seller pickup' : 'hub delivery'} before verifying the parcel.',
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error, style: TextStyle(color: scheme.error)),
              if (actionStatus == PickupTaskActionStatus.consentRequired &&
                  _policyController != null)
                TextButton.icon(
                  onPressed: _openPolicies,
                  icon: const Icon(Icons.policy_outlined),
                  label: const Text('Review policies'),
                ),
              if (_canRetryAction(actionStatus) &&
                  controller.hasPendingRejection(task))
                TextButton.icon(
                  onPressed: busy ? null : () => _retryRejection(task),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry same rejection'),
                ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: busy ? null : () => _confirmAcceptTask(task),
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(
                task.isFirstMile
                    ? 'Accept Seller pickup'
                    : 'Accept hub delivery',
              ),
            ),
            if (task.isFinalMile) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: busy ? null : () => _confirmRejectTask(task),
                icon: const Icon(Icons.close),
                label: const Text('Reject offer'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVerification(BuildContext context, PickupTask task) {
    if (task.isFirstMile) {
      return _buildFirstMileScanReview(context, task);
    }
    return const Text(
      'No pickup verification action is available for this task.',
    );
  }

  Widget _buildFirstMileScanReview(BuildContext context, PickupTask task) {
    final controller = _pickupController;
    final candidate = _scanCandidate;
    final actionError = controller.actionError(task);
    final actionStatus = controller.actionStatus(task);
    final busy = controller.isActionBusy(task);
    final hasPendingAttempt = controller.hasPendingAttempt(task);
    final scheme = Theme.of(context).colorScheme;
    final detectedType = candidate == null
        ? null
        : switch (candidate.type) {
            BarcodeScanType.qr => 'QR code',
            BarcodeScanType.trackingId => 'Code 128',
          };

    return CourierSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Scan verification',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Divider(height: 20),
          if (actionError != null) ...[
            Semantics(liveRegion: true, child: Text(actionError)),
            if (actionStatus == PickupTaskActionStatus.consentRequired &&
                _policyController != null)
              TextButton.icon(
                onPressed: _openPolicies,
                icon: const Icon(Icons.policy_outlined),
                label: const Text('Review policies'),
              ),
            const SizedBox(height: 12),
          ],
          Text(
            'Scanned code',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          if (candidate == null)
            Text(
              'Scan the waybill QR code or tracking barcode to prepare pickup confirmation.',
              style: Theme.of(context).textTheme.bodyLarge,
            )
          else
            Semantics(
              liveRegion: true,
              label:
                  'Unverified scan candidate. $detectedType. ${candidate.value}',
              child: Container(
                constraints: const BoxConstraints(minHeight: 60),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        candidate.value,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.lock_outline, color: scheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          if (detectedType != null) ...[
            const SizedBox(height: 12),
            _ScanTypeLabel(label: 'Automatically detected: $detectedType'),
          ],
          if (BarcodeScannerScreen.isSupported) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed:
                  busy || hasPendingAttempt || !controller.canRetryRateLimit
                  ? null
                  : _openScanner,
              icon: const Icon(Icons.refresh),
              label: Text(
                candidate == null ? 'Scan QR or tracking ID' : 'Scan again',
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            const Text(
              'Camera scanning is unavailable on this platform. Use a supported device or browser to capture a code.',
            ),
          ],
          if (hasPendingAttempt && actionError != null) ...[
            const SizedBox(height: 12),
            Text(
              'Retry will send the same pickup confirmation again.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScanTypeLabel extends StatelessWidget {
  const _ScanTypeLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [Flexible(child: Text(label))],
        ),
      ),
    );
  }
}

class _PickupScanNotice extends StatelessWidget {
  const _PickupScanNotice();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_outlined, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Code capture only reads the value. Confirm pickup asks the server to verify it for this task and records handoff if accepted.',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

bool _canRetryAction(PickupTaskActionStatus status) {
  return status == PickupTaskActionStatus.offline ||
      status == PickupTaskActionStatus.timeout ||
      status == PickupTaskActionStatus.conflict ||
      status == PickupTaskActionStatus.rateLimited ||
      status == PickupTaskActionStatus.failed;
}
