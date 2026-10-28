part of '../pickup_screen.dart';

class PickupTaskDetailScreen extends StatefulWidget {
  const PickupTaskDetailScreen({
    required this.authController,
    required this.pickupController,
    required this.task,
    this.policyController,
    this.onOpenDelivery,
    this.onOpenBatches,
    this.chatController,
    this.onRefresh,
    super.key,
  });

  final AuthController authController;
  final PickupController pickupController;
  final PickupTask task;
  final PolicyController? policyController;
  final VoidCallback? onOpenDelivery;
  final VoidCallback? onOpenBatches;
  final ChatController? chatController;
  final Future<void> Function()? onRefresh;

  @override
  State<PickupTaskDetailScreen> createState() => _PickupTaskDetailScreenState();
}

class _PickupTaskDetailScreenState extends State<PickupTaskDetailScreen> {
  BarcodeScanCandidate? _scanCandidate;
  bool? _resolvedForThisTask;
  String? _resolutionMessage;

  PickupController get _pickupController => widget.pickupController;

  AuthController get _authController => widget.authController;

  PolicyController? get _policyController => widget.policyController;

  VoidCallback? get _onOpenDelivery => widget.onOpenDelivery;

  VoidCallback? get _onOpenBatches => widget.onOpenBatches;

  BuildContext get _pickupContext => context;

  bool get _pickupMounted => mounted;

  void _pickupSetState(VoidCallback callback) => setState(callback);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.pickupController,
      builder: (context, child) {
        final task = widget.pickupController.taskWithId(widget.task);
        final scoped = widget.pickupController.isTargeted;
        final tasks = task.isFirstMile
            ? widget.pickupController.firstMileTasks
            : widget.pickupController.finalMileTasks;
        final status = task.isFirstMile
            ? widget.pickupController.firstMileStatus
            : widget.pickupController.finalMileStatus;
        if (scoped &&
            (status != PickupSectionStatus.loaded ||
                !tasks.any((current) => current.id == task.id))) {
          return Scaffold(
            appBar: AppBar(title: const Text('Pickup order')),
            body: RefreshIndicator(
              onRefresh: widget.onRefresh ?? widget.pickupController.load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  if (status == PickupSectionStatus.loading)
                    const _PickupLoadingState()
                  else
                    _PickupErrorState(
                      message:
                          (task.isFirstMile
                              ? widget.pickupController.firstMileErrorMessage
                              : widget
                                    .pickupController
                                    .finalMileErrorMessage) ??
                          'The related work is no longer available. Return to the notification for its history.',
                      status: status,
                      onRetry: widget.pickupController.load,
                      onOpenPolicies: _openPolicies,
                      showPolicyAction: widget.policyController != null,
                    ),
                ],
              ),
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Pickup order')),
          body: RefreshIndicator(
            onRefresh: widget.onRefresh ?? widget.pickupController.load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _TaskIdentity(task: task),
                const SizedBox(height: 16),
                _TaskDetails(task: task),
                const SizedBox(height: 16),
                _buildAction(context, task),
                const SizedBox(height: 16),
                if (widget.chatController != null &&
                    (task.isAssigned ||
                        task.isAccepted ||
                        (task.isFinalMile &&
                            (task.status == PickupTaskStatus.pickedUpFromHub ||
                                task.status == PickupTaskStatus.inTransit ||
                                task.status ==
                                    PickupTaskStatus.outForDelivery)))) ...[
                  OutlinedButton.icon(
                    onPressed: () => _openLogisticsChat(task),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Message Logistics'),
                  ),
                  const SizedBox(height: 16),
                ],
                if (widget.chatController != null &&
                    task.isFirstMile &&
                    task.status == PickupTaskStatus.accepted) ...[
                  OutlinedButton.icon(
                    onPressed: () => _openSellerChat(task),
                    icon: const Icon(Icons.storefront_outlined),
                    label: const Text('Message Seller'),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openLogisticsChat(PickupTask task) async {
    await _openChat(task, 'logistics');
  }

  Future<void> _openSellerChat(PickupTask task) async {
    await _openChat(task, 'seller');
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
            leg: task.isFirstMile ? 'first_mile' : 'final_mile',
            taskId: task.id,
            counterpartyRole: counterpartyRole,
            reference: task.order?.reference,
          ),
        ),
      ),
    );
  }

  Widget _buildAction(BuildContext context, PickupTask task) {
    if (task.isFinalMile && task.status == PickupTaskStatus.rejected) {
      return _buildRejected(context, task);
    }
    if (task.hasBeenPickedUp) {
      return _CompletedPickup(
        task: task,
        controller: _pickupController,
        onOpenDelivery: _onOpenDelivery,
      );
    }
    if (task.isAssigned) {
      return _buildAcceptance(context, task);
    }
    if (task.isAccepted) {
      if (task.isFinalMile) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'This parcel is accepted. Open Delivery work to submit photo proof and Delivered confirmation.',
            ),
            if (_onOpenDelivery != null)
              FilledButton(
                onPressed: _onOpenDelivery,
                child: const Text('Open Delivery work'),
              ),
            const Text(
              'Hub handoff below is optional; delivery submission does not require it.',
            ),
            _buildHubHandoff(context, task),
          ],
        );
      }
      return _buildVerification(context, task);
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(
          'This task is not currently eligible for a pickup action. Refresh to see the server-authoritative state.',
        ),
      ),
    );
  }
}
