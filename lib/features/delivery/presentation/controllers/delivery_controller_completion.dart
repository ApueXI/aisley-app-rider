part of 'delivery_controller.dart';

extension DeliveryControllerCompletion on DeliveryController {
  Future<bool> submitCompletion(
    PickupTask task, {
    required String evidenceId,
    required DeliveryCodCollection confirmedCollection,
  }) async {
    final normalizedEvidenceId = evidenceId.trim();
    if (!task.isFinalMile ||
        task.status != PickupTaskStatus.outForDelivery ||
        normalizedEvidenceId.isEmpty ||
        isCompletionPending(task) ||
        completions[task.id]?.isDelivered == true ||
        !canStartAction(task)) {
      return false;
    }
    final knownProofId =
        proofs[task.id]?.proofId ?? completions[task.id]?.evidenceId;
    if (knownProofId == null || knownProofId != normalizedEvidenceId) {
      _setLocalValidationError(
        task,
        'Upload a delivery photo for this task before sending it to Logistics for review.',
      );
      return false;
    }
    if (completions[task.id]?.evidenceId == normalizedEvidenceId &&
        completions[task.id]?.evidenceStatus == 'rejected') {
      _setLocalValidationError(
        task,
        'Logistics rejected this photo. Select and submit a new photo POD.',
      );
      return false;
    }
    final existing = _pendingCompletions[task.id];
    if (existing != null && existing.evidenceId == normalizedEvidenceId) {
      return _performCompletion(task, existing);
    }
    final currentCollection = await _readCodCollection(task);
    if (currentCollection == null) return false;
    if (!currentCollection.matches(confirmedCollection)) {
      _setLocalValidationError(
        task,
        'The COD amount changed. Review the current payable total and confirm collection again.',
      );
      return false;
    }
    _actionStatuses[task.id] = DeliveryActionStatus.completionLoading;
    _actionErrors[task.id] = null;
    _notifyDeliveryListeners();
    CompletionProjection current;
    try {
      current = await deliveryRepository.fetchCompletion(task.id);
      if (current.taskId != task.id) {
        throw const ApiContractException('delivery.completion.task_id');
      }
      completions[task.id] = current;
      if (current.evidenceId == normalizedEvidenceId &&
          (current.evidenceStatus == 'rejected' ||
              current.completionStatus == 'rejected')) {
        _actionStatuses[task.id] = DeliveryActionStatus.validationError;
        _actionErrors[task.id] = 'Logistics rejected this photo or intent. Submit a new photo proof.';
        _notifyDeliveryListeners();
        return false;
      }
      if (current.isDelivered ||
          (current.isAwaitingValidation &&
              _completionMatchesCurrentProof(task.id, current))) {
        _syncTaskFromCompletion(task, current);
        _reconcileActionWithCompletion(task.id, current);
        _notifyDeliveryListeners();
        return false;
      }
      if (current.revision == null ||
          current.taskStatus != 'out_for_delivery') {
        _actionStatuses[task.id] = DeliveryActionStatus.conflict;
        _actionErrors[task.id] = 'This delivery changed. Refresh the task before sending it to Logistics for review.';
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
    final attempt = _PendingCompletionAttempt(
      evidenceId: normalizedEvidenceId,
      expectedRevision: current.revision!,
      idempotencyKey: DeliveryController._newUuid(),
      codCollected: true,
    );
    _pendingCompletions[task.id] = attempt;
    _actionStatuses[task.id] = DeliveryActionStatus.idle;
    return _performCompletion(task, attempt);
  }

  Future<bool> retryCompletion(PickupTask task) async {
    final attempt = _pendingCompletions[task.id];
    if (attempt == null) {
      return false;
    }
    return _performCompletion(task, attempt);
  }

  Future<bool> _performCompletion(
    PickupTask task,
    _PendingCompletionAttempt attempt,
  ) async {
    if (!task.isFinalMile ||
        task.status != PickupTaskStatus.outForDelivery ||
        isCompletionPending(task) ||
        completions[task.id]?.isDelivered == true ||
        !canStartAction(task)) {
      return false;
    }
    _actionStatuses[task.id] = DeliveryActionStatus.completionSubmitting;
    _actionErrors[task.id] = null;
    _actionRetryAfter[task.id] = null;
    _notifyDeliveryListeners();
    try {
      final completion = await deliveryRepository.submitCompletion(
        taskId: task.id,
        expectedRevision: attempt.expectedRevision,
        evidenceId: attempt.evidenceId,
        idempotencyKey: attempt.idempotencyKey,
        codCollected: attempt.codCollected,
      );
      if (completion.taskId != task.id ||
          completion.evidenceId != attempt.evidenceId ||
          !completion.isAwaitingValidation) {
        throw const ApiContractException('delivery.completion.intent');
      }
      completions[task.id] = completion;
      _pendingCompletions.remove(task.id);
      _syncTaskFromCompletion(task, completion, allowDelivered: false);
      _actionStatuses[task.id] =
          DeliveryActionStatus.completionAwaitingValidation;
      _notifyDeliveryListeners();
      return true;
    } on ApiException catch (error) {
      if (DeliveryController._isDefinitiveMutationError(error)) {
        _pendingCompletions.remove(task.id);
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
