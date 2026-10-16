part of '../registration_screen.dart';

int _stepForField(String key) {
  final normalized = key.replaceAll('[', '.').replaceAll(']', '');
  if (normalized == 'email_verification_token') return 0;
  if (normalized.startsWith('address.') ||
      const {
        'region',
        'province',
        'city_municipality',
        'barangay',
        'postal_code',
        'address_line_1',
        'address_line_2',
      }.contains(normalized)) {
    return 2;
  }
  if (const {
    'logistics_organization_id',
    'vehicle_type',
    'plate_number',
  }.contains(normalized)) {
    return 3;
  }
  if (const {'government_id', 'vehicle_registration'}.contains(normalized)) {
    return 4;
  }
  if (normalized.startsWith('password')) return 5;
  return 1;
}

extension _RegistrationStepNavigation on _RegistrationScreenState {
  void _goToStep(int step) {
    FocusManager.instance.primaryFocus?.unfocus();
    _updateState(() => _step = _verification.verified ? step : 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _stepScrolls[_step].hasClients) {
        _stepScrolls[_step].jumpTo(0);
      }
    });
  }

  void _backRegistration() {
    if (_step > 0) {
      _goToStep(_step - 1);
    } else {
      _leaveRegistration();
    }
  }

  Future<void> _continueStep() async {
    if (_isSubmitting || _isPickingEvidence || !_verification.verified) return;
    if (_step == 0) {
      _goToStep(1);
      return;
    }
    _updateState(() {
      _fieldErrors = {};
      _submissionError = null;
    });
    var valid = _stepFormKeys[_step - 1].currentState?.validate() ?? false;
    if (_step == 2 && !_validatePsgcAddress()) valid = false;
    if (_step == 4) {
      if (_governmentId == null) {
        _fieldErrors = {
          ..._fieldErrors,
          'government_id': ['Select a government ID image.'],
        };
      }
      if (_vehicleRegistration == null) {
        _fieldErrors = {
          ..._fieldErrors,
          'vehicle_registration': ['Select a vehicle registration image.'],
        };
      }
      if (_fieldErrors.isNotEmpty) valid = false;
    }
    if (!valid) {
      _updateState(
        () => _submissionError =
            'Review the highlighted fields before continuing.',
      );
      await _revealRegistrationError();
      return;
    }
    _goToStep((_step + 1).clamp(0, 5));
  }

  Widget _buildReviewSummary(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Review your application',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      _reviewEntry(
        'Personal details',
        '${_firstNameController.text} ${_lastNameController.text}\n${_emailController.text}',
        1,
      ),
      _reviewEntry(
        'Address',
        [
          _addressLine1Controller.text,
          _barangayController.text,
          _cityMunicipalityController.text,
          _provinceController.text,
          _regionController.text,
          _postalCodeController.text,
        ].where((s) => s.isNotEmpty).join(', '),
        2,
      ),
      _reviewEntry(
        'Logistics and vehicle',
        '${_organization?.businessName ?? 'Choose Logistics'}\n${_vehicleType ?? 'Choose vehicle'} · ${_plateNumberController.text}',
        3,
      ),
      _reviewEntry(
        'Evidence',
        '${_governmentId?.fileName ?? 'ID required'}\n${_vehicleRegistration?.fileName ?? 'OR/CR required'}',
        4,
      ),
    ],
  );

  Widget _reviewEntry(String title, String value, int step) => Column(
    children: [
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title),
        subtitle: Text(value),
        trailing: const Icon(Icons.edit_outlined),
        onTap: _isSubmitting ? null : () => _goToStep(step),
      ),
      const Divider(height: 1),
    ],
  );
}
