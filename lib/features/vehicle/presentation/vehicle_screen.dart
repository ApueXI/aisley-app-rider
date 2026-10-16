import '../../../shared/presentation/unsaved_changes_guard.dart';
import '../../../shared/presentation/private_image_screen.dart';

import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../auth/presentation/controllers/auth_controller.dart';
import '../domain/vehicle_models.dart';
import 'controllers/vehicle_controller.dart';

part 'components/vehicle_actions.dart';
part 'components/vehicle_details.dart';
part 'components/vehicle_documents.dart';
part 'components/vehicle_widgets.dart';

const _maxVehicleDocumentBytes = 10 * 1024 * 1024;
const _vehicleDocumentTypeGroup = XTypeGroup(
  label: 'Vehicle documents',
  extensions: <String>['jpg', 'jpeg', 'png', 'webp'],
);

class VehicleScreen extends StatefulWidget {
  const VehicleScreen({
    required this.authController,
    required this.vehicleController,
    super.key,
  });

  final AuthController authController;
  final VehicleController vehicleController;

  @override
  State<VehicleScreen> createState() => _VehicleScreenState();
}

class _VehicleScreenState extends State<VehicleScreen> {
  final _leaveGuard = GlobalKey<UnsavedChangesGuardState>();
  final _formKey = GlobalKey<FormState>();
  final _plateController = TextEditingController();
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final Map<VehicleDocumentKind, VehicleDocumentSelection?> _pendingDocuments =
      <VehicleDocumentKind, VehicleDocumentSelection?>{};
  final Map<VehicleDocumentKind, String?> _selectionErrors =
      <VehicleDocumentKind, String?>{};
  final Map<VehicleDocumentKind, bool> _isPicking =
      <VehicleDocumentKind, bool>{};
  final Map<VehicleDocumentKind, VoidCallback?> _cancelUploads =
      <VehicleDocumentKind, VoidCallback?>{};

  String _vehicleType = 'motorcycle';
  bool _hasPopulatedVehicle = false;

  VehicleController get _vehicleController => widget.vehicleController;

  AuthController get _authController => widget.authController;

  BuildContext get _vehicleContext => context;

  bool get _vehicleMounted => mounted;

  void _vehicleSetState(VoidCallback callback) => setState(callback);

  @override
  void initState() {
    super.initState();
    widget.authController.addListener(_sessionChanged);
    for (final controller in [
      _plateController,
      _makeController,
      _modelController,
    ]) {
      controller.addListener(_draftChanged);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadVehicle();
      }
    });
  }

  void _draftChanged() {
    if (mounted) setState(() {});
  }

  void _sessionChanged() {
    if (widget.authController.status == AuthStatus.authenticated) return;
    for (final cancel in _cancelUploads.values) {
      cancel?.call();
    }
    _pendingDocuments.clear();
    _selectionErrors.clear();
    _plateController.clear();
    _makeController.clear();
    _modelController.clear();
    _leaveGuard.currentState?.leaveWithoutConfirmation();
  }

  @override
  void dispose() {
    widget.authController.removeListener(_sessionChanged);
    for (final cancel in _cancelUploads.values) {
      cancel?.call();
    }
    _pendingDocuments.clear();
    widget.vehicleController.clearDocumentPreviews();
    _plateController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.vehicleController,
      builder: (context, child) {
        final vehicle = widget.vehicleController.vehicle;
        return UnsavedChangesGuard(
          key: _leaveGuard,
          hasUnsavedChanges:
              _hasLocalVehicleEdits() ||
              _pendingDocuments.values.any((value) => value != null),
          isBusy:
              widget.vehicleController.isBusy ||
              _isPicking.values.any((value) => value),
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back),
                onPressed: () => _leaveGuard.currentState?.requestLeave(),
              ),
              title: const Text('Vehicle management'),
            ),
            body: vehicle == null
                ? _buildVehicleState(context)
                : RefreshIndicator(
                    onRefresh: _refreshVehicle,
                    child: _buildVehicleForm(context, vehicle),
                  ),
          ),
        );
      },
    );
  }
}
