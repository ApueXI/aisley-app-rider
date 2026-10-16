part of '../pickup_screen.dart';

class _PickupListBody extends StatelessWidget {
  const _PickupListBody({
    required this.authController,
    required this.pickupController,
    required this.policyController,
    required this.onOpenTask,
    required this.onOpenRoute,
    required this.onOpenPolicies,
  });

  final AuthController authController;
  final PickupController pickupController;
  final PolicyController? policyController;
  final ValueChanged<PickupTask> onOpenTask;
  final ValueChanged<PickupTask> onOpenRoute;
  final VoidCallback onOpenPolicies;

  @override
  Widget build(BuildContext context) {
    final controller = pickupController;
    return ListView(
      key: const PageStorageKey('pickup-work'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(
          'Assigned pickup work',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Review the server assignment, accept it, then verify the waybill before confirming physical handoff.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        _PickupSection(
          title: 'Seller pickups',
          subtitle: 'First-mile work from a Seller to your Logistics hub.',
          icon: Icons.storefront_outlined,
          status: controller.firstMileStatus,
          errorMessage: controller.firstMileErrorMessage,
          tasks: controller.firstMileTasks,
          page: controller.firstMilePage,
          filter: controller.targetScheduleId != null
              ? null
              : PickupScheduleFilter(
                  selectedId: controller.firstMileScheduleId,
                  options: controller.firstMileScheduleOptions,
                  onChanged: controller.selectFirstMileSchedule,
                ),
          emptyMessage: controller.targetScheduleId != null
              ? 'No current pickup work is available for this schedule. The notification remains readable in your inbox.'
              : controller.firstMileScheduleId == null
              ? null
              : 'No Seller pickups were returned for the selected schedule. Clear the filter to view unfiltered work.',
          onOpenTask: onOpenTask,
          onOpenRoute: onOpenRoute,
          onRetry: controller.reloadFirstMile,
          onOpenPolicies: onOpenPolicies,
          showPolicyAction: policyController != null,
        ),
        if (controller.targetScheduleId == null) ...[
          const SizedBox(height: 24),
          _PickupSection(
            title: 'Hub pickups',
            subtitle: 'Final-mile work from your Logistics hub to the Buyer.',
            icon: Icons.local_shipping_outlined,
            status: controller.finalMileStatus,
            errorMessage: controller.finalMileErrorMessage,
            tasks: controller.finalMileTasks,
            onOpenTask: onOpenTask,
            onOpenRoute: null,
            onRetry: controller.load,
            onOpenPolicies: onOpenPolicies,
            showPolicyAction: policyController != null,
          ),
        ],
        if (!controller.hasLoadedAnySection && !controller.isLoading) ...[
          const SizedBox(height: 8),
          Text(
            'No pickup section is available yet. Pull to refresh when the service is reachable.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ],
    );
  }
}

class _PickupSection extends StatelessWidget {
  const _PickupSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.status,
    required this.errorMessage,
    required this.tasks,
    required this.onOpenTask,
    required this.onOpenRoute,
    required this.onRetry,
    required this.onOpenPolicies,
    required this.showPolicyAction,
    this.page,
    this.filter,
    this.emptyMessage,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final PickupSectionStatus status;
  final String? errorMessage;
  final List<PickupTask> tasks;
  final FirstMileTaskPage? page;
  final Widget? filter;
  final String? emptyMessage;
  final ValueChanged<PickupTask> onOpenTask;
  final ValueChanged<PickupTask>? onOpenRoute;
  final VoidCallback onRetry;
  final VoidCallback onOpenPolicies;
  final bool showPolicyAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final groupedTasks = _groupTasks(tasks);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (filter != null) ...[filter!, const SizedBox(height: 12)],
        if (status == PickupSectionStatus.loading && tasks.isEmpty)
          const _PickupLoadingState()
        else if (_isBlockingStatus(status) && tasks.isEmpty)
          _PickupErrorState(
            message: errorMessage ?? 'Pickup work is unavailable.',
            status: status,
            onRetry: onRetry,
            onOpenPolicies: onOpenPolicies,
            showPolicyAction: showPolicyAction,
          )
        else if (status == PickupSectionStatus.empty || tasks.isEmpty)
          _PickupEmptyState(title: title, message: emptyMessage)
        else ...[
          for (final group in groupedTasks) ...[
            _ScheduleGroupHeader(
              task: group.first,
              onOpenRoute: onOpenRoute == null
                  ? null
                  : () => onOpenRoute!(group.first),
            ),
            const SizedBox(height: 8),
            for (final task in group) ...[
              _PickupTaskCard(task: task, onTap: () => onOpenTask(task)),
              const SizedBox(height: 8),
            ],
          ],
          if (page?.hasMore == true)
            Text(
              'This is a limited pickup list. More work may be available.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          if (_isRecoverableStatus(status) && errorMessage != null)
            _PickupInlineError(
              message: errorMessage!,
              onRetry: onRetry,
              onOpenPolicies: onOpenPolicies,
              showPolicyAction: showPolicyAction,
            ),
        ],
      ],
    );
  }
}

class _PickupTaskCard extends StatelessWidget {
  const _PickupTaskCard({required this.task, required this.onTap});
  final PickupTask task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TaskRow(
    reference: task.order?.displayReference ?? 'Order reference unavailable',
    leg: _taskLegLabel(task),
    status: _taskStatusLabel(task.rawStatus),
    location: [
      ?task.pickup?.name,
      if (task.destinationArea?.areaSummary case final area?) 'To $area',
    ].join(' · '),
    nextStep: switch (task.status) {
      PickupTaskStatus.assigned => 'Review the pickup offer',
      PickupTaskStatus.accepted => 'Verify the parcel before confirming pickup',
      PickupTaskStatus.deliveryAssigned => 'Review the final-mile batch',
      PickupTaskStatus.deliveryAccepted => 'Request hub handoff confirmation',
      PickupTaskStatus.pickedUpFromHub => 'Continue to delivery work',
      _ => 'Open to review current work',
    },
    onTap: onTap,
  );
}

class _ScheduleGroupHeader extends StatelessWidget {
  const _ScheduleGroupHeader({required this.task, this.onOpenRoute});

  final PickupTask task;
  final VoidCallback? onOpenRoute;

  @override
  Widget build(BuildContext context) {
    final schedule = task.schedule;
    final scheduleLabel = schedule?.displayId;
    final window = _formatWindow(schedule);
    if (scheduleLabel == null && window == null && onOpenRoute == null) {
      return const SizedBox.shrink();
    }

    final label = Text(
      [
        if (scheduleLabel != null) 'Schedule $scheduleLabel',
        ?window,
      ].join(' • '),
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(fontWeight: FontWeight.w700),
    );
    final route = onOpenRoute == null
        ? null
        : TextButton.icon(
            onPressed: onOpenRoute,
            icon: const Icon(Icons.route_outlined),
            label: const Text('Route order'),
          );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 400 ||
            MediaQuery.textScalerOf(context).scale(14) > 21) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [label, ?route],
          );
        }
        return Row(
          children: [
            Expanded(child: label),
            ?route,
          ],
        );
      },
    );
  }
}

List<List<PickupTask>> _groupTasks(List<PickupTask> tasks) {
  final groups = <String, List<PickupTask>>{};
  for (final task in tasks) {
    final key = task.pickupScheduleId ?? task.schedule?.id ?? task.id;
    groups.putIfAbsent(key, () => <PickupTask>[]).add(task);
  }
  return groups.values.toList(growable: false);
}
