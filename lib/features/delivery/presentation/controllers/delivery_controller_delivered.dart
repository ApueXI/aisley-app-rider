part of 'delivery_controller.dart';

extension DeliveryControllerDelivered on DeliveryController {
  /// One deliberate action; each successful stage survives a partial failure.
  Future<bool> submitDelivered(
    PickupTask task, {
    DeliveryPhotoSelection? photo,
    required DeliveryCodCollection confirmedCollection,
    void Function(void Function() cancel)? onCancel,
  }) async {
    if (isActionBusy(task) ||
        !canStartAction(task) ||
        !task.canSubmitDelivery) {
      return false;
    }
    final epoch = _loadEpoch;
    _deliveredBusy.add(task.id);
    _notifyDeliveryListeners();
    try {
      if (hasPendingCompletion(task)) {
        await loadCompletion(task);
        if (_disposed || epoch != _loadEpoch) return false;
        if (isCompletionPending(task) ||
            completions[task.id]?.isDelivered == true) {
          _pendingCompletions.remove(task.id);
          return true;
        }
      }
      // Confirm payment authority before uploading any new evidence.
      final payment = await _readCodCollection(task);
      if (_disposed || epoch != _loadEpoch || payment == null) return false;
      if (!payment.matches(confirmedCollection)) {
        _setLocalValidationError(
          task,
          'Payment details changed. Review and confirm again.',
        );
        return false;
      }
      if (hasPendingCompletion(task)) return await retryCompletion(task);
      if (hasPendingProof(task)) {
        if (!await retryProof(task)) return false;
      } else if (photo != null) {
        if (!await submitProof(task, photo: photo, onCancel: onCancel)) {
          return false;
        }
      }
      if (_disposed || epoch != _loadEpoch) return false;
      final current = taskById(task.id) ?? task;
      if (isCompletionPending(current) ||
          completions[task.id]?.isDelivered == true) {
        return true;
      }
      final evidenceId =
          proofs[task.id]?.proofId ?? completions[task.id]?.evidenceId;
      if (evidenceId == null) {
        _setLocalValidationError(
          task,
          'Take or choose a delivery photo first.',
        );
        return false;
      }
      return await submitCompletion(
        current,
        evidenceId: evidenceId,
        confirmedCollection: confirmedCollection,
      );
    } finally {
      if (!_disposed && epoch == _loadEpoch) {
        _deliveredBusy.remove(task.id);
        _notifyDeliveryListeners();
      }
    }
  }
}
