part of '../registration_screen.dart';

const _registrationFieldOrder = <String>[
  'first_name',
  'last_name',
  'middle_name',
  'sex',
  'contact_number',
  'birth_date',
  'email',
  'logistics_organization_id',
  'address.address_line_1',
  'address.address_line_2',
  'address.region',
  'address.province',
  'address.city_municipality',
  'address.barangay',
  'address.postal_code',
  'vehicle_type',
  'plate_number',
  'government_id',
  'vehicle_registration',
  'password',
  'password_confirmation',
];

extension _RegistrationInteraction on _RegistrationScreenState {
  List<TextEditingController> get _textControllers => [
    _firstNameController,
    _lastNameController,
    _middleNameController,
    _contactNumberController,
    _birthDateController,
    _emailController,
    _passwordController,
    _passwordConfirmationController,
    _plateNumberController,
    _addressLine1Controller,
    _addressLine2Controller,
    _regionController,
    _provinceController,
    _cityMunicipalityController,
    _barangayController,
    _postalCodeController,
  ];

  bool get _hasUnsavedChanges =>
      _result == null &&
      (_textControllers.any(
            (controller) =>
                controller != _emailController && controller.text.isNotEmpty,
          ) ||
          _sex != null ||
          _vehicleType != null ||
          _organization != null ||
          _governmentId != null ||
          _vehicleRegistration != null);

  void _onDraftChanged() {
    if (mounted) _updateState(() {});
  }

  void _leaveRegistration() {
    unawaited(_leaveGuardKey.currentState?.requestLeave());
  }

  Future<void> _revealRegistrationError() async {
    for (final key in _registrationFieldOrder) {
      if (_serverError(key) != null ||
          _fieldNavigation.fieldKey(key).currentState?.hasError == true) {
        _goToStep(_stepForField(key));
        break;
      }
    }
    await _fieldNavigation.revealFirstError(
      _registrationFieldOrder,
      errors: _fieldErrors,
    );
  }
}
