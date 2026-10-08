part of 'delivery_controller.dart';

extension DeliveryControllerErrors on DeliveryController {
  Future<void> _setLoadError(ApiException error, int epoch) async {
    if (epoch != _loadEpoch) {
      return;
    }
    loadStatus = _loadStateFor(error);
    errorMessage = _messageForError(error);
    if (loadStatus == DeliveryLoadStatus.rateLimited) {
      _startRetryDelay(error.retryAfter);
    }
    _notifyDeliveryListeners();
    if (error.statusCode == 401) {
      clearAllProofPhotos(notify: false);
      await _notifyAuthFailure(error);
    }
  }

  Future<void> _setContextError(String taskId, ApiException error) async {
    contextStatuses[taskId] = _loadStateFor(error);
    contextErrors[taskId] = _messageForError(error);
    if (contextStatuses[taskId] == DeliveryLoadStatus.rateLimited) {
      _startRetryDelay(error.retryAfter);
    }
    _notifyDeliveryListeners();
    if (error.statusCode == 401) {
      clearAllProofPhotos(notify: false);
      await _notifyAuthFailure(error);
    }
  }

  Future<void> _setCompletionError(String taskId, ApiException error) async {
    completionStatuses[taskId] = _loadStateFor(error);
    completionErrors[taskId] = _messageForError(error);
    if (completionStatuses[taskId] == DeliveryLoadStatus.rateLimited) {
      _startRetryDelay(error.retryAfter);
    }
    _notifyDeliveryListeners();
    if (error.statusCode == 401) {
      clearAllProofPhotos(notify: false);
      await _notifyAuthFailure(error);
    }
  }

  Future<void> _setActionError(
    PickupTask task,
    ApiException error, {
    bool submission = true,
  }) async {
    _actionStatuses[task.id] = _actionStateFor(error);
    _actionErrors[task.id] = _messageForError(error, submission: submission);
    _actionRetryAfter[task.id] = error.retryAfter;
    if (_actionStatuses[task.id] == DeliveryActionStatus.rateLimited) {
      _startRetryDelay(error.retryAfter);
    }
    _notifyDeliveryListeners();
    if (error.statusCode == 401) {
      clearAllProofPhotos(notify: false);
      await _notifyAuthFailure(error);
    }
  }

  void _setLocalValidationError(PickupTask task, String message) {
    _actionStatuses[task.id] = DeliveryActionStatus.validationError;
    _actionErrors[task.id] = message;
    _actionRetryAfter[task.id] = null;
    _notifyDeliveryListeners();
  }

  void _setStorageActionError(PickupTask task) {
    _actionStatuses[task.id] = DeliveryActionStatus.secureStorageFailure;
    _actionErrors[task.id] = 'Your saved sign-in could not be accessed. Close and reopen the app, then refresh the task before trying again.';
    _notifyDeliveryListeners();
  }

  void _setContractActionError(PickupTask task, {bool submission = true}) {
    _actionStatuses[task.id] = DeliveryActionStatus.failed;
    _actionErrors[task.id] = submission
        ? 'We could not confirm the result of this delivery update. Refresh the task before retrying the same action.'
        : 'Delivery information could not be loaded. Refresh the task and try again.';
    _notifyDeliveryListeners();
  }

  Future<void> _notifyAuthFailure(ApiException error) async {
    if (_authFailureNotified) {
      return;
    }
    _authFailureNotified = true;
    await onAuthFailure?.call(error);
  }

