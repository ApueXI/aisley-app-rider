part of 'account_controller.dart';

extension AccountControllerPassword on AccountController {
  void cancelPasswordVerification() {
    if (isBusy) return;
    passwordChallenge = null;
    fieldErrors = const {};
    _notify();
  }

  Future<bool> requestPasswordCode({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) async {
    if (isBusy ||
        passwordCoolingDown ||
        passwordRequiresReconciliation ||
        (passwordChallenge?.resendSeconds ?? 0) > 0) {
      return false;
    }
    final operationEpoch = ++_operationEpoch;
    status = AccountStatus.changingPassword;
    errorMessage = null;
    successMessage = null;
    fieldErrors = const {};
    _notify();
    try {
      final result = await _accountRepository.requestPasswordCode(
        currentPassword: currentPassword,
        password: password,
        passwordConfirmation: passwordConfirmation,
      );
      if (operationEpoch != _operationEpoch) return false;
      passwordChallenge = result;
      status = AccountStatus.loaded;
      successMessage = 'Your password verification email is queued.';
      _notify();
      return true;
    } on ApiException catch (error) {
      if (operationEpoch == _operationEpoch) {
        if (error.statusCode == 429) {
          passwordRetryAt = DateTime.now().add(
            error.retryAfter ?? const Duration(seconds: 60),
          );
        }
        if (error.isNetworkError || (error.statusCode ?? 0) >= 500) {
          passwordRetryAt = DateTime.now().add(const Duration(seconds: 60));
        }
        await _handleApiError(error);
      }
    } on TokenStorageException {
      if (operationEpoch == _operationEpoch) _setSecureStorageFailure();
    } on ApiContractException {
      if (operationEpoch == _operationEpoch) {
        passwordRetryAt = DateTime.now().add(const Duration(seconds: 60));
        _setRetryableFailure(
          'Unexpected verification response. Wait one minute before requesting a new code.',
        );
      }
    }
    return false;
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
    required String verificationCode,
  }) async {
    if (isBusy ||
        passwordCoolingDown ||
        passwordRequiresReconciliation ||
        passwordChallenge == null ||
        passwordChallenge!.expired) {
      return false;
    }

    final operationEpoch = ++_operationEpoch;
    status = AccountStatus.changingPassword;
    errorMessage = null;
    successMessage = null;
    fieldErrors = const <String, List<String>>{};
    _notify();

    try {
      await _accountRepository.changePassword(
        currentPassword: currentPassword,
        password: password,
        passwordConfirmation: passwordConfirmation,
        challengeId: passwordChallenge!.id,
        verificationCode: verificationCode,
      );
      if (operationEpoch != _operationEpoch) {
        return false;
      }
      passwordChallenge = null;
      account = null;
      profilePhoto = null;
      profilePhotoStatus = ProfilePhotoStatus.idle;
      _clearProfilePhotoMessages();
      await _onPasswordChanged?.call();
      status = AccountStatus.signedOut;
      _notify();
      return true;
    } on ApiException catch (error) {
      if (operationEpoch != _operationEpoch) {
        return false;
      }
      if (error.statusCode == 429) {
        passwordRetryAt = DateTime.now().add(
          error.retryAfter ?? const Duration(seconds: 60),
        );
      }
      await _handleApiError(error);
      if (error.isNetworkError || (error.statusCode ?? 0) >= 500) {
        passwordRequiresReconciliation = true;
        passwordChallenge = null;
        _setRetryableFailure(
          'The password change outcome is uncertain. Sign out and check sign-in before another change.',
        );
      }
    } on TokenStorageException {
      if (operationEpoch != _operationEpoch) {
        return false;
      }
      _setSecureStorageFailure();
    } on ApiContractException {
      if (operationEpoch != _operationEpoch) {
        return false;
      }
      _setRetryableFailure(
        'The account service returned an unexpected response. Please retry.',
      );
    }
    return false;
  }
}
