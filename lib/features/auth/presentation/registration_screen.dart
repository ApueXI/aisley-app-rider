import 'registration_email_controller.dart';
import 'registration_email_fields.dart';

import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_contract_exception.dart';
import '../../../shared/presentation/form_field_navigation.dart';
import '../../../shared/presentation/unsaved_changes_guard.dart';
import '../data/psgc_address_data_source.dart';
import '../domain/auth_models.dart';
import '../domain/psgc_address_models.dart';
import 'controllers/auth_controller.dart';

part 'components/registration_data.dart';
part 'components/registration_submission.dart';
part 'components/registration_form.dart';
part 'components/registration_step_navigation.dart';
part 'components/registration_step_personal.dart';
part 'components/registration_step_address.dart';
part 'components/registration_step_logistics.dart';
part 'components/registration_step_evidence.dart';
part 'components/registration_step_review.dart';
part 'components/registration_sections.dart';
part 'components/registration_address.dart';
part 'components/registration_fields.dart';
part 'components/registration_result.dart';
part 'components/registration_interaction.dart';

const _maxEvidenceBytes = 10 * 1024 * 1024;
const _evidenceTypeGroup = XTypeGroup(
  label: 'Images',
  extensions: <String>['jpg', 'jpeg', 'png', 'webp'],
);

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({
    required this.authController,
    required this.onSignIn,
    this.verificationClock,
    super.key,
  });

  final AuthController authController;
  final VoidCallback onSignIn;
  final DateTime Function()? verificationClock;

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  late final RegistrationEmailController _verification;
  final _emailVerificationFocus = FocusNode(debugLabel: 'registration_email');
  int _step = 0;
  bool _wasVerified = false;
  final _stepScrolls = List.generate(6, (_) => ScrollController());
  final _stepFormKeys = List.generate(5, (_) => GlobalKey<FormState>());
  final _leaveGuardKey = GlobalKey<UnsavedChangesGuardState>();
  final _fieldNavigation = FormFieldNavigation();
  final _psgcDataSource = PsgcAddressDataSource();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmationController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _plateNumberController = TextEditingController();
  final _addressLine1Controller = TextEditingController();
  final _addressLine2Controller = TextEditingController();
  final _barangayController = TextEditingController();
  final _cityMunicipalityController = TextEditingController();
  final _provinceController = TextEditingController();
  final _regionController = TextEditingController();
  final _postalCodeController = TextEditingController();

  List<LogisticsOption> _organizations = const <LogisticsOption>[];
  List<PsgcRegion> _psgcRegions = const <PsgcRegion>[];
  LogisticsOption? _organization;
  PsgcRegion? _psgcRegion;
  PsgcAddressNode? _psgcRegionTree;
  PsgcAddressNode? _psgcProvince;
  PsgcAddressNode? _psgcCity;
  PsgcAddressNode? _psgcBarangay;
  String? _sex;
  String? _vehicleType;
  DateTime? _birthDate;
  RegistrationUpload? _governmentId;
  RegistrationUpload? _vehicleRegistration;
  Map<String, List<String>> _fieldErrors = const <String, List<String>>{};
  String? _optionsError;
  String? _psgcError;
  String? _submissionError;
  RegistrationResult? _result;
  bool _isLoadingOrganizations = true;
  bool _isLoadingPsgc = true;
  bool _isLoadingPsgcRegion = false;
  bool _useManualAddress = false;
  bool _isSubmitting = false;
  bool _isPickingEvidence = false;
  bool _obscurePassword = true;
  bool _obscurePasswordConfirmation = true;
  int _submissionSerial = 0;
  VoidCallback? _cancelUpload;

  @override
  void initState() {
    super.initState();
    _verification = RegistrationEmailController(
      widget.authController.registrationEmailRepository,
      clock: widget.verificationClock,
    );
    _verification.addListener(_onVerificationChanged);
    widget.authController.addListener(_onDraftChanged);
    for (final controller in _textControllers) {
      controller.addListener(_onDraftChanged);
    }
    unawaited(_loadOrganizations());
    unawaited(_loadPsgcRegions());
  }

  void _onVerificationChanged() {
    if (!mounted) return;
    if (_verification.verified &&
        _emailController.text != _verification.verifiedEmail) {
      _emailController.text = _verification.verifiedEmail;
    }
    setState(() {
      if (_verification.verified && !_wasVerified) _step = 1;
      if (!_verification.verified && _wasVerified) {
        _step = 0;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_verification.verified) {
            _emailVerificationFocus.requestFocus();
          }
        });
        _passwordController.clear();
        _passwordConfirmationController.clear();
      }
      _wasVerified = _verification.verified;
    });
  }

  @override
  void dispose() {
    widget.authController.removeListener(_onDraftChanged);
    _cancelUpload?.call();
    _fieldNavigation.dispose();
    _emailVerificationFocus.dispose();
    for (final controller in _stepScrolls) {
      controller.dispose();
    }
    for (final controller in _textControllers) {
      controller.removeListener(_onDraftChanged);
      controller.dispose();
    }
    _verification.removeListener(_onVerificationChanged);
    _verification.dispose();
    super.dispose();
  }

  void _updateState(VoidCallback callback) {
    setState(callback);
  }

  @override
  Widget build(BuildContext context) {
    return UnsavedChangesGuard(
      key: _leaveGuardKey,
      hasUnsavedChanges: _hasUnsavedChanges,
      isBusy: _isSubmitting || _isPickingEvidence,
      onLeave: widget.onSignIn,
      onBack: _step > 0 && _result == null ? _backRegistration : null,
      child: FocusTraversalGroup(child: _buildRegistrationForm(context)),
    );
  }
}
