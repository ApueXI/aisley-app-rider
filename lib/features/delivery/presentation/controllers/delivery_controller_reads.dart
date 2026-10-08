part of 'delivery_controller.dart';

extension DeliveryControllerReads on DeliveryController {
  Future<void> load() async {
    if (_loadInFlight || !canRetryRateLimit) {
      return;
    }
    final epoch = ++_loadEpoch;
    _loadInFlight = true;
    _authFailureNotified = false;
    retryAfter = null;
    loadStatus = DeliveryLoadStatus.loading;
    errorMessage = null;
    _notifyDeliveryListeners();

    try {
      final loadedTasks = await deliveryRepository.fetchFinalMileTasks();
      if (epoch != _loadEpoch) {
        return;
      }
      final loadedTaskIds = loadedTasks.map((task) => task.id).toSet();
      final removedTaskIds = tasks
          .map((task) => task.id)
          .where((taskId) => !loadedTaskIds.contains(taskId))
          .toList(growable: false);
      for (final taskId in removedTaskIds) {
        clearProofPhotosForTask(taskId, notify: false);
      }
      tasks = List<PickupTask>.unmodifiable(loadedTasks);
      for (final task in loadedTasks) {
        if (_actionStatuses[task.id] == DeliveryActionStatus.conflict) {
          _actionStatuses.remove(task.id);
          _actionErrors.remove(task.id);
          _actionRetryAfter.remove(task.id);
        }
      }
      loadStatus = loadedTasks.isEmpty
          ? DeliveryLoadStatus.empty
          : DeliveryLoadStatus.loaded;
      errorMessage = null;
      _notifyDeliveryListeners();
    } on ApiException catch (error) {
      await _setLoadError(error, epoch);
    } on TokenStorageException {
      if (epoch != _loadEpoch) {
        return;
      }
      loadStatus = DeliveryLoadStatus.secureStorageFailure;
      errorMessage = 'Your saved sign-in could not be accessed. Close and reopen the app, then try loading Delivery work again.';
      _notifyDeliveryListeners();
    } on ApiContractException {
      if (epoch != _loadEpoch) {
        return;
      }
      loadStatus = DeliveryLoadStatus.failed;
      errorMessage =
          'Delivery work could not be loaded. Please retry in a moment.';
      _notifyDeliveryListeners();
    } finally {
      if (epoch == _loadEpoch) {
        _loadInFlight = false;
        _notifyDeliveryListeners();
      }
    }
  }

  Future<void> loadDetails(PickupTask task) async {
    final taskId = task.id;
    if (contextStatuses[taskId] == DeliveryLoadStatus.loading ||
        !canRetryRateLimit) {
      return;
    }
    contextStatuses[taskId] = DeliveryLoadStatus.loading;
    contextErrors[taskId] = null;
    _notifyDeliveryListeners();

    try {
      final context = await deliveryRepository.fetchDeliveryContext(taskId);
      contexts[taskId] = context;
      final currentTask = taskById(taskId);
      if (currentTask != null) {
        _replaceTask(
          currentTask.copyWith(
            rawStatus: context.status,
            revision: context.revision,
          ),
        );
      }
      contextStatuses[taskId] = DeliveryLoadStatus.loaded;
      contextErrors[taskId] = null;
      _notifyDeliveryListeners();
    } on ApiException catch (error) {
      await _setContextError(taskId, error);
    } on TokenStorageException {
      contextStatuses[taskId] = DeliveryLoadStatus.secureStorageFailure;
      contextErrors[taskId] = 'Your saved sign-in could not be accessed. Close and reopen the app, then try loading this delivery again.';
      _notifyDeliveryListeners();
    } on ApiContractException {
      contextStatuses[taskId] = DeliveryLoadStatus.failed;
      contextErrors[taskId] = 'Delivery details could not be loaded. Refresh the task and try again.';
      _notifyDeliveryListeners();
    }

    final current = taskById(taskId) ?? task;
    if (current.status == PickupTaskStatus.outForDelivery ||
        current.status == PickupTaskStatus.delivered) {
      await loadCompletion(current);
    }
  }

  Future<void> loadCompletion(PickupTask task) async {
    final taskId = task.id;
    if (completionStatuses[taskId] == DeliveryLoadStatus.loading ||
        !canRetryRateLimit) {
      return;
    }
    completionStatuses[taskId] = DeliveryLoadStatus.loading;
    completionErrors[taskId] = null;
    _notifyDeliveryListeners();
    try {
      final completion = await deliveryRepository.fetchCompletion(taskId);
      completions[taskId] = completion;
      completionStatuses[taskId] = DeliveryLoadStatus.loaded;
      completionErrors[taskId] = null;
      _syncTaskFromCompletion(task, completion);
      _reconcileActionWithCompletion(taskId, completion);
      _notifyDeliveryListeners();
      final evidenceId = completion.evidenceId;
      if (evidenceId != null) {
        await loadProofPhoto(evidenceId, force: true);
      }
    } on ApiException catch (error) {
      await _setCompletionError(taskId, error);
    } on TokenStorageException {
      completionStatuses[taskId] = DeliveryLoadStatus.secureStorageFailure;
      completionErrors[taskId] = 'Your saved sign-in could not be accessed. Close and reopen the app, then check the delivery review status again.';
      _notifyDeliveryListeners();
    } on ApiContractException {
      completionStatuses[taskId] = DeliveryLoadStatus.failed;
      completionErrors[taskId] = 'The delivery review status could not be loaded. Refresh the task to check whether Logistics has confirmed delivery.';
      _notifyDeliveryListeners();
    }
  }

  Future<void> retry() => load();
}
