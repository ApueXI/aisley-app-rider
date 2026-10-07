part of 'auth_controller.dart';

extension AuthControllerRegistration on AuthController {
  Future<List<LogisticsOption>> fetchLogisticsOptions({String? search}) {
    return _authRepository.fetchLogisticsOptions(search: search);
  }

  Future<RegistrationResult> register(
    CourierRegistrationRequest request, {
    void Function(void Function() cancel)? onCancel,
  }) async {
    if (!canRegister) {
      throw ApiException(
        statusCode: 429,
        code: 'THROTTLED',
        message: 'Please wait before submitting again.',
        retryAfter: registrationRetryAfter,
      );
    }
    try {
      return await _authRepository.register(request, onCancel: onCancel);
    } on ApiException catch (error) {
      if (error.statusCode == 429) {
        _startRegistrationCooldown(error.retryAfter);
        _notify();
      }
      rethrow;
    }
  }
}
