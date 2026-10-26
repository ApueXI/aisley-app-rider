import 'package:flutter/material.dart';

import '../../auth/presentation/controllers/auth_controller.dart';
import '../../chat/presentation/controllers/chat_controller.dart';
import '../../pickup/domain/pickup_models.dart';
import '../../pickup/presentation/controllers/pickup_controller.dart';
import '../../pickup/presentation/pickup_screen.dart';
import '../../policy/presentation/controllers/policy_controller.dart';
import '../../policy/presentation/policy_screen.dart';
import 'controllers/delivery_controller.dart';
import 'delivery_screen.dart';

/// Reauthorizes an opaque task ID without relying on any loaded task list.
class FinalMileTaskEntryScreen extends StatefulWidget {
  const FinalMileTaskEntryScreen({
    required this.taskId,
    required this.authController,
    required this.pickupController,
    required this.deliveryController,
    this.policyController,
    this.chatController,
    this.onOpenBatches,
    super.key,
  });

  final String taskId;
  final AuthController authController;
  final PickupController pickupController;
  final DeliveryController deliveryController;
  final PolicyController? policyController;
  final ChatController? chatController;
  final Future<void> Function()? onOpenBatches;

  @override
  State<FinalMileTaskEntryScreen> createState() =>
      _FinalMileTaskEntryScreenState();
}

class _FinalMileTaskEntryScreenState extends State<FinalMileTaskEntryScreen> {
  late final PickupController _pickup;
  late final DeliveryController _delivery;
  bool _sessionEnded = false;

  @override
  void initState() {
    super.initState();
    _pickup = PickupController(
      pickupRepository: widget.pickupController.pickupRepository,
      onAuthFailure: widget.pickupController.onAuthFailure,
      targetFinalMileTaskId: widget.taskId,
    );
    _delivery = DeliveryController(
      deliveryRepository: widget.deliveryController.deliveryRepository,
      onAuthFailure: widget.deliveryController.onAuthFailure,
    );
    widget.authController.addListener(_handleAuthState);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh();
    });
  }

  void _handleAuthState() {
    if (widget.authController.status == AuthStatus.policyConsentRequired) {
      _pickup.clear();
      _pickup.finalMileStatus = PickupSectionStatus.consentRequired;
      _pickup.finalMileErrorMessage =
          'Review the current policies before opening delivery work.';
      _delivery.clear();
      return;
    }
    if (widget.authController.status == AuthStatus.authenticated ||
        widget.authController.status == AuthStatus.policyConsentRequired) {
      return;
    }
    _sessionEnded = true;
    _pickup.clear();
    _delivery.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    });
  }

  Future<void> _refresh() async {
    if (_sessionEnded ||
        _delivery.tasks.any(_delivery.isActionBusy) ||
        !_pickup.canRetryRateLimit ||
        !_delivery.canRetryRateLimit) {
      return;
    }
    _delivery.invalidateDetails();
    await _pickup.load();
    if (!mounted || _sessionEnded) return;
    _delivery.tasks = List<PickupTask>.unmodifiable(_pickup.finalMileTasks);
  }

  Future<void> _reviewBatches() async {
    await widget.onOpenBatches?.call();
    if (mounted) await _refresh();
  }

  Future<void> _openPolicies() async {
    final policy = widget.policyController;
    if (policy == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PolicyScreen(
          authController: widget.authController,
          policyController: policy,
        ),
      ),
    );
    if (mounted) await _refresh();
  }

  @override
  void dispose() {
    widget.authController.removeListener(_handleAuthState);
    _pickup.dispose();
    _delivery.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pickup, _delivery]),
      builder: (context, _) {
        if (_sessionEnded) return const SizedBox.shrink();
        final status = _pickup.finalMileStatus;
        final task = _pickup.finalMileTasks.firstOrNull;
        if (status != PickupSectionStatus.loaded || task == null) {
          return _stateView(
            loading:
                status == PickupSectionStatus.loading ||
                status == PickupSectionStatus.idle,
            message: _pickup.finalMileErrorMessage ?? 'The related work is no longer available. The notification remains readable in your inbox.',
            consent: status == PickupSectionStatus.consentRequired,
          );
        }
        if (task.status == PickupTaskStatus.deliveryAssigned) {
          return PickupTaskDetailScreen(
            key: ValueKey('pickup:${task.id}:${task.rawStatus}'),
            authController: widget.authController,
            pickupController: _pickup,
            task: task,
            policyController: widget.policyController,
            chatController: widget.chatController,
            onOpenBatches: widget.onOpenBatches == null ? null : _reviewBatches,
            onRefresh: _refresh,
          );
        }
        if (task.canSubmitDelivery) {
          final contextStatus = _delivery.contextStatuses[task.id];
          if (contextStatus != null &&
              contextStatus != DeliveryLoadStatus.loaded &&
              contextStatus != DeliveryLoadStatus.loading) {
            return _stateView(
              message:
                  _delivery.contextErrors[task.id] ??
                  'The related work is unavailable. Refresh before continuing.',
              consent: contextStatus == DeliveryLoadStatus.consentRequired,
            );
          }
          return DeliveryTaskScreen(
            key: ValueKey('delivery:${task.id}:${task.rawStatus}'),
            authController: widget.authController,
            deliveryController: _delivery,
            task: task,
            policyController: widget.policyController,
            chatController: widget.chatController,
            onRefresh: _refresh,
          );
        }
        return _stateView(
          message: switch (task.status) {
            PickupTaskStatus.delivered => 'This task is delivered. The notification remains readable in your inbox.',
            PickupTaskStatus.rejected =>
              'This offer is rejected. Refresh to check for a current offer.',
            _ => 'No current action is available for this task. The notification remains readable in your inbox.',
          },
        );
      },
    );
  }

  Widget _stateView({
    required String message,
    bool loading = false,
    bool consent = false,
  }) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delivery work')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (loading)
              Semantics(
                liveRegion: true,
                label: 'Loading related work',
                child: const Center(child: CircularProgressIndicator()),
              )
            else ...[
              Text(message),
              const SizedBox(height: 16),
              if (consent && widget.policyController != null)
                FilledButton.icon(
                  onPressed: _openPolicies,
                  icon: const Icon(Icons.policy_outlined),
                  label: const Text('Review policies'),
                )
              else
                OutlinedButton.icon(
                  onPressed:
                      _pickup.canRetryRateLimit && _delivery.canRetryRateLimit
                      ? _refresh
                      : null,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
