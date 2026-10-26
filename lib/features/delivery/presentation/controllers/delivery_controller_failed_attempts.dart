part of 'delivery_controller.dart';

extension DeliveryControllerFailedAttempts on DeliveryController {
  PendingFailedDeliveryAttempt? pendingFailedAttempt(PickupTask task) =>
      _pendingFailedAttempts[task.id];
  bool hasPendingFailedAttempt(PickupTask task) =>
      _pendingFailedAttempts.containsKey(task.id);
  bool isReportingFailedAttempt(PickupTask task) =>
      _failedAttemptBusy.contains(task.id);

  bool canReportFailedAttempt(PickupTask task) =>
      !_disposed &&
      task.isFinalMile &&
      task.canSubmitDelivery &&
      isDeliverySubmissionStatus(contexts[task.id]?.status ?? '') &&
      contextStatuses[task.id] == DeliveryLoadStatus.loaded &&
      completionStatuses[task.id] == DeliveryLoadStatus.loaded &&
      !isCompletionPending(task) &&
      !isActionBusy(task) &&
      !hasPendingProof(task) &&
      !hasPendingMovement(task) &&
      !hasPendingCompletion(task) &&
      !hasPendingFailedAttempt(task) &&
      !_failedAttemptBlocked.contains(task.id) &&
      canStartAction(task);

  bool canRetryFailedAttempt(PickupTask task) =>
      !_disposed &&
      hasPendingFailedAttempt(task) &&
      !_failedAttemptBusy.contains(task.id) &&
      canRetryRateLimit &&
      !_failedAttemptBlocked.contains(task.id);

  bool hasFreshProof(PickupTask task, {CompletionProjection? projection}) {
    final current = projection ?? completions[task.id];
    final proofId = proofs[task.id]?.proofId ?? current?.evidenceId;
    final count = contexts[task.id]?.failedAttemptCount;
    return !_invalidatedProofTasks.contains(task.id) &&
        !hasPendingFailedAttempt(task) &&
        contextStatuses[task.id] == DeliveryLoadStatus.loaded &&
        completionStatuses[task.id] == DeliveryLoadStatus.loaded &&
        proofId != null &&
        current?.evidenceId == proofId &&
        count != null &&
        count == current?.proofFailedAttemptCount;
  }

  Future<bool> reportFailedAttempt(
    PickupTask task, {
    required FailedDeliveryReason reason,
    String? note,
  }) async {
    if (!canReportFailedAttempt(task)) return false;
    final normalizedNote = note?.trim();
    if ((reason == FailedDeliveryReason.other &&
            (normalizedNote == null || normalizedNote.isEmpty)) ||
        (normalizedNote?.runes.length ?? 0) > 500) {
      failedAttemptFieldErrors[task.id] = {
        'note': [
          reason == FailedDeliveryReason.other &&
                  (normalizedNote == null || normalizedNote.isEmpty)
              ? 'Describe what prevented this delivery.'
              : 'Use at most 500 characters.',
        ],
      };
      _notifyDeliveryListeners();
      return false;
    }
    final epoch = _loadEpoch;
    _failedAttemptBusy.add(task.id);
    failedAttemptErrors.remove(task.id);
    failedAttemptFieldErrors.remove(task.id);
    _notifyDeliveryListeners();
    try {
      // A newly created attempt uses fresh authority, never an old screen row.
      final context = await deliveryRepository.fetchDeliveryContext(task.id);
      if (!_failedAttemptCurrent(epoch)) return false;
      final completion = await deliveryRepository.fetchCompletion(task.id);
      if (!_failedAttemptCurrent(epoch)) return false;
      if (context.taskId != task.id || completion.taskId != task.id) {
        throw const ApiContractException('delivery.failed_attempt.task');
      }
      contexts[task.id] = context;
      completions[task.id] = completion;
      if (!isDeliverySubmissionStatus(context.status) ||
          !isDeliverySubmissionStatus(completion.taskStatus) ||
          context.revision == null ||
          context.revision! < 1 ||
          completion.revision != context.revision ||
          completion.isAwaitingValidation) {
        failedAttemptErrors[task.id] = 'This delivery changed or is under review. Refresh the task before reporting a visit.';
        _failedAttemptBlocked.add(task.id);
        return false;
      }
      _pendingFailedAttempts[task.id] = PendingFailedDeliveryAttempt(
        reason: reason,
        note: normalizedNote?.isEmpty == true ? null : normalizedNote,
        expectedRevision: context.revision!,
        idempotencyKey: DeliveryController._newUuid(),
      );
    } on ApiException catch (error) {
      if (_failedAttemptCurrent(epoch)) await _failedAttemptError(task, error);
      return false;
    } on TokenStorageException {
      if (_failedAttemptCurrent(epoch)) {
        failedAttemptErrors[task.id] = 'Your saved sign-in could not be accessed. Reopen the app and refresh this delivery.';
      }
      return false;
    } on ApiContractException {
      if (_failedAttemptCurrent(epoch)) {
        failedAttemptErrors[task.id] = 'Delivery details could not be confirmed. Refresh the task before reporting a visit.';
      }
      return false;
    } finally {
      if (_failedAttemptCurrent(epoch)) {
        _failedAttemptBusy.remove(task.id);
        _notifyDeliveryListeners();
      }
    }
    return retryFailedAttempt(task);
  }

