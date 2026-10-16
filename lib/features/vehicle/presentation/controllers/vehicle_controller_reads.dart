part of 'vehicle_controller.dart';

extension VehicleControllerReads on VehicleController {
  Future<void> load() async {
    if (_disposed || _loading || !canRetryRateLimit) {
      return;
    }
    final generation = _generation;
    _loading = true;
    _authFailureNotified = false;
    retryAfter = null;
    loadStatus = VehicleLoadStatus.loading;
    errorMessage = null;
    _notifyVehicleListeners();

    try {
      final loadedVehicle = await vehicleRepository.fetchVehicle();
      if (_disposed || generation != _generation) return;
      vehicle = loadedVehicle;
      loadStatus = VehicleLoadStatus.loaded;
      errorMessage = null;
      _notifyVehicleListeners();
    } on ApiException catch (error) {
      if (_disposed || generation != _generation) return;
      await _setLoadError(error);
    } on TokenStorageException {
      if (_disposed || generation != _generation) return;
      loadStatus = VehicleLoadStatus.secureStorageFailure;
      errorMessage = 'Secure session storage is unavailable. Vehicle information cannot be loaded.';
      _notifyVehicleListeners();
    } on ApiContractException {
      if (_disposed || generation != _generation) return;
      loadStatus = VehicleLoadStatus.failed;
      errorMessage = 'The vehicle response was not understood. Please retry.';
      _notifyVehicleListeners();
    } finally {
      if (generation == _generation) _loading = false;
    }
  }

  Future<void> retry() => load();
}
