part of 'vehicle_controller.dart';

extension VehicleControllerErrors on VehicleController {
  Future<void> _setLoadError(ApiException error) async {
    loadStatus = _loadStateFor(error);
    errorMessage = _messageForError(error, subject: 'vehicle information');
    if (loadStatus == VehicleLoadStatus.rateLimited) {
      _startRetryDelay(error.retryAfter);
    }
    _notifyVehicleListeners();
    if (error.statusCode == 401 || error.statusCode == 403) {
      await _notifyAuthFailure(error);
    }
  }

  Future<void> _setUpdateError(ApiException error) async {
    updateStatus = _actionStateFor(error);
    updateErrorMessage = _messageForError(error, subject: 'vehicle details');
    updateSuccessMessage = null;
    updateFieldErrors = error.fieldErrors;
    if (updateStatus == VehicleActionStatus.rateLimited) {
      _startRetryDelay(error.retryAfter);
    }
    _notifyVehicleListeners();
    if (error.statusCode == 409) {
      await _refreshAfterConflict();
    }
    if (error.statusCode == 401 || error.statusCode == 403) {
      await _notifyAuthFailure(error);
    }
  }

  Future<void> _setDocumentError(
    VehicleDocumentKind kind,
    ApiException error,
  ) async {
    _documentStatuses[kind] = _actionStateFor(error);
    _documentErrors[kind] = _messageForError(
      error,
      subject: '${kind.shortLabel} document',
    );
    _documentSuccessMessages[kind] = null;
    _documentFieldErrors[kind] = error.fieldErrors;
    if (_documentStatuses[kind] == VehicleActionStatus.rateLimited) {
      _startRetryDelay(error.retryAfter);
    }
    _notifyVehicleListeners();
    if (error.statusCode == 409) {
      await _refreshAfterConflict();
    }
    if (error.statusCode == 401 || error.statusCode == 403) {
      await _notifyAuthFailure(error);
    }
  }

  Future<void> _setDocumentPreviewError(
    VehicleDocumentKind kind,
    ApiException error,
  ) async {
    _documentPreviewStatuses[kind] = _previewStateFor(error);
    _documentPreviewErrors[kind] = _messageForError(
      error,
      subject: 'private ${kind.shortLabel} document',
    );
    if (_documentPreviewStatuses[kind] ==
        VehicleDocumentPreviewStatus.rateLimited) {
      _startRetryDelay(error.retryAfter);
    }
    _notifyVehicleListeners();
    if (error.statusCode == 401 || error.statusCode == 403) {
      await _notifyAuthFailure(error);
    }
  }

  Future<void> _reconcileUncertainUpdate(ApiException error) async {
    final generation = _generation;
    try {
      final refreshedVehicle = await vehicleRepository.fetchVehicle();
      if (_disposed || generation != _generation) return;
      vehicle = refreshedVehicle;
      updateStatus = _actionStateFor(error);
      updateErrorMessage = 'The save result was uncertain. We refreshed your vehicle; review the values and retry the same save if needed.';
      updateSuccessMessage = null;
      updateFieldErrors = const <String, List<String>>{};
      _notifyVehicleListeners();
    } on ApiException catch (refreshError) {
      if (_disposed || generation != _generation) return;
      await _setUpdateError(refreshError);
    } on TokenStorageException {
      if (_disposed || generation != _generation) return;
      updateStatus = VehicleActionStatus.secureStorageFailure;
      updateErrorMessage = 'Secure session storage is unavailable. The save result is uncertain.';
      _notifyVehicleListeners();
    } on ApiContractException {
      if (_disposed || generation != _generation) return;
      updateStatus = VehicleActionStatus.failed;
      updateErrorMessage = 'The save result was uncertain and could not be reconciled. Refresh before retrying.';
      _notifyVehicleListeners();
    }
  }

  Future<void> _reconcileUncertainDocument(
    VehicleDocumentKind kind,
    ApiException error,
  ) async {
    final generation = _generation;
    try {
      final refreshedVehicle = await vehicleRepository.fetchVehicle();
      if (_disposed || generation != _generation) return;
      vehicle = refreshedVehicle;
      _documentStatuses[kind] = _actionStateFor(error);
      _documentErrors[kind] =
          'The ${kind.shortLabel} upload result was uncertain. We refreshed the vehicle; review the current document and retry if needed.';
      _documentSuccessMessages[kind] = null;
      _documentFieldErrors[kind] = const <String, List<String>>{};
      _notifyVehicleListeners();
    } on ApiException catch (refreshError) {
      if (_disposed || generation != _generation) return;
      await _setDocumentError(kind, refreshError);
    } on TokenStorageException {
      if (_disposed || generation != _generation) return;
      _documentStatuses[kind] = VehicleActionStatus.secureStorageFailure;
      _documentErrors[kind] = 'Secure session storage is unavailable. The upload result is uncertain.';
      _notifyVehicleListeners();
    } on ApiContractException {
      if (_disposed || generation != _generation) return;
      _documentStatuses[kind] = VehicleActionStatus.failed;
      _documentErrors[kind] = 'The upload result was uncertain and could not be reconciled. Refresh before retrying.';
      _notifyVehicleListeners();
    }
  }

  Future<void> _refreshAfterConflict() async {
    final generation = _generation;
    try {
      final refreshedVehicle = await vehicleRepository.fetchVehicle();
      if (_disposed || generation != _generation) return;
      vehicle = refreshedVehicle;
      _notifyVehicleListeners();
    } on ApiException catch (error) {
      if (_disposed || generation != _generation) return;
      loadStatus = _loadStateFor(error);
      errorMessage = _messageForError(error, subject: 'vehicle information');
      _notifyVehicleListeners();
    } on TokenStorageException {
      if (_disposed || generation != _generation) return;
      loadStatus = VehicleLoadStatus.secureStorageFailure;
      errorMessage = 'Secure session storage is unavailable. Refresh could not be completed.';
      _notifyVehicleListeners();
    } on ApiContractException {
      if (_disposed || generation != _generation) return;
      loadStatus = VehicleLoadStatus.failed;
      errorMessage =
          'The refreshed vehicle response was not understood. Please retry.';
      _notifyVehicleListeners();
    }
  }

  Future<void> _notifyAuthFailure(ApiException error) async {
    if (_authFailureNotified) {
      return;
    }
    _authFailureNotified = true;
    await onAuthFailure?.call(error);
  }

  void _setLocalUpdateError(String message) {
    updateStatus = VehicleActionStatus.validationError;
    updateErrorMessage = message;
    updateSuccessMessage = null;
    _notifyVehicleListeners();
  }
}
