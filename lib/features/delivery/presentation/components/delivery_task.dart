part of '../delivery_screen.dart';

class DeliveryTaskScreen extends StatefulWidget {
  const DeliveryTaskScreen({
    required this.authController,
    required this.deliveryController,
    required this.task,
    this.policyController,
    this.onOpenPickup,
    this.chatController,
    this.onRefresh,
    this.photoCaptureLauncher = const CameraDeliveryPhotoCaptureLauncher(),
    super.key,
  });

  final AuthController authController;
  final DeliveryController deliveryController;
  final PickupTask task;
  final PolicyController? policyController;
  final VoidCallback? onOpenPickup;
  final ChatController? chatController;
  final Future<void> Function()? onRefresh;
  final DeliveryPhotoCaptureLauncher photoCaptureLauncher;

  @override
  State<DeliveryTaskScreen> createState() => _DeliveryTaskScreenState();
}

class _DeliveryTaskScreenState extends State<DeliveryTaskScreen>
    with _DeliveryPhotoSelection {
  final _leaveGuard = GlobalKey<UnsavedChangesGuardState>();
  @override
  void initState() {
    super.initState();
    widget.authController.addListener(_handleAuthState);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.deliveryController.loadDetails(widget.task);
      }
    });
  }

  @override
  void dispose() {
    widget.authController.removeListener(_handleAuthState);
    widget.deliveryController.clearProofPhotosForTask(
      widget.task.id,
      notify: false,
    );
    _selectedPhoto = null;
    super.dispose();
  }

  void _handleAuthState() {
    if (widget.authController.status == AuthStatus.authenticated) return;
    if (widget.onRefresh != null &&
        widget.authController.status == AuthStatus.policyConsentRequired) {
      return;
    }
    _selectedPhoto = null;
    _photoSelectionError = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.deliveryController,
      builder: (context, child) {
        final controller = widget.deliveryController;
        final task = controller.taskById(widget.task.id) ?? widget.task;
        final deliveryContext = controller.contexts[task.id];
        return UnsavedChangesGuard(
          key: _leaveGuard,
          hasUnsavedChanges: _selectedPhoto != null,
          isBusy: _isPickingPhoto || controller.isActionBusy(task),
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back),
                onPressed: () => _leaveGuard.currentState?.requestLeave(),
              ),
              title: const Text('Deliver order'),
            ),
            body: RefreshIndicator(
              onRefresh: () async {
                if (controller.isActionBusy(task)) return;
                await (widget.onRefresh?.call() ??
                    controller.loadDetails(task));
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _DeliveryIdentity(task: task),
                  const SizedBox(height: 16),
                  _DeliveryContextCard(
                    contextData: deliveryContext,
                    status:
                        controller.contextStatuses[task.id] ??
                        DeliveryLoadStatus.idle,
                    error: controller.contextErrors[task.id],
                    onRetry:
                        widget.onRefresh ?? () => controller.loadDetails(task),
                  ),
                  const SizedBox(height: 16),
                  _buildAction(context, task, deliveryContext),
                  if (widget.chatController != null &&
                      task.isFinalMile &&
                      (task.status == PickupTaskStatus.deliveryAssigned ||
                          task.status == PickupTaskStatus.deliveryAccepted ||
                          task.status == PickupTaskStatus.pickedUpFromHub ||
                          task.status == PickupTaskStatus.inTransit ||
                          task.status == PickupTaskStatus.outForDelivery))
                    OutlinedButton.icon(
                      onPressed: () => _openChat(task, 'logistics'),
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Message Logistics'),
                    ),
                  if (widget.chatController != null &&
                      ChatTaskContext.canMessageBuyer(task))
                    OutlinedButton.icon(
                      onPressed: () => _openChat(task, 'customer'),
                      icon: const Icon(Icons.person_outline),
                      label: const Text('Message Buyer'),
                    ),
                  if (task.isFinalMile && task.canSubmitDelivery) ...[
                    const SizedBox(height: 16),
                    FailedDeliveryAttemptCard(
                      task: task,
                      controller: controller,
                      authController: widget.authController,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openChat(PickupTask task, String counterpartyRole) async {
    final controller = widget.chatController;
    if (controller == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatThreadScreen(
          controller: controller,
          authController: widget.authController,
          task: ChatTaskContext(
            leg: 'final_mile',
            taskId: task.id,
            counterpartyRole: counterpartyRole,
            reference: task.order?.reference,
          ),
        ),
      ),
    );
  }

  Widget _buildAction(
    BuildContext context,
    PickupTask task,
    DeliveryContext? deliveryContext,
  ) {
    if (widget.onRefresh != null &&
        widget.deliveryController.contextStatuses[task.id] !=
            DeliveryLoadStatus.loaded) {
      return const Text('Refresh delivery details before continuing.');
    }
    if (task.status == PickupTaskStatus.delivered) {
      return _CompletedDeliveryCard();
    }
    if (task.status == PickupTaskStatus.deliveryAssigned) {
      return const Text(
        'Review and accept this parcel from Final-mile batches first.',
      );
    }
    if (task.canSubmitDelivery) {
      return _ProofAndCompletionCard(
        task: task,
        controller: widget.deliveryController,
        selectedPhoto: _selectedPhoto,
        selectionError: _photoSelectionError,
        isPicking: _isPickingPhoto,
        canCancelUpload: _cancelPhotoUpload != null,
        onChoosePhoto: _pickPhoto,
        cameraSupported: widget.photoCaptureLauncher.isSupported,
        onCapturePhoto: _capturePhoto,
        onDiscardPhoto: () => setState(() {
          _selectedPhoto = null;
          _photoSelectionError = null;
        }),
        onSubmitPhoto: () => _confirmDelivered(task),
        onCancelUpload: () => _cancelPhotoUpload?.call(),
        onOpenPolicies: _openPolicies,
        showPolicyAction: widget.policyController != null,
      );
    }
    return const _DeliveryUnavailableActionCard();
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
      await (widget.onRefresh?.call() ??
          widget.deliveryController.loadDetails(widget.task));
    }
  }
}
