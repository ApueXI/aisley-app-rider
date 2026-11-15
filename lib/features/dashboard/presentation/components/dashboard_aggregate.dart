part of '../dashboard_screen.dart';

class _DashboardAggregate extends StatelessWidget {
  const _DashboardAggregate({
    required this.snapshot,
    required this.onOpenPickups,
    required this.onOpenDeliveries,
    required this.onOpenWork,
    this.onRetry,
    this.onOpenNotifications,
    this.onOpenBatches,
  });

  final DashboardSnapshot snapshot;
  final VoidCallback? onRetry;
  final VoidCallback onOpenPickups, onOpenDeliveries;
  final VoidCallback onOpenWork;
  final VoidCallback? onOpenNotifications, onOpenBatches;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final key in const ['active_tasks', 'available_tasks'])
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: _DashboardAggregateSection(
            sectionKey: key,
            section: snapshot.section(key),
            onRetry: onRetry,
            onOpenPickups: onOpenPickups,
            onOpenDeliveries: onOpenDeliveries,
            onOpenWork: onOpenWork,
            onOpenNotifications: onOpenNotifications,
            onOpenBatches: onOpenBatches,
          ),
        ),
    ],
  );
}

class _DashboardAggregateSection extends StatelessWidget {
  const _DashboardAggregateSection({
    required this.sectionKey,
    required this.section,
    required this.onRetry,
    required this.onOpenPickups,
    required this.onOpenDeliveries,
    required this.onOpenWork,
    required this.onOpenNotifications,
    required this.onOpenBatches,
  });

  final String sectionKey;
  final DashboardSection section;
  final VoidCallback? onRetry, onOpenNotifications, onOpenBatches;
  final VoidCallback onOpenPickups, onOpenDeliveries;
  final VoidCallback onOpenWork;

  @override
  Widget build(BuildContext context) {
    final title = _aggregateSectionTitle(sectionKey);
    final refreshedAt = _formatRefreshTime(context, section.generatedAt);

    final onViewAll = sectionKey == 'notifications'
        ? onOpenNotifications
        : onOpenWork;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DashboardAggregateHeading(
          title: title,
          refreshedAt: refreshedAt,
          onViewAll: onViewAll,
        ),
        if (section.state == DashboardSectionState.stale) ...[
          const SizedBox(height: 8),
          _DashboardSectionNotice(
            message: 'Refresh failed · Showing cached data',
            onRetry: onRetry,
          ),
        ],
        if (section.state == DashboardSectionState.failed) ...[
          const SizedBox(height: 8),
          _DashboardSectionNotice(
            message: 'This section could not be loaded.',
            onRetry: onRetry,
            retryLabel: 'Retry',
          ),
        ] else if (section.state == DashboardSectionState.empty) ...[
          const SizedBox(height: 8),
          CourierSurfaceCard(child: Text(_emptySectionLabel(sectionKey))),
        ] else if (section.state == DashboardSectionState.unavailable) ...[
          const SizedBox(height: 8),
          const CourierSurfaceCard(child: Text('Unavailable')),
        ] else if (section.state == DashboardSectionState.unknown) ...[
          const SizedBox(height: 8),
          const CourierSurfaceCard(
            child: Text('This section could not be confirmed.'),
          ),
        ],
        if (section.items.isNotEmpty) ...[
          if (section.state == DashboardSectionState.stale)
            const SizedBox(height: 8),
          for (var index = 0; index < section.items.length; index++) ...[
            if (index > 0) const SizedBox(height: 8),
            _AggregatePreviewCard(
              sectionKey: sectionKey,
              row: section.items[index],
              isStale: section.state == DashboardSectionState.stale,
              onOpenPickups: onOpenPickups,
              onOpenDeliveries: onOpenDeliveries,
              onOpenNotifications: onOpenNotifications,
              onOpenBatches: onOpenBatches,
            ),
          ],
        ],
        if (section.hasMore) ...[
          const SizedBox(height: 8),
          Text(
            _moreSectionLabel(sectionKey),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _DashboardAggregateHeading extends StatelessWidget {
  const _DashboardAggregateHeading({
    required this.title,
    required this.refreshedAt,
    required this.onViewAll,
  });

  final String title;
  final String? refreshedAt;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final titleStyle = Theme.of(context).textTheme.titleMedium;
    final timeStyle = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: scheme.onSurfaceVariant);
    final timestamp = refreshedAt == null
        ? null
        : Text(
            '· Last refreshed $refreshedAt',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: timeStyle,
          );
    final viewAll = onViewAll == null
        ? null
        : TextButton(onPressed: onViewAll, child: const Text('View all'));

    return LayoutBuilder(
      builder: (context, constraints) {
        final stack =
            constraints.maxWidth < 330 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.25;
        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: titleStyle),
              if (timestamp != null || viewAll != null)
                Row(
                  children: [
                    if (timestamp != null) Expanded(child: timestamp),
                    ?viewAll,
                  ],
                ),
            ],
          );
        }
        return Row(
          children: [
            Flexible(child: Text(title, style: titleStyle)),
            if (timestamp != null) ...[
              const SizedBox(width: 8),
              Expanded(child: timestamp),
            ],
            ?viewAll,
          ],
        );
      },
    );
  }
}

