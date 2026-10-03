part of 'delivery_controller.dart';

extension DeliveryControllerMovement on DeliveryController {
  Future<bool> advanceStatus(PickupTask task) async {
    final nextStatus = DeliveryController.nextStatusFor(task.status);
    final revision = task.revision;
    if (!task.isFinalMile ||
        nextStatus == null ||
        revision == null ||
        !canStartAction(task)) {
      return false;
    }
    final pending = _pendingMovements[task.id];
    if (pending != null &&
        (pending.targetStatus != nextStatus ||
            pending.expectedRevision != revision)) {
      _pendingMovements.remove(task.id);
    }
    final attempt =
        _pendingMovements[task.id] ??
        _PendingMovementAttempt(
          targetStatus: nextStatus,
          expectedRevision: revision,
          idempotencyKey: DeliveryController._newUuid(),
        );
    _pendingMovements[task.id] = attempt;
    return _performMovement(task, attempt);
  }

  Future<bool> retryMovement(PickupTask task) async {
    final attempt = _pendingMovements[task.id];
    if (attempt == null || !canStartAction(task)) {
      return false;
    }
    try {
      final tasks = await deliveryRepository.fetchFinalMileTasks();
      PickupTask? fresh;
      for (final candidate in tasks) {
        if (candidate.id == task.id) {
          fresh = candidate;
          break;
        }
      }
      if (fresh == null) {
        _actionStatuses[task.id] = DeliveryActionStatus.failed;
        _actionErrors[task.id] = 'This task is no longer in your active delivery list. Refresh your work.';
        _notifyDeliveryListeners();
        return false;
      }
      _replaceTask(fresh);
      if (fresh.rawStatus == attempt.targetStatus) {
        _pendingMovements.remove(task.id);
        _actionStatuses[task.id] = DeliveryActionStatus.moved;
        _actionErrors[task.id] = null;
        _notifyDeliveryListeners();
        return true;
      }
      if (fresh.rawStatus != task.rawStatus ||
          fresh.revision != attempt.expectedRevision) {
        _pendingMovements.remove(task.id);
        _actionStatuses[task.id] = DeliveryActionStatus.conflict;
        _actionErrors[task.id] = 'This delivery state changed. Review the refreshed task before acting.';
        _notifyDeliveryListeners();
        return false;
      }
      return await _performMovement(fresh, attempt);
    } on ApiException catch (error) {
      await _setActionError(task, error, submission: false);
    } on TokenStorageException {
      _setStorageActionError(task);
    } on ApiContractException {
      _setContractActionError(task, submission: false);
    }
    return false;
  }

  Future<bool> _performMovement(
    PickupTask task,
    _PendingMovementAttempt attempt,
  ) async {
    final taskId = task.id;
    _actionStatuses[taskId] = DeliveryActionStatus.moving;
    _actionErrors[taskId] = null;
    _actionRetryAfter[taskId] = null;
    _notifyDeliveryListeners();
    try {
      final update = await deliveryRepository.advanceStatus(
        taskId: taskId,
        status: attempt.targetStatus,
        expectedRevision: attempt.expectedRevision,
        idempotencyKey: attempt.idempotencyKey,
      );
      if (update.taskId != taskId || update.status != attempt.targetStatus) {
        throw const ApiContractException('delivery.status.task_projection');
      }
      final updated = task.copyWith(
        rawStatus: update.status,
        revision: update.revision,
      );
      _pendingMovements.remove(taskId);
      _replaceTask(updated);
      final context = contexts[taskId];
      if (context != null) {
        contexts[taskId] = context.copyWith(
          status: update.status,
          revision: update.revision,
        );
      }
      _actionStatuses[taskId] = DeliveryActionStatus.moved;
      _notifyDeliveryListeners();
      return true;
    } on ApiException catch (error) {
      if (DeliveryController._isDefinitiveMutationError(error)) {
        _pendingMovements.remove(taskId);
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
