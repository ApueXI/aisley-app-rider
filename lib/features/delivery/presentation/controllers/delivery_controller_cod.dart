part of 'delivery_controller.dart';

extension DeliveryControllerCod on DeliveryController {
  Future<DeliveryCodCollection?> prepareCodCompletion(PickupTask task) async {
    final proof = proofs[task.id]?.proofId ?? completions[task.id]?.evidenceId;
    if (proof == null || evidenceStatusFor(task) == 'rejected') return null;
    final payment = await prepareDeliveryPayment(task);
    if (payment == null) return null;
    if (!payment.isCod) {
      _setLocalValidationError(
        task,
        'Cash collection information is unavailable for this delivery.',
      );
      return null;
    }
    if (!hasFreshProof(task)) await loadCompletion(task);
    if (!hasFreshProof(task)) {
      _setLocalValidationError(
        task,
        'Take a new photo after a failed visit, or refresh to confirm photo freshness.',
      );
      return null;
    }
    return payment;
  }

  Future<DeliveryCodCollection?> prepareDeliveryPayment(PickupTask task) async {
    if (hasPendingCompletion(task)) {
      await loadCompletion(task);
      if (isCompletionPending(task) ||
          completions[task.id]?.isDelivered == true) {
        _pendingCompletions.remove(task.id);
        return null;
      }
    }
    if (!task.isFinalMile ||
        !task.canSubmitDelivery ||
        isCompletionPending(task) ||
        !canStartAction(task)) {
      return null;
    }
    final collection = await _readCodCollection(task);
    if (collection == null) return null;
    return collection;
  }

  Future<DeliveryCodCollection?> _readCodCollection(PickupTask task) async {
    final epoch = _loadEpoch;
    _actionStatuses[task.id] = DeliveryActionStatus.completionLoading;
    _actionErrors[task.id] = null;
    _actionRetryAfter[task.id] = null;
    _notifyDeliveryListeners();

    try {
      final context = await deliveryRepository.fetchDeliveryContext(task.id);
      if (epoch != _loadEpoch) return null;
      if (context.taskId != task.id) {
        throw const ApiContractException('delivery.context.task_id');
      }
      if (!isDeliverySubmissionStatus(context.status) ||
          context.revision == null) {
        _actionStatuses[task.id] = DeliveryActionStatus.conflict;
        _actionErrors[task.id] = 'This delivery task changed. Refresh it before confirming cash collection.';
        _notifyDeliveryListeners();
        return null;
      }

      contexts[task.id] = context;
      contextStatuses[task.id] = DeliveryLoadStatus.loaded;
      contextErrors[task.id] = null;
      _replaceTask(
        (taskById(task.id) ?? task).copyWith(revision: context.revision),
      );

      if (context.paymentMethod != 'cod' &&
          !(context.paymentMethod == 'prepaid' &&
              context.paymentStatus == 'paid')) {
        _setLocalValidationError(
          task,
          'Cash collection information is unavailable for this delivery. Refresh the task before continuing.',
        );
        return null;
      }
      final collection = context.paymentMethod == 'prepaid'
          ? const DeliveryCodCollection(amount: '', currency: '', isCod: false)
          : context.codCollection;
      if (collection == null) {
        _setLocalValidationError(
          task,
          'The cash amount to collect could not be confirmed. Refresh delivery details before confirming cash collection.',
        );
        return null;
      }
      _actionStatuses[task.id] = DeliveryActionStatus.idle;
      _notifyDeliveryListeners();
      return collection;
    } on ApiException catch (error) {
      if (epoch == _loadEpoch) {
        await _setActionError(task, error, submission: false);
      }
    } on TokenStorageException {
      if (epoch == _loadEpoch) _setStorageActionError(task);
    } on ApiContractException {
      if (epoch == _loadEpoch) _setContractActionError(task, submission: false);
    }
    return null;
  }
}
