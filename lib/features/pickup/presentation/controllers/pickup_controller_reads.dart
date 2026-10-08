part of 'pickup_controller.dart';

extension PickupControllerReads on PickupController {
  Future<void> load() async {
    if (_loadInFlight || !canRetryRateLimit) {
      return;
    }

    final epoch = ++_loadEpoch;
    _loadInFlight = true;
    _authFailureNotified = false;
    retryAfter = null;
    firstMileStatus = PickupSectionStatus.loading;
    finalMileStatus = PickupSectionStatus.loading;
    firstMileErrorMessage = null;
    finalMileErrorMessage = null;
    _notifyPickupListeners();

    await Future.wait<void>(<Future<void>>[
      _loadFirstMile(epoch),
      _loadFinalMile(epoch),
    ]);

    if (epoch == _loadEpoch) {
      _loadInFlight = false;
      _notifyPickupListeners();
    }
  }

  Future<void> _loadFinalMile(int epoch) async {
    try {
      final tasks = await pickupRepository.fetchFinalMileTasks();
      if (epoch != _loadEpoch) {
        return;
      }
      finalMileTasks = List<PickupTask>.unmodifiable(tasks);
      finalMileStatus = tasks.isEmpty
          ? PickupSectionStatus.empty
          : PickupSectionStatus.loaded;
      finalMileErrorMessage = null;
      _notifyPickupListeners();
    } on ApiException catch (error) {
      await _setSectionError(firstMile: false, error: error, epoch: epoch);
    } on TokenStorageException {
      if (epoch != _loadEpoch) {
        return;
      }
      finalMileStatus = PickupSectionStatus.secureStorageFailure;
      finalMileErrorMessage = 'Secure session storage is unavailable. Pickup work cannot be loaded.';
      _notifyPickupListeners();
    } on ApiContractException {
      if (epoch != _loadEpoch) {
        return;
      }
      finalMileStatus = PickupSectionStatus.failed;
      finalMileErrorMessage = 'The hub pickup service returned an unexpected response. Please retry.';
      _notifyPickupListeners();
    }
  }

  Future<PickupRouteManifest?> loadRouteManifest(
    String scheduleId, {
    bool refresh = false,
  }) async {
    final key = scheduleId.trim();
    if (_disposed ||
        !canRetryRateLimit ||
        key.isEmpty ||
        (!refresh && routeStatuses[key] == PickupSectionStatus.loading)) {
      return routeManifests[key];
    }
    final epoch = _loadEpoch;
    final request = (_routeRequests[key] ?? 0) + 1;
    _routeRequests[key] = request;
    bool current() =>
        !_disposed && epoch == _loadEpoch && request == _routeRequests[key];

    routeStatuses[key] = PickupSectionStatus.loading;
    routeErrors[key] = null;
    _notifyPickupListeners();
    try {
      final manifest = await pickupRepository.fetchRouteManifest(key);
      if (!current()) return null;
      routeManifests[key] = manifest;
      routeStatuses[key] = manifest.status == RouteManifestStatus.unavailable
          ? PickupSectionStatus.failed
          : PickupSectionStatus.loaded;
      _notifyPickupListeners();
      return manifest;
    } on ApiException catch (error) {
      if (!current()) return null;
      if (error.statusCode == 401 ||
          error.statusCode == 403 ||
          error.statusCode == 404 ||
          error.statusCode == 409) {
        routeManifests.remove(key);
      }
      routeStatuses[key] = _sectionStateFor(error);
      routeErrors[key] = _messageForError(error);
      if (error.statusCode == 429) {
        _startRetryDelay(error.retryAfter);
      }
      _notifyPickupListeners();
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _notifyAuthFailure(error);
      }
    } on TokenStorageException {
      if (!current()) return null;
      routeManifests.remove(key);
      routeStatuses[key] = PickupSectionStatus.secureStorageFailure;
      routeErrors[key] =
          'Secure session storage is unavailable. The route cannot be loaded.';
      _notifyPickupListeners();
    } on ApiContractException {
      if (!current()) return null;
      routeStatuses[key] = PickupSectionStatus.failed;
      routeErrors[key] =
          'The route service returned an unexpected response. Please retry.';
      _notifyPickupListeners();
    }
    return routeManifests[key];
  }

  void releaseRouteManifest(String scheduleId) {
    _routeRequests[scheduleId] = (_routeRequests[scheduleId] ?? 0) + 1;
    routeManifests.remove(scheduleId);
    routeStatuses.remove(scheduleId);
    routeErrors.remove(scheduleId);
  }

  void holdRouteRetry(Duration? delay) {
    if (_disposed) return;
    final requested = delay ?? const Duration(seconds: 30);
    if (_retryTimer != null && retryAfter != null && retryAfter! > requested) {
      return;
    }
    _startRetryDelay(requested);
  }

  Future<void> retry() => load();

  void clearResolution() {
    lastWaybillResolution = null;
    waybillResolutionError = null;
    waybillResolutionStatus = null;
    _notifyPickupListeners();
  }
}
