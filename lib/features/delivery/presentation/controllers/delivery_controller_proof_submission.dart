part of 'delivery_controller.dart';

extension DeliveryControllerProofSubmission on DeliveryController {
  Future<bool> submitProof(
    PickupTask task, {
    required DeliveryPhotoSelection photo,
    void Function(void Function() cancel)? onCancel,
  }) async {
    if (!task.isFinalMile ||
        task.status != PickupTaskStatus.outForDelivery ||
        isCompletionPending(task) ||
        !canStartAction(task)) {
      return false;
    }
    final priorProof = proofs[task.id];
    if (priorProof != null && evidenceStatusFor(task) != 'rejected') {
      _setLocalValidationError(
        task,
        'This task already has photo proof. Refresh its validation status before submitting another.',
      );
      return false;
    }
    if (photo.bytes.isEmpty ||
        photo.bytes.length >= maxImageUploadBytes ||
        photo.fileName.trim().isEmpty) {
      _setLocalValidationError(
        task,
        'Choose a non-empty JPEG, PNG, or WebP photo under 10 MiB.',
      );
      return false;
    }
    if (_pendingProofs.containsKey(task.id)) {
      return false;
    }
    _actionStatuses[task.id] = DeliveryActionStatus.loading;
    _actionErrors[task.id] = null;
    _notifyDeliveryListeners();
    PickupTask current;
    try {
      current = await deliveryRepository.fetchFinalMileTask(task.id);
      if (current.id != task.id || !current.isFinalMile) {
        throw const ApiContractException('delivery.task.identity');
      }
      _replaceTask(current);
      if (current.status != PickupTaskStatus.outForDelivery ||
          current.revision == null) {
        _actionStatuses[task.id] = DeliveryActionStatus.conflict;
        _actionErrors[task.id] = 'This delivery task or its revision changed. Refresh before submitting photo proof.';
        _notifyDeliveryListeners();
        return false;
      }
    } on ApiException catch (error) {
      await _setActionError(task, error, submission: false);
      return false;
    } on TokenStorageException {
      _setStorageActionError(task);
      return false;
    } on ApiContractException {
      _setContractActionError(task, submission: false);
      return false;
    }
    final attempt = _PendingPhotoAttempt(
      photo: photo,
      expectedRevision: current.revision!,
      idempotencyKey: DeliveryController._newUuid(),
    );
    _pendingProofs[task.id] = attempt;
    _actionStatuses[task.id] = DeliveryActionStatus.idle;
    return _performProof(current, attempt, onCancel: onCancel);
  }

  Future<bool> retryProof(PickupTask task) async {
    final attempt = _pendingProofs[task.id];
    if (attempt == null) {
      return false;
    }
    return _performProof(task, attempt);
  }

  Future<bool> _performProof(
    PickupTask task,
    _PendingPhotoAttempt attempt, {
    void Function(void Function() cancel)? onCancel,
  }) async {
    if (!task.isFinalMile ||
        task.status != PickupTaskStatus.outForDelivery ||
        isCompletionPending(task) ||
        !canStartAction(task)) {
      return false;
    }
    _actionStatuses[task.id] = DeliveryActionStatus.proofSubmitting;
    _actionErrors[task.id] = null;
    _actionRetryAfter[task.id] = null;
    _notifyDeliveryListeners();
    try {
      final proof = await deliveryRepository.submitProof(
        taskId: task.id,
        photo: attempt.photo,
        expectedRevision: attempt.expectedRevision,
        idempotencyKey: attempt.idempotencyKey,
        onCancel: onCancel,
      );
      if (proof.taskId != task.id) {
        throw const ApiContractException('delivery.proof.task_id');
      }
      final previousProofId = proofs[task.id]?.proofId;
      if (previousProofId != null && previousProofId != proof.proofId) {
        clearProofPhoto(previousProofId);
      }
      proofs[task.id] = proof;
      _pendingProofs.remove(task.id);
      _actionStatuses[task.id] = proof.evidenceStatus == 'rejected'
          ? DeliveryActionStatus.validationError
          : DeliveryActionStatus.proofAwaitingValidation;
      _notifyDeliveryListeners();
      await loadProofPhoto(proof.proofId, force: true);
      return true;
    } on ApiException catch (error) {
      if (DeliveryController._isDefinitiveMutationError(error)) {
        _pendingProofs.remove(task.id);
      }
      await _setActionError(task, error);
    } on TokenStorageException {
      _setStorageActionError(task);
    } on ApiContractException {
      _setContractActionError(task);
    }
    return false;
  }
}
