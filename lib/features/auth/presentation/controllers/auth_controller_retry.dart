part of 'auth_controller.dart';

extension AuthControllerRetry on AuthController {
  Duration _retryDelay(Duration? delay) =>
      delay != null && delay > Duration.zero
      ? delay
      : const Duration(seconds: 1);

  void _startLoginCooldown(Duration? delay) {
    _loginRetryTimer?.cancel();
    retryAfter = _retryDelay(delay);
    _loginRetryTimer = Timer(retryAfter!, () {
      _loginRetryTimer = null;
      retryAfter = null;
      _notify();
    });
  }

  void _startSessionCooldown(Duration? delay) {
    _sessionRetryTimer?.cancel();
    sessionRetryAfter = _retryDelay(delay);
    _sessionRetryTimer = Timer(sessionRetryAfter!, () {
      _sessionRetryTimer = null;
      sessionRetryAfter = null;
      _notify();
    });
  }

  void _startRegistrationCooldown(Duration? delay) {
    _registrationRetryTimer?.cancel();
    registrationRetryAfter = _retryDelay(delay);
    _registrationRetryTimer = Timer(registrationRetryAfter!, () {
      _registrationRetryTimer = null;
      registrationRetryAfter = null;
      _notify();
    });
  }
}