  Future<bool> retryFailedAttempt(PickupTask task) async {
    if (!canRetryFailedAttempt(task)) return false;
    final attempt = _pendingFailedAttempts[task.id]!;
    final epoch = _loadEpoch;
    _failedAttemptBusy.add(task.id);
    failedAttemptErrors.remove(task.id);
    failedAttemptFieldErrors.remove(task.id);
    _notifyDeliveryListeners();
    try {
      final receipt = await deliveryRepository.reportFailedAttempt(
        taskId: task.id,
        reason: attempt.reason,
        note: attempt.note,
        expectedRevision: attempt.expectedRevision,
        idempotencyKey: attempt.idempotencyKey,
      );
      if (!_failedAttemptCurrent(epoch)) return false;
      if (receipt.taskId != task.id ||
          receipt.attempt.reason != attempt.reason.value ||
          receipt.attempt.note != attempt.note ||
          !receipt.retryAllowed) {
        throw const ApiContractException('delivery.failed_attempt.identity');
      }
      failedAttemptReceipts[task.id] = receipt;
      _pendingFailedAttempts.remove(task.id);
      _invalidatedProofTasks.add(task.id);
      clearProofPhotosForTask(task.id, notify: false);
      proofs.remove(task.id);
      _failedAttemptBusy.remove(task.id);
      // A read failure cannot turn the confirmed write into another attempt.
      await loadDetails(task);
      return _failedAttemptCurrent(epoch);
    } on ApiException catch (error) {
      if (!_failedAttemptCurrent(epoch)) return false;
      if (error.statusCode == 422 ||
          error.statusCode == 404 ||
          (error.statusCode == 409 && error.code != 'IDEMPOTENCY_KEY_REUSED')) {
        _pendingFailedAttempts.remove(task.id);
      }
      await _failedAttemptError(task, error);
    } on TokenStorageException {
      if (_failedAttemptCurrent(epoch)) {
        failedAttemptErrors[task.id] = 'Your saved sign-in could not be accessed. Reopen the app before retrying this report.';
      }
    } on ApiContractException {
      if (_failedAttemptCurrent(epoch)) {
        failedAttemptErrors[task.id] = 'The report is not confirmed. Retry the same report when connected.';
      }
    } finally {
      if (_failedAttemptCurrent(epoch)) {
        _failedAttemptBusy.remove(task.id);
        _notifyDeliveryListeners();
      }
    }
    return false;
  }

  bool _failedAttemptCurrent(int epoch) => !_disposed && epoch == _loadEpoch;

  Future<void> _failedAttemptError(PickupTask task, ApiException error) async {
    if (error.code == 'IDEMPOTENCY_KEY_REUSED') {
      _failedAttemptKeyConflicts.add(task.id);
    }
    if (error.statusCode == 429) _startRetryDelay(error.retryAfter);
    if (error.statusCode == 401 ||
        error.statusCode == 403 ||
        error.statusCode == 404 ||
        error.statusCode == 409) {
      _failedAttemptBlocked.add(task.id);
    }
    failedAttemptFieldErrors[task.id] = {
      if (error.fieldErrors.containsKey('reason'))
        'reason': ['Choose a supported reason.'],
      if (error.fieldErrors.containsKey('note'))
        'note': [
          'Check the note; Other needs a description of at most 500 characters.',
        ],
    };
    failedAttemptErrors[task.id] = switch (error.statusCode) {
      409 when error.code == 'IDEMPOTENCY_KEY_REUSED' => 'This report conflicts with an earlier request. Contact Logistics; do not submit another report for this visit.',
      409 when error.code == 'COMPLETION_PENDING' =>
        'Logistics is already reviewing this delivery. Refresh its status.',
      409 =>
        'This delivery changed. Refresh the task before reporting a visit.',
      422 => 'Check the reason and note before submitting again.',
      429 => 'Too many requests. Wait before retrying the same report.',
      401 => 'Your session expired. Sign in again.',
      403 when error.code == 'POLICY_CONSENT_REQUIRED' =>
        'Accept the current policies, then refresh this delivery.',
      403 => 'This delivery is no longer available to your account.',
      404 => 'This delivery is no longer available. Refresh your work.',
      _ => 'The report is not confirmed. Check your connection and retry the same report.',
    };
    if (error.statusCode == 401 ||
        error.statusCode == 403 ||
        error.statusCode == 404) {
      if (error.code != 'POLICY_CONSENT_REQUIRED') {
        _clearFailedAttemptPrivateState(task.id);
        clearProofPhotosForTask(task.id, notify: false);
        contexts.remove(task.id);
        completions.remove(task.id);
        proofs.remove(task.id);
      }
      if (error.statusCode != 404) await _notifyAuthFailure(error);
    }
    _notifyDeliveryListeners();
  }
}

extension DeliveryControllerFailedAttemptCleanup on DeliveryController {
  void _clearFailedAttemptPrivateState(String taskId) {
    _pendingFailedAttempts.remove(taskId);
    failedAttemptReceipts.remove(taskId);
    failedAttemptFieldErrors.remove(taskId);
    _failedAttemptBlocked.add(taskId);
  }
}
