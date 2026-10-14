part of '../account_screen.dart';

extension _AccountScreenSecurity on _AccountScreenState {
  Future<void> _changePassword() async {
    if (widget.accountController.isBusy || _isClosingForSession) return;
    if (!_passwordFormKey.currentState!.validate()) {
      await _revealAccountError(_passwordFieldOrder);
      return;
    }

    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final passwordConfirmation = _passwordConfirmationController.text;
    final sent = await widget.accountController.requestPasswordCode(
      currentPassword: currentPassword,
      password: newPassword,
      passwordConfirmation: passwordConfirmation,
    );
    if (!mounted || _isClosingForSession) return;
    if (sent) {
      FocusManager.instance.primaryFocus?.unfocus();
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => PasswordVerificationDialog(
          controller: widget.accountController,
          hasUnsavedProfileChanges:
              _profileHasLocalEdits() || _pendingProfilePhoto != null,
          onVerify: (code) => widget.accountController.changePassword(
            currentPassword: currentPassword,
            password: newPassword,
            passwordConfirmation: passwordConfirmation,
            verificationCode: code,
          ),
          onResend: () => widget.accountController.requestPasswordCode(
            currentPassword: currentPassword,
            password: newPassword,
            passwordConfirmation: passwordConfirmation,
          ),
        ),
      );
      if (!mounted) return;
      widget.accountController.cancelPasswordVerification();
      _clearPasswordFields();
    }

    if (mounted) {
      await _closeIfSessionEnded();
      if (!_isClosingForSession &&
          widget.accountController.fieldErrors.isNotEmpty) {
        await _revealAccountError(_passwordFieldOrder);
      }
    }
  }

  void _clearPasswordFields() {
    if (!mounted) return;
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _passwordConfirmationController.clear();
  }

  Widget _buildSecuritySection(BuildContext context) {
    final controller = widget.accountController;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Security',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Changing your password revokes all current sessions.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        Form(
          key: _passwordFormKey,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  _PasswordField(
                    fieldKey: _fieldNavigation.fieldKey('current_password'),
                    focusNode: _fieldNavigation.focusNode('current_password'),
                    controller: _currentPasswordController,
                    enabled: !controller.isBusy,
                    label: 'Current password',
                    obscureText: _obscureCurrentPassword,
                    onToggle: () {
                      _updateState(() {
                        _obscureCurrentPassword = !_obscureCurrentPassword;
                      });
                    },
                    serverError: controller.fieldError('current_password'),
                  ),
                  const SizedBox(height: 12),
                  _PasswordField(
                    fieldKey: _fieldNavigation.fieldKey('password'),
                    focusNode: _fieldNavigation.focusNode('password'),
                    controller: _newPasswordController,
                    enabled: !controller.isBusy,
                    label: 'New password',
                    obscureText: _obscureNewPassword,
                    onToggle: () {
                      _updateState(() {
                        _obscureNewPassword = !_obscureNewPassword;
                      });
                    },
                    serverError: controller.fieldError('password'),
                  ),
                  const SizedBox(height: 12),
                  _PasswordField(
                    fieldKey: _fieldNavigation.fieldKey(
                      'password_confirmation',
                    ),
                    focusNode: _fieldNavigation.focusNode(
                      'password_confirmation',
                    ),
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _changePassword(),
                    controller: _passwordConfirmationController,
                    enabled: !controller.isBusy,
                    label: 'Confirm new password',
                    obscureText: _obscurePasswordConfirmation,
                    onToggle: () {
                      _updateState(() {
                        _obscurePasswordConfirmation =
                            !_obscurePasswordConfirmation;
                      });
                    },
                    serverError: controller.fieldError('password_confirmation'),
                    validator: (value) {
                      final requiredError = _required(value, 'confirmation');
                      if (requiredError != null) {
                        return requiredError;
                      }
                      if (value != _newPasswordController.text) {
                        return 'Passwords do not match.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Semantics(
                    button: true,
                    label: controller.status == AccountStatus.changingPassword
                        ? 'Changing password'
                        : 'Send verification code',
                    child: OutlinedButton.icon(
                      onPressed: controller.isBusy ? null : _changePassword,
                      icon: controller.status == AccountStatus.changingPassword
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.lock_reset_outlined),
                      label: Text(
                        controller.status == AccountStatus.changingPassword
                            ? 'Please wait…'
                            : 'Send verification code',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
