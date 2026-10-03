import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../auth/domain/auth_models.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../../shared/presentation/form_field_navigation.dart';
import '../../../shared/presentation/unsaved_changes_guard.dart';
import '../../policy/presentation/controllers/policy_controller.dart';
import '../../policy/presentation/policy_screen.dart';
import '../domain/account_models.dart';
import '../../vehicle/presentation/controllers/vehicle_controller.dart';
import '../../vehicle/presentation/vehicle_screen.dart';
import 'controllers/account_controller.dart';

part 'components/account_screen_account.dart';
part 'components/account_screen_content.dart';
part 'components/account_screen_profile_photo.dart';
part 'components/account_screen_profile_photo_view.dart';
part 'components/account_screen_security.dart';
part 'components/account_screen_widgets.dart';
part 'components/account_screen_interaction.dart';

const _maxProfilePhotoBytes = 10 * 1024 * 1024;
const _profilePhotoTypeGroup = XTypeGroup(
  label: 'Profile photos',
  extensions: <String>['jpg', 'jpeg', 'png', 'webp'],
);

class AccountScreen extends StatefulWidget {
  const AccountScreen({
    required this.authController,
    required this.accountController,
    this.policyController,
    this.vehicleController,
    super.key,
  });

  final AuthController authController;
  final AccountController accountController;
  final PolicyController? policyController;
  final VehicleController? vehicleController;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _profileFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  final _leaveGuardKey = GlobalKey<UnsavedChangesGuardState>();
  final _fieldNavigation = FormFieldNavigation();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _passwordConfirmationController = TextEditingController();
  bool _hasPopulatedProfile = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscurePasswordConfirmation = true;
  ProfilePhotoSelection? _pendingProfilePhoto;
  String? _profilePhotoSelectionError;
  bool _isPickingProfilePhoto = false;
  VoidCallback? _cancelProfilePhotoUpload;
  bool _isClosingForSession = false;
  String? _sessionCourierId;

  @override
  void initState() {
    super.initState();
    _sessionCourierId = widget.authController.courier?.id;
    widget.authController.addListener(_onAccountScopeChanged);
    widget.accountController.addListener(_onAccountScopeChanged);
    for (final controller in _textControllers) {
      controller.addListener(_onDraftChanged);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadAccount();
      }
    });
  }

  @override
  void dispose() {
    widget.authController.removeListener(_onAccountScopeChanged);
    widget.accountController.removeListener(_onAccountScopeChanged);
    _cancelProfilePhotoUpload?.call();
    _fieldNavigation.dispose();
    for (final controller in _textControllers) {
      controller.removeListener(_onDraftChanged);
      controller.dispose();
    }
    super.dispose();
  }

  void _updateState(VoidCallback callback) {
    setState(callback);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.accountController,
      builder: (context, child) {
        final account = widget.accountController.account;
        return UnsavedChangesGuard(
          key: _leaveGuardKey,
          hasUnsavedChanges: _hasUnsavedChanges,
          isBusy: _hasPendingAccountMutation,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Account'),
              leading: Navigator.of(context).canPop()
                  ? IconButton(
                      tooltip: 'Back',
                      onPressed: _hasPendingAccountMutation
                          ? null
                          : () => _leaveGuardKey.currentState?.requestLeave(),
                      icon: const Icon(Icons.arrow_back),
                    )
                  : null,
            ),
            body: account == null
                ? _buildAccountState(context)
                : RefreshIndicator(
                    onRefresh: _refreshAccount,
                    child: _buildAccountForm(context, account),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildAccountState(BuildContext context) {
    final controller = widget.accountController;
    if (controller.status == AccountStatus.loading) {
      return Center(
        child: Semantics(
          liveRegion: true,
          label: 'Loading your account',
          child: const CircularProgressIndicator(),
        ),
      );
    }

    final message =
        controller.errorMessage ??
        'Your account details are not available right now.';
    final canRetry =
        controller.status != AccountStatus.signedOut &&
        controller.status != AccountStatus.forbidden;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                controller.status == AccountStatus.forbidden
                    ? Icons.lock_outline
                    : Icons.account_circle_outlined,
                size: 52,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (canRetry) ...[
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: controller.isBusy ? null : _loadAccount,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openPolicy() async {
    final policyController = widget.policyController;
    if (policyController == null || !mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PolicyScreen(
          authController: widget.authController,
          policyController: policyController,
        ),
      ),
    );
  }

  Future<void> _openVehicle() async {
    final vehicleController = widget.vehicleController;
    if (vehicleController == null || !mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VehicleScreen(
          authController: widget.authController,
          vehicleController: vehicleController,
        ),
      ),
    );
  }
}
