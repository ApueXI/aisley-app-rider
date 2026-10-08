part of '../account_screen.dart';

const _profileFieldOrder = <String>[
  'first_name',
  'middle_name',
  'last_name',
  'contact_number',
];
const _passwordFieldOrder = <String>[
  'current_password',
  'password',
  'password_confirmation',
];

extension _AccountScreenInteraction on _AccountScreenState {
  List<TextEditingController> get _textControllers => [
    _firstNameController,
    _middleNameController,
    _lastNameController,
    _contactNumberController,
    _currentPasswordController,
    _newPasswordController,
    _passwordConfirmationController,
  ];

  bool get _hasUnsavedChanges =>
      !_isClosingForSession &&
      (_profileHasLocalEdits() ||
          _pendingProfilePhoto != null ||
          _currentPasswordController.text.isNotEmpty ||
          _newPasswordController.text.isNotEmpty ||
          _passwordConfirmationController.text.isNotEmpty);

  bool get _hasPendingAccountMutation =>
      _isPickingProfilePhoto ||
      widget.accountController.status == AccountStatus.savingProfile ||
      widget.accountController.status == AccountStatus.changingPassword ||
      widget.accountController.profilePhotoStatus ==
          ProfilePhotoStatus.uploading ||
      widget.accountController.profilePhotoStatus ==
          ProfilePhotoStatus.deleting;

  void _onDraftChanged() {
    if (mounted) _updateState(() {});
  }

  void _onAccountScopeChanged() {
    if (!mounted || _isClosingForSession) return;
    final auth = widget.authController;
    final account = widget.accountController;
    final scopeChanged =
        _sessionCourierId != null && auth.courier?.id != _sessionCourierId;
    final accessLost =
        auth.status != AuthStatus.authenticated ||
        scopeChanged ||
        account.status == AccountStatus.signedOut ||
        account.status == AccountStatus.forbidden ||
        (_hasPopulatedProfile && account.account == null);
    if (!accessLost) return;
    _isClosingForSession = true;
    _cancelProfilePhotoUpload?.call();
    _cancelProfilePhotoUpload = null;
    _pendingProfilePhoto = null;
    _profilePhotoSelectionError = null;
    for (final controller in _textControllers) {
      controller.clear();
    }
    _hasPopulatedProfile = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _leaveGuardKey.currentState?.leaveWithoutConfirmation();
    });
    _updateState(() {});
  }

  Future<void> _revealAccountError(List<String> fields) => _fieldNavigation
      .revealFirstError(fields, errors: widget.accountController.fieldErrors);
}
