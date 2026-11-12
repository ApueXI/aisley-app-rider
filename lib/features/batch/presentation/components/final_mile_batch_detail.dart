part of '../final_mile_batch_screen.dart';

class FinalMileBatchDetailScreen extends StatefulWidget {
  const FinalMileBatchDetailScreen({
    required this.authController,
    required this.batchController,
    required this.scheduleId,
    this.policyController,
    this.chatController,
    super.key,
  });

  final AuthController authController;
  final FinalMileBatchController batchController;
  final String scheduleId;
  final PolicyController? policyController;
  final ChatController? chatController;

  @override
  State<FinalMileBatchDetailScreen> createState() =>
      _FinalMileBatchDetailScreenState();
}

class _FinalMileBatchDetailScreenState
    extends State<FinalMileBatchDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.batchController.loadDetail(widget.scheduleId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.batchController,
      builder: (context, child) {
        final controller = widget.batchController;
        final batch = controller.batchById(widget.scheduleId);
        final detailStatus = controller.detailStatus(widget.scheduleId);
        if (batch == null &&
            (detailStatus == FinalMileBatchLoadStatus.idle ||
                detailStatus == FinalMileBatchLoadStatus.loading)) {
          return Scaffold(
            appBar: AppBar(title: const Text('Final-mile batches')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (batch == null ||
            detailStatus == FinalMileBatchLoadStatus.unavailable ||
            detailStatus == FinalMileBatchLoadStatus.forbidden ||
            detailStatus == FinalMileBatchLoadStatus.unauthorized) {
          return Scaffold(
            appBar: AppBar(title: const Text('Final-mile batches')),
            body: _BatchErrorState(
              message:
                  controller.detailError(widget.scheduleId) ??
                  'This dispatch batch is unavailable.',
              status: detailStatus,
              onRetry: () => controller.loadDetail(widget.scheduleId),
              onOpenPolicies: _openPolicies,
              canOpenPolicies: widget.policyController != null,
            ),
          );
        }

        return PopScope(
          canPop:
              controller.decidingTask == null &&
              !controller.hasUncertainDecision,
          child: Scaffold(
            appBar: AppBar(title: const Text('Final-mile batches')),
            body: RefreshIndicator(
              onRefresh: () => controller.loadDetail(widget.scheduleId),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _BatchSummary(batch: batch),
                  if (_isBatchBlocking(detailStatus) &&
                      controller.detailError(widget.scheduleId) != null) ...[
                    const SizedBox(height: 12),
                    _BatchInlineError(
                      message: controller.detailError(widget.scheduleId)!,
                      onRetry: () => controller.loadDetail(widget.scheduleId),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'Parcels in batch',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_acceptedParcelCount(batch)} accepted · ${_offeredParcelCount(batch)} offered',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (var index = 0; index < batch.tasks.length; index++) ...[
                    _ParcelDecisionCard(
                      task: batch.tasks[index],
                      batch: batch,
                      controller: controller,
                      onOpenParcel: () => _openParcel(batch.tasks[index]),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
            bottomNavigationBar: _routeFooter(batch, controller),
          ),
        );
      },
    );
  }

  Widget? _routeFooter(
    FinalMileBatch batch,
    FinalMileBatchController controller,
  ) {
    final routeController = controller.routeController;
    if (!batch.hasAcceptedTasks || routeController == null) return null;
    final acceptedCount = _routeParcelCount(batch);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => DeliveryRouteScreen(
                      batch: batch,
                      controller: routeController,
                      onOpenPolicies: widget.policyController == null
                          ? null
                          : _openPolicies,
                    ),
                  ),
                ),
                icon: const Icon(Icons.alt_route_outlined),
                label: const Text('View delivery route'),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Route includes accepted deliveries only '
              '($acceptedCount ${acceptedCount == 1 ? 'parcel' : 'parcels'}).',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openParcel(FinalMileBatchTask task) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FinalMileOfferedTaskScreen(
          authController: widget.authController,
          batchController: widget.batchController,
          scheduleId: widget.scheduleId,
          taskId: task.id,
          policyController: widget.policyController,
          chatController: widget.chatController,
        ),
      ),
    );
  }

  Future<void> _openPolicies() async {
    final policies = widget.policyController;
    if (policies == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PolicyScreen(
          authController: widget.authController,
          policyController: policies,
        ),
      ),
    );
    if (mounted) {
      await widget.batchController.loadDetail(widget.scheduleId);
    }
  }
}

class _BatchSummary extends StatelessWidget {
  const _BatchSummary({required this.batch});

  final FinalMileBatch batch;

  @override
  Widget build(BuildContext context) {
    final areas = batch.tasks
        .map((task) => task.destination.summary)
        .where((area) => area != 'Destination area unavailable')
        .toSet()
        .toList(growable: false);
    final areaSummary = areas.isEmpty
        ? 'Destination area unavailable'
        : areas.take(2).join(' · ');
    return CourierSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Schedule reference',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                batch.reference,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              _BatchStatusChip(status: batch.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${batch.parcelCount} ${batch.parcelCount == 1 ? 'parcel' : 'parcels'} assigned',
          ),
          const Divider(height: 28),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.location_on_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(areaSummary)),
            ],
          ),
          const SizedBox(height: 8),
          Text('Scheduled ${_formatBatchSchedule(batch.scheduledFor)}'),
        ],
      ),
    );
  }
}

class _BatchParcelCard extends StatelessWidget {
  const _BatchParcelCard({required this.task});

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
                reference,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              CourierStatusBadge(
                label: _parcelStatusLabel(task.status),
                tone: _parcelStatusTone(task.status),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Area',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(task.destination.summary, textAlign: TextAlign.end),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _parcelStatusLabel(String status) => switch (status) {
  'delivery_assigned' => 'Delivery offered',
  'delivery_accepted' => 'Delivery accepted',
  'picked_up_from_hub' => 'Picked up from hub',
  'in_transit' => 'In transit',
  'out_for_delivery' => 'Out for delivery',
  'delivered' => 'Delivered',
  'rejected' => 'Rejected',
  'cancelled' => 'Cancelled',
  _ => 'Status unavailable',
};

CourierStatusTone _parcelStatusTone(String status) => switch (status) {
  'delivered' ||
  'delivery_accepted' ||
  'picked_up_from_hub' => CourierStatusTone.success,
  'rejected' || 'cancelled' => CourierStatusTone.critical,
  'in_transit' || 'out_for_delivery' => CourierStatusTone.info,
  _ => CourierStatusTone.neutral,
};

int _acceptedParcelCount(FinalMileBatch batch) =>
    batch.tasks.where((task) => task.status != 'delivery_assigned').length;

int _offeredParcelCount(FinalMileBatch batch) =>
    batch.tasks.where((task) => task.status == 'delivery_assigned').length;

int _routeParcelCount(FinalMileBatch batch) => batch.tasks
    .where(
      (task) => const {
        'delivery_accepted',
        'picked_up_from_hub',
        'in_transit',
        'out_for_delivery',
      }.contains(task.status),
    )
    .length;