class _DashboardSectionNotice extends StatelessWidget {
  const _DashboardSectionNotice({
    required this.message,
    required this.onRetry,
    this.retryLabel = 'Retry',
  });

  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stack =
              constraints.maxWidth < 300 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.25;
          final text = Row(
            children: [
              Icon(Icons.cloud_off_outlined, color: scheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          );
          final retry = onRetry == null
              ? const SizedBox.shrink()
              : TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.onSurface,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text(retryLabel),
                );
          return stack
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [text, if (onRetry != null) retry],
                )
              : Row(
                  children: [
                    Expanded(child: text),
                    retry,
                  ],
                );
        },
      ),
    );
  }
}

class _AggregatePreviewCard extends StatelessWidget {
  const _AggregatePreviewCard({
    required this.sectionKey,
    required this.row,
    required this.isStale,
    required this.onOpenPickups,
    required this.onOpenDeliveries,
    required this.onOpenNotifications,
    required this.onOpenBatches,
  });

  final String sectionKey;
  final Map<String, dynamic> row;
  final bool isStale;
  final VoidCallback onOpenPickups, onOpenDeliveries;
  final VoidCallback? onOpenNotifications, onOpenBatches;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (sectionKey == 'notifications') {
      final title = _stringField(row, 'title') ?? 'Notification';
      final summary = _stringField(row, 'summary');
      return _ReadOnlyDashboardCard(
        title: title,
        contextLabels: [?summary],
        footerLabel: 'Open notifications',
        onTap: onOpenNotifications,
      );
    }

