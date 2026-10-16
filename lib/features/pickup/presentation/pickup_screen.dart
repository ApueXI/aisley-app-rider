import '../../../shared/presentation/task_row.dart';
import '../../../shared/presentation/destination_scope.dart';

import 'package:flutter/material.dart';

import '../../../core/networking/api_client.dart';

import '../../../core/scanning/barcode_scan_candidate.dart';
import '../../../core/scanning/barcode_scanner_screen.dart';
import '../../../shared/route_map/route_map_data.dart';
import '../../../shared/route_map/route_map_view.dart';
import '../../../shared/route_map/route_session_boundary.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../chat/presentation/controllers/chat_controller.dart';
import '../../chat/presentation/chat_thread_screen.dart';
import '../../policy/presentation/controllers/policy_controller.dart';
import '../../policy/presentation/policy_screen.dart';
import '../domain/pickup_models.dart';
import 'components/pickup_schedule_filter.dart';
import 'controllers/pickup_controller.dart';

part 'components/pickup_list.dart';
part 'components/pickup_task_detail.dart';
part 'components/pickup_task_actions.dart';
part 'components/pickup_hub_handoff.dart';
part 'components/pickup_task_interactions.dart';
part 'components/pickup_task_info.dart';
part 'components/pickup_route.dart';
part 'components/pickup_status.dart';

class PickupScreen extends StatefulWidget {
  const PickupScreen({
    required this.authController,
    required this.pickupController,
    this.policyController,
    this.onOpenDelivery,
    this.onOpenBatches,
    this.chatController,
    this.scheduleId,
    super.key,
  });

  final AuthController authController;
  final PickupController pickupController;
  final PolicyController? policyController;
  final VoidCallback? onOpenDelivery;
  final VoidCallback? onOpenBatches;
  final ChatController? chatController;
  final String? scheduleId;

  @override
  State<PickupScreen> createState() => _PickupScreenState();
}

class _PickupScreenState extends State<PickupScreen> {
  late final PickupController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.scheduleId == null
        ? widget.pickupController
        : PickupController(
            pickupRepository: widget.pickupController.pickupRepository,
            onAuthFailure: widget.pickupController.onAuthFailure,
            targetScheduleId: widget.scheduleId,
          );
    widget.authController.addListener(_handleAuthState);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.load();
      }
    });
  }

  void _handleAuthState() {
    if (widget.scheduleId != null &&
        widget.authController.status == AuthStatus.policyConsentRequired) {
      _controller.clear();
      _controller.firstMileStatus = PickupSectionStatus.consentRequired;
      _controller.firstMileErrorMessage =
          'Review the current policies before opening pickup work.';
      return;
    }
    if (widget.scheduleId == null ||
        widget.authController.status == AuthStatus.authenticated ||
        widget.authController.status == AuthStatus.policyConsentRequired) {
      return;
    }
    _controller.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    });
  }

  @override
  void dispose() {
    widget.authController.removeListener(_handleAuthState);
    if (widget.scheduleId != null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            leading: destinationBackButton(context),
            title: const Text('Pickup orders'),
          ),
          body: RefreshIndicator(
            onRefresh: _controller.load,
            child: _PickupListBody(
              authController: widget.authController,
              pickupController: _controller,
              policyController: widget.policyController,
              onOpenTask: _openTask,
              onOpenRoute: _openRoute,
              onOpenPolicies: _openPolicies,
            ),
          ),
        );
      },
    );
  }

  Future<void> _openTask(PickupTask task) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PickupTaskDetailScreen(
          authController: widget.authController,
          pickupController: _controller,
          policyController: widget.policyController,
          task: task,
          onOpenDelivery: widget.onOpenDelivery,
          onOpenBatches: widget.onOpenBatches,
          chatController: widget.chatController,
        ),
      ),
    );
  }

  Future<void> _openRoute(PickupTask task) async {
    final scheduleId = task.pickupScheduleId ?? task.schedule?.id;
    if (scheduleId == null || scheduleId.isEmpty) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PickupRouteScreen(
          pickupController: _controller,
          scheduleId: scheduleId,
          schedule: task.schedule,
          onOpenPolicies: _openPolicies,
        ),
      ),
    );
  }

  Future<void> _openPolicies() async {
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
    if (mounted) {
      await _controller.load();
    }
  }
}
