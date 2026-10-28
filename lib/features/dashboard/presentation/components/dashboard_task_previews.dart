part of '../dashboard_screen.dart';

class _DashboardTaskPreviews extends StatelessWidget {
  const _DashboardTaskPreviews({
    required this.controller,
    required this.onOpenFirstMile,
    required this.onOpenFinalMile,
  });

  final DashboardPreviewController controller;
  final VoidCallback onOpenFirstMile;
  final VoidCallback onOpenFinalMile;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Limited work previews. Open a work list for current tasks.',
          ),
          const SizedBox(height: 12),
          _TaskPreviewSection(
            title: 'First-mile pickup',
            source: 'Limited pickup preview',
            expectedLeg: PickupTaskLeg.firstMile,
            section: controller.firstMile,
            canRetry: controller.canRetryFirstMile,
            onRetry: controller.refreshFirstMile,
            onOpen: onOpenFirstMile,
            showRows: false,
          ),
          const SizedBox(height: 12),
          _TaskPreviewSection(
            title: 'Final-mile delivery',
            source: 'Limited delivery preview',
            expectedLeg: PickupTaskLeg.finalMile,
            section: controller.finalMile,
            canRetry: controller.canRetryFinalMile,
            onRetry: controller.refreshFinalMile,
            onOpen: onOpenFinalMile,
            showRows: false,
          ),
          const SizedBox(height: 16),
          for (final category in [
            DashboardTaskClass.active,
            DashboardTaskClass.offered,
            DashboardTaskClass.other,
          ])
            _PreviewWorkGroup(
              controller: controller,
              category: category,
              onOpenFirstMile: onOpenFirstMile,
              onOpenFinalMile: onOpenFinalMile,
            ),
        ],
      ),
    );
  }
}

class _PreviewWorkGroup extends StatelessWidget {
  const _PreviewWorkGroup({
    required this.controller,
    required this.category,
    required this.onOpenFirstMile,
    required this.onOpenFinalMile,
  });
  final DashboardPreviewController controller;
  final DashboardTaskClass category;
  final VoidCallback onOpenFirstMile, onOpenFinalMile;

  @override
  Widget build(BuildContext context) {
    final rows =
        <(DashboardTaskPreview, PickupTaskLeg)>[
          for (final task in controller.firstMile.tasks)
            (task, PickupTaskLeg.firstMile),
          for (final task in controller.finalMile.tasks)
            (task, PickupTaskLeg.finalMile),
        ].where((row) {
          final classified = dashboardTaskClassification(row.$1, row.$2);
          return classified == category ||
              category == DashboardTaskClass.other &&
                  classified == DashboardTaskClass.unclassified;
        }).toList();
    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(switch (category) {
            DashboardTaskClass.active => 'Active work',
            DashboardTaskClass.offered => 'Available work',
            _ => 'Other work',
          }, style: Theme.of(context).textTheme.titleMedium),
          for (final row in rows)
            _TaskPreviewRow(
              task: row.$1,
              expectedLeg: row.$2,
              onOpen: row.$2 == PickupTaskLeg.firstMile
                  ? onOpenFirstMile
                  : onOpenFinalMile,
            ),
        ],
      ),
    );
  }
}

class _TaskPreviewSection extends StatelessWidget {
  const _TaskPreviewSection({
    required this.title,
    required this.source,
    required this.expectedLeg,
    required this.section,
    required this.canRetry,
    required this.onRetry,
    required this.onOpen,
    this.showRows = true,
  });