    final rawLeg = _stringField(row, 'leg');
    final rawStatus = _stringField(row, 'status');
    final reference =
        _stringField(row, 'order_reference') ??
        _stringField(row, 'waybill_reference') ??
        'Task reference unavailable';
    final legLabel = _dashboardLegLabel(rawLeg);
    final statusLabel = _dashboardStatusLabel(rawStatus);
    final isOffer = rawStatus == 'assigned' || rawStatus == 'delivery_assigned';
    final isFinalOffer = rawLeg == 'final_mile' && isOffer;
    final onTap = switch (rawLeg) {
      'first_mile' => onOpenPickups,
      'final_mile' when isFinalOffer => onOpenBatches,
      'final_mile' => onOpenDeliveries,
      _ => null,
    };
    final destinationArea = _stringField(row, 'destination_area');
    final freshStatus = isStale ? '$statusLabel (Stale)' : statusLabel;
    final chipLabel = legLabel == null
        ? freshStatus
        : '$legLabel · $freshStatus';
    final actionLabel = isOffer ? 'Review task' : 'View task';
    final actionContent = MediaQuery.textScalerOf(context).scale(1) > 1.25
        ? Text(actionLabel)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(actionLabel),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward),
            ],
          );
    final referenceStyle = isStale
        ? Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          )
        : Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: scheme.onSurfaceVariant);

    return CourierSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final stack =
                  constraints.maxWidth < 300 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.25;
              final titleText = Text(
                reference,
                maxLines: 1,
                softWrap: false,
                style: referenceStyle,
              );
              final status = CourierStatusBadge(
                label: chipLabel,
                tone: _dashboardStatusTone(rawStatus),
              );
              return stack
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(reference, style: referenceStyle),
                        const SizedBox(height: 8),
                        status,
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: FittedBox(
                            alignment: AlignmentDirectional.centerStart,
                            fit: BoxFit.scaleDown,
                            child: titleText,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(child: status),
                      ],
                    );
            },
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: scheme.outlineVariant),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (destinationArea case final area?) ...[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Area',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 2),
                      Text(area),
                    ],
                  ),
                ),
              ],
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Quantity',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '1 parcel',
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (onTap != null) ...[
            const SizedBox(height: 16),
            if (isOffer)
              FilledButton(onPressed: onTap, child: actionContent)
            else
              OutlinedButton(onPressed: onTap, child: actionContent),
          ],
        ],
      ),
    );
  }
}

class _ReadOnlyDashboardCard extends StatelessWidget {
  const _ReadOnlyDashboardCard({
    required this.title,
    required this.contextLabels,
    this.footerLabel,
    this.onTap,
  });

  final String title;
  final List<String> contextLabels;
  final String? footerLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CourierSurfaceCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          for (final label in contextLabels) ...[
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          if (footerLabel != null) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: scheme.outlineVariant),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    footerLabel!,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: onTap == null
                          ? scheme.onSurfaceVariant
                          : scheme.primary,
                    ),
                  ),
                ),
                if (onTap != null)
                  Icon(Icons.arrow_forward, color: scheme.primary),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

String _aggregateSectionTitle(String key) => switch (key) {
  'notifications' => 'Recent notifications',
  'available_tasks' => 'Available work',
  _ => 'Active work',
};

String _emptySectionLabel(String key) => switch (key) {
  'active_tasks' => 'No active work.',
  'available_tasks' => 'No available work.',
  _ => 'No recent notifications.',
};

String _moreSectionLabel(String key) => switch (key) {
  'notifications' => 'Open notifications to review more.',
  _ => 'More work may be available in the work list.',
};

String? _stringField(Map<String, dynamic> value, String key) {
  final field = value[key];
  if (field is String && field.trim().isNotEmpty) return field.trim();
  return null;
}

String? _dashboardLegLabel(String? leg) => switch (leg) {
  'first_mile' => 'First mile',
  'final_mile' => 'Final mile',
  _ => null,
};

String _dashboardStatusLabel(String? status) => switch (status) {
  'assigned' || 'delivery_assigned' => 'Offer',
  'accepted' || 'delivery_accepted' => 'Accepted',
  'picked_up_from_seller' => 'Picked up from Seller',
  'picked_up_from_hub' => 'Picked up from hub',
  'in_transit' => 'In transit',
  'out_for_delivery' => 'Out for delivery',
  'delivered' => 'Delivered',
  'rejected' => 'Rejected',
  _ => 'Status unavailable',
};

CourierStatusTone _dashboardStatusTone(String? status) => switch (status) {
  'rejected' => CourierStatusTone.critical,
  _ => CourierStatusTone.neutral,
};

String? _formatRefreshTime(BuildContext context, String? timestamp) {
  if (timestamp == null) return null;
  final parsed = DateTime.tryParse(timestamp);
  if (parsed == null) return null;
  final local = parsed.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