  void _startRetryDelay(Duration? delay) {
    _retryTimer?.cancel();
    if (delay == null || delay <= Duration.zero) {
      _retryTimer = null;
      return;
    }
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      retryAfter = null;
      _notifyDeliveryListeners();
    });
    retryAfter = delay;
  }

  DeliveryLoadStatus _loadStateFor(ApiException error) {
    if (error.statusCode == 401) {
      return DeliveryLoadStatus.unauthorized;
    }
    if (error.statusCode == 403) {
      return error.code == 'POLICY_CONSENT_REQUIRED'
          ? DeliveryLoadStatus.consentRequired
          : DeliveryLoadStatus.forbidden;
    }
    if (error.statusCode == 429) {
      return DeliveryLoadStatus.rateLimited;
    }
    if (error.isNetworkError) {
      return error.networkFailure == ApiNetworkFailure.timeout
          ? DeliveryLoadStatus.timeout
          : DeliveryLoadStatus.offline;
    }
    return DeliveryLoadStatus.failed;
  }

  DeliveryActionStatus _actionStateFor(ApiException error) {
    if (error.statusCode == 401) {
      return DeliveryActionStatus.unauthorized;
    }
    if (error.statusCode == 403) {
      return error.code == 'POLICY_CONSENT_REQUIRED'
          ? DeliveryActionStatus.consentRequired
          : DeliveryActionStatus.forbidden;
    }
    if (error.statusCode == 409) {
      return DeliveryActionStatus.conflict;
    }
    if (error.statusCode == 422) {
      return DeliveryActionStatus.validationError;
    }
    if (error.statusCode == 429) {
      return DeliveryActionStatus.rateLimited;
    }
    if (error.isNetworkError) {
      return error.networkFailure == ApiNetworkFailure.timeout
          ? DeliveryActionStatus.timeout
          : DeliveryActionStatus.offline;
    }
    return DeliveryActionStatus.failed;
  }

  String _messageForError(ApiException error, {bool submission = false}) {
    if (error.code == 'POLICY_CONSENT_REQUIRED') {
      return 'Accept the current Terms of Service and Privacy Policy before delivery actions are available.';
    }
    if (error.code == 'PARCEL_NOT_FOUND') {
      return 'The parcel for this delivery task was not found. Refresh the task before trying again.';
    }
    if (error.code == 'TASK_STATE_CONFLICT') {
      return 'This delivery changed. Refresh the task and review its current status before trying again.';
    }
    if (error.code == 'COMPLETION_STATE_CONFLICT') {
      return 'The delivery review status changed. Refresh the task before trying again.';
    }
    if (error.code == 'COD_COLLECTION_REQUIRED') {
      return 'Confirm that you collected the full cash amount shown for this delivery before sending it to Logistics for review.';
    }
    if (error.statusCode == 404) {
      return 'This delivery is no longer available. Refresh to see current work.';
    }
    if (error.statusCode == 409) {
      if (error.code == 'PROOF_NOT_VALIDATED') {
        return 'Logistics has not validated the proof yet. Refresh before trying completion again.';
      }
      return 'This delivery changed on the server. Refresh before trying again.';
    }
    if (error.statusCode == 422) {
      final fields = error.fieldErrors.keys.toSet();
      if (fields.contains('expected_revision') || fields.contains('status')) {
        return 'Refresh the task and check its current status before trying again.';
      }
      if (fields.contains('photo')) {
        return 'Choose a JPEG, PNG or WebP delivery photo smaller than 10 MiB, then try again.';
      }
      if (fields.contains('evidence_id')) {
        return 'Upload a delivery photo for this task before sending it to Logistics for review.';
      }
      if (fields.contains('cod_collected') || fields.contains('confirmed')) {
        return 'Confirm that you collected the full cash amount shown for this delivery before sending it to Logistics for review.';
      }
      return 'Check the delivery information and try again. If the problem continues, refresh the task.';
    }
    if (error.statusCode == 429) {
      return 'Too many requests. Wait before trying again.';
    }
    if (error.isNetworkError) {
      if (submission) {
        return error.networkFailure == ApiNetworkFailure.timeout
            ? 'The request timed out, so your update is not confirmed. Refresh the task before retrying the same action.'
            : 'Check your connection. Your update is not confirmed; reconnect and refresh the task before retrying the same action.';
      }
      return error.networkFailure == ApiNetworkFailure.timeout
          ? 'Loading delivery information took too long. Check your connection and retry.'
          : 'Delivery information could not be loaded. Check your connection and retry.';
    }
    if (error.statusCode == 401) {
      return 'Your session has expired. Please sign in again.';
    }
    if (error.statusCode == 403) {
      return 'This delivery is not available to your Courier account. Contact your Logistics organization if you need help.';
    }
    return submission
        ? 'We could not confirm your delivery update. Refresh the task before retrying the same action.'
        : 'Delivery information could not be loaded. Please retry in a moment.';
  }
}
