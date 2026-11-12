part of '../final_mile_batch_screen.dart';

class FinalMileOfferedTaskScreen extends StatefulWidget {
  const FinalMileOfferedTaskScreen({
    required this.authController,
    required this.batchController,
    required this.scheduleId,
    required this.taskId,
    this.policyController,
    this.chatController,
    super.key,
  });

  final AuthController authController;
  final FinalMileBatchController batchController;
  final String scheduleId;
  final String taskId;
  final PolicyController? policyController;
  final ChatController? chatController;

  @override
  State<FinalMileOfferedTaskScreen> createState() =>
      _FinalMileOfferedTaskScreenState();
}

class _FinalMileOfferedTaskScreenState
    extends State<FinalMileOfferedTaskScreen> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.batchController,
      builder: (context, child) {
        final controller = widget.batchController;
        final batch = controller.batchById(widget.scheduleId);
        final task = batch?.tasks
            .where((candidate) => candidate.id == widget.taskId)
            .firstOrNull;
        final status = controller.detailStatus(widget.scheduleId);

        if (task == null &&
            (status == FinalMileBatchLoadStatus.idle ||
                status == FinalMileBatchLoadStatus.loading)) {
          return Scaffold(
            appBar: AppBar(
              leading: _backButton(context),
              title: const Text('Task details'),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (task == null ||
            status == FinalMileBatchLoadStatus.unavailable ||
            status == FinalMileBatchLoadStatus.forbidden ||
            status == FinalMileBatchLoadStatus.unauthorized) {
          return Scaffold(
            appBar: AppBar(
              leading: _backButton(context),
              title: const Text('Task details'),
            ),
            body: _offerUnavailableState(controller, status),
          );
        }

        final isOffered = task.status == 'delivery_assigned';
        final pending = controller.hasPendingDecision(task.id);
        final freshRead = status == FinalMileBatchLoadStatus.loaded;
        final actionBlocked =
            !freshRead ||
            controller.decidingTask != null ||
            !controller.canRetryRateLimit ||
            controller.hasUncertainDecision;

        return PopScope(
          canPop:
              controller.decidingTask == null &&
              !controller.hasUncertainDecision,
          child: Scaffold(
            appBar: AppBar(
              leading: _backButton(context),
              title: const Text('Task details'),
            ),
            body: RefreshIndicator(
              onRefresh: () => controller.loadDetail(widget.scheduleId),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  _OfferedTaskIdentity(task: task),
                  const SizedBox(height: 16),
                  _OfferedTaskContext(task: task),
                  if (controller.parcelErrors[task.id] case final error?) ...[
                    const SizedBox(height: 12),
                    _OfferMessageCard(message: error, isError: true),
                  ],
                  if (!freshRead)
                    if (controller.detailError(widget.scheduleId)
                        case final error?) ...[
                      const SizedBox(height: 12),
                      _OfferMessageCard(
                        message: error,
                        isError: true,
                        onRetry: controller.canRetryRateLimit
                            ? () => controller.loadDetail(widget.scheduleId)
                            : null,
                      ),
                    ],
                  if (!isOffered) ...[
                    const SizedBox(height: 12),
                    _OfferMessageCard(message: _taskStateMessage(task.status)),
                  ],
                ],
              ),
            ),
            bottomNavigationBar: isOffered
                ? _OfferedTaskActions(
                    task: task,
                    controller: controller,
                    scheduleId: widget.scheduleId,
                    chatController: widget.chatController,
                    authController: widget.authController,
                    enabled: !actionBlocked,
                    pending: pending,
                    onDecisionComplete: _closeAfterDecision,
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _backButton(BuildContext context) => IconButton(
    tooltip: 'Back',
    onPressed: () => Navigator.of(context).maybePop(),
    icon: const Icon(Icons.arrow_back),
  );

  Widget _offerUnavailableState(
    FinalMileBatchController controller,
    FinalMileBatchLoadStatus status,
  ) {
    final message =
        controller.detailError(widget.scheduleId) ??
        'This delivery offer is no longer available. Refresh the batch before continuing.';
    return RefreshIndicator(
      onRefresh: () => controller.loadDetail(widget.scheduleId),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 32),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          if (status != FinalMileBatchLoadStatus.unauthorized &&
              controller.canRetryRateLimit)
            Center(
              child: OutlinedButton.icon(
                onPressed: () => controller.loadDetail(widget.scheduleId),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh offer'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _closeAfterDecision() async {
    if (mounted) await Navigator.of(context).maybePop();
  }
}

class _OfferedTaskIdentity extends StatelessWidget {
  const _OfferedTaskIdentity({required this.task});

  final FinalMileBatchTask task;

  @override
  Widget build(BuildContext context) {
    final reference =
        task.orderReference ?? task.parcel.reference ?? 'Reference unavailable';
    return CourierSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Task reference',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              CourierStatusBadge(
                label: task.status == 'delivery_assigned'
                    ? 'Final mile · Delivery offered'
                    : 'Final mile · ${_parcelStatusLabel(task.status)}',
                tone: _parcelStatusTone(task.status),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            reference,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _OfferedTaskContext extends StatelessWidget {
  const _OfferedTaskContext({required this.task});

  final FinalMileBatchTask task;

  @override
  Widget build(BuildContext context) {
    return CourierSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OfferedTaskFact(
            icon: Icons.local_shipping_outlined,
            label: 'Leg',
            value: 'Final-mile delivery',
          ),
          const Divider(height: 24),
          _OfferedTaskFact(
            icon: Icons.home_work_outlined,
            label: 'Origin',
            value: 'Assigned Logistics hub',
          ),
          const Divider(height: 24),
          _OfferedTaskFact(
            icon: Icons.near_me_outlined,
            label: 'Destination area',
            value: '${task.destination.summary} · General area only',
          ),
          const Divider(height: 24),
          _OfferedTaskFact(
            icon: Icons.inventory_2_outlined,
            label: 'Parcel',
            value: '1 parcel · ${task.parcel.itemSummary}',
          ),
          const SizedBox(height: 16),
          Semantics(
            label: 'Buyer contact details and exact street address are shown after this delivery is accepted.',
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lock_outline,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Buyer contact details and exact street address will be shown after accepting this delivery.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferedTaskFact extends StatelessWidget {
  const _OfferedTaskFact({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(value),
            ],
          ),
        ),
      ],
    );
  }
}

class _OfferMessageCard extends StatelessWidget {
  const _OfferMessageCard({
    required this.message,
    this.isError = false,
    this.onRetry,
  });

  final String message;
  final bool isError;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return CourierSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            liveRegion: isError,
            child: Text(
              message,
              style: isError
                  ? TextStyle(color: Theme.of(context).colorScheme.error)
                  : null,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh batch'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