  final bool showRows;
  final String title;
  final String source;
  final PickupTaskLeg expectedLeg;
  final DashboardPreviewSection section;
  final bool canRetry;
  final VoidCallback onRetry;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final status = section.status;
    final isLoading = status == DashboardPreviewStatus.loading;
    final loadedAt = section.refreshedAt;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(source, style: Theme.of(context).textTheme.bodySmall),
                if (loadedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Last loaded ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(loadedAt.toLocal()))}${section.isStale ? ' · may be stale' : ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (isLoading) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(
                    semanticsLabel: 'Refreshing task preview',
                  ),
                ],
                if (section.error case final message?) ...[
                  const SizedBox(height: 8),
                  Semantics(liveRegion: true, child: Text(message)),
                ],
                if (status == DashboardPreviewStatus.empty) ...[
                  const SizedBox(height: 8),
                  const Text('No tasks returned by this list.'),
                ],
                if (status == DashboardPreviewStatus.idle) ...[
                  const SizedBox(height: 8),
                  const Text('Task preview has not loaded yet.'),
                ],
              ],
            ),
          ),
          if (showRows)
            for (final task in section.tasks) ...[
              const Divider(height: 16),
              _TaskPreviewRow(
                task: task,
                expectedLeg: expectedLeg,
                onOpen: onOpen,
              ),
            ],
          if (section.firstPageOnly)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text('More first-mile tasks may be on later pages.'),
            ),
          if (section.error != null && canRetry)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text('Retry $title'),
              ),
            ),
        ],
      ),
    );
  }
}

class _TaskPreviewRow extends StatelessWidget {
  const _TaskPreviewRow({
    required this.task,
    required this.expectedLeg,
    required this.onOpen,
  });

  final DashboardTaskPreview task;
  final PickupTaskLeg expectedLeg;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final classification = dashboardTaskClassification(task, expectedLeg);
    final orderReference = task.orderReference;
    final waybillReference = task.waybillReference;
    final label = orderReference != null
        ? 'Order $orderReference'
        : waybillReference != null
        ? 'Waybill $waybillReference'
        : 'Task reference unavailable';
    final origin = task.originName;
    final destination = task.destinationArea;
    final workState =
        '${classification.label} · ${dashboardTaskStatusLabel(task)}';
    final contextLines = [
      if (origin != null) 'From $origin',
      if (destination != null) 'To $destination',
      if (task.distanceKm case final km? when km >= 0)
        '${km.toStringAsFixed(1)} km',
      if (task.estimatedDurationMinutes case final minutes? when minutes >= 0)
        '$minutes min estimate',
    ].join(' · ');
    final canNavigate = classification != DashboardTaskClass.unclassified;
    final nextStep = switch (expectedLeg) {
      PickupTaskLeg.firstMile => 'Open pickup orders',
      PickupTaskLeg.finalMile => 'Open delivery work',
      PickupTaskLeg.unknown => 'Open work lists',
    };
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CourierSurfaceCard(
        padding: const EdgeInsets.all(12),
        onTap: canNavigate ? onOpen : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                CourierStatusBadge(
                  label: expectedLeg == PickupTaskLeg.firstMile
                      ? 'First mile'
                      : 'Final mile',
                  tone: CourierStatusTone.info,
                ),
                CourierStatusBadge(label: workState, tone: _previewTone(task)),
              ],
            ),
            if (contextLines.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                contextLines,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 12),
            Divider(height: 1, color: scheme.outlineVariant),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    canNavigate ? nextStep : 'Review status in the work list',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: canNavigate
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (canNavigate)
                  Icon(Icons.arrow_forward, color: scheme.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

CourierStatusTone _previewTone(DashboardTaskPreview task) =>
    switch (task.status) {
      PickupTaskStatus.assigned ||
      PickupTaskStatus.deliveryAssigned => CourierStatusTone.info,
      PickupTaskStatus.accepted ||
      PickupTaskStatus.deliveryAccepted ||
      PickupTaskStatus.pickedUpFromSeller ||
      PickupTaskStatus.pickedUpFromHub ||
      PickupTaskStatus.inTransit ||
      PickupTaskStatus.outForDelivery => CourierStatusTone.success,
      PickupTaskStatus.rejected => CourierStatusTone.critical,
      _ => CourierStatusTone.neutral,
    };
