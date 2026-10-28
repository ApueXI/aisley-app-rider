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
    initializeCashAcknowledgment();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.deliveryController.loadDetails(widget.task);
      }
    });
  }

  @override
  void dispose() {
    widget.authController.removeListener(_handleAuthState);
    disposeCashAcknowledgment();
    widget.deliveryController.clearProofPhotosForTask(
      widget.task.id,
      notify: false,
    );
    _selectedPhoto = null;
    super.dispose();
  }

  @override
  void didUpdateWidget(DeliveryTaskScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deliveryController != widget.deliveryController) {
      replaceCashAcknowledgmentController(oldWidget.deliveryController);
    }
    updateCashAcknowledgmentTask(oldWidget.task.id, widget.task.id);
  }

  void _handleAuthState() {
    if (widget.authController.status == AuthStatus.authenticated) return;
    if (widget.onRefresh != null &&
        widget.authController.status == AuthStatus.policyConsentRequired) {
      return;
    }
    clearCashAcknowledgment();
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
        final reviewPending = controller.isCompletionPending(task);
        final codCollection = deliveryContext?.codCollection;
        final isCod = deliveryContext?.paymentMethod == 'cod';
        final cashAcknowledged = cashAcknowledgmentMatches(
          task,
          deliveryContext,
        );
        final paymentReady =
            paymentIsKnown(deliveryContext) && (!isCod || cashAcknowledged);
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
              title: Text(reviewPending ? 'Delivery review' : 'Deliver order'),
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
                    codCollection: codCollection,
                    cashAcknowledged: cashAcknowledged,
                    canAcknowledgeCash:
                        !reviewPending && !controller.isActionBusy(task),
                    onCashAcknowledged: (value) {
                      if (codCollection != null) {
                        setCashAcknowledgement(task, codCollection, value);
                      }
                    },
                    isReviewPending: reviewPending,
                  ),
                  const SizedBox(height: 16),
                  _buildAction(
                    context,
                    task,
                    deliveryContext,
                    paymentReady: paymentReady,
                    onBackToWork: () =>
                        _leaveGuard.currentState?.requestLeave(),
                  ),
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
                  if (task.isFinalMile &&
                      task.canSubmitDelivery &&
                      !reviewPending) ...[
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
    DeliveryContext? deliveryContext, {
    required bool paymentReady,
    required VoidCallback onBackToWork,
  }) {
    if (task.status == PickupTaskStatus.delivered) {
      return _CompletedDeliveryCard();
    }
    if (widget.deliveryController.isCompletionPending(task)) {
      return _DeliveryPendingReviewCard(
        task: task,
        controller: widget.deliveryController,
        contextData: deliveryContext,
        canRefresh:
            !widget.deliveryController.isActionBusy(task) &&
            widget.deliveryController.canRetryRateLimit &&
            widget.deliveryController.completionStatuses[task.id] !=
                DeliveryLoadStatus.loading,
        onRefresh: () => widget.deliveryController.loadCompletion(task),
        onBackToWork: onBackToWork,
      );
    }
    if (widget.onRefresh != null &&
        widget.deliveryController.contextStatuses[task.id] !=
            DeliveryLoadStatus.loaded) {
      return const Text('Refresh delivery details before continuing.');
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
        paymentReady: paymentReady,
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
