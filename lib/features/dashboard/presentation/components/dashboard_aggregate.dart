part of '../dashboard_screen.dart';

class _DashboardAggregate extends StatelessWidget {
  const _DashboardAggregate({
    required this.snapshot,
    required this.onOpenPickups,
    required this.onOpenDeliveries,
    this.onRetry,
    this.onOpenNotifications,
    this.onOpenBatches,
  });

  final DashboardSnapshot snapshot;
  final VoidCallback? onRetry;
  final VoidCallback onOpenPickups, onOpenDeliveries;
  final VoidCallback? onOpenNotifications, onOpenBatches;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final key in const [
        'active_tasks',
        'available_tasks',
        'notifications',
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _DashboardAggregateSection(
            sectionKey: key,
            section: snapshot.section(key),
            onRetry: onRetry,
            onOpenPickups: onOpenPickups,
            onOpenDeliveries: onOpenDeliveries,
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
    required this.onOpenNotifications,
    required this.onOpenBatches,
  });

  final String sectionKey;
  final DashboardSection section;
  final VoidCallback? onRetry, onOpenNotifications, onOpenBatches;
  final VoidCallback onOpenPickups, onOpenDeliveries;

  @override
  Widget build(BuildContext context) {
    final title = _aggregateSectionTitle(sectionKey);
    final refreshedAt = _formatRefreshTime(context, section.generatedAt);

    return CourierSurfaceCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CourierSectionHeader(
            title: title,
            trailing: refreshedAt == null
                ? null
                : Text(
                    'Last refreshed $refreshedAt',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
          ),
          if (section.state == DashboardSectionState.stale) ...[
            const SizedBox(height: 8),
            CourierStatusBadge(
              label: 'Needs refresh',
              tone: CourierStatusTone.warning,
            ),
            const SizedBox(height: 4),
            Text(
              'Showing earlier data for this section. Refresh before acting.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh dashboard'),
                ),
              ),
            ],
          ],
          if (section.state == DashboardSectionState.failed) ...[
            const SizedBox(height: 8),
            const Text('This section could not be loaded. Refresh to retry.'),
            if (onRetry != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ),
            ],
          ] else if (section.state == DashboardSectionState.empty) ...[
            const SizedBox(height: 8),
            Text(_emptySectionLabel(sectionKey)),
          ] else if (section.state == DashboardSectionState.unavailable) ...[
            const SizedBox(height: 8),
            const Text('Unavailable'),
          ] else if (section.state == DashboardSectionState.unknown) ...[
            const SizedBox(height: 8),
            const Text('This section could not be confirmed.'),
          ],
          if (section.items.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (var index = 0; index < section.items.length; index++) ...[
              if (index > 0) const SizedBox(height: 8),
              _AggregatePreviewCard(
                sectionKey: sectionKey,
                row: section.items[index],
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
      ),
    );
  }
}

class _AggregatePreviewCard extends StatelessWidget {
  const _AggregatePreviewCard({
    required this.sectionKey,
    required this.row,
    required this.onOpenPickups,
    required this.onOpenDeliveries,
    required this.onOpenNotifications,
    required this.onOpenBatches,
  });

  final String sectionKey;
  final Map<String, dynamic> row;
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
    final isFinalOffer =
        rawLeg == 'final_mile' && rawStatus == 'delivery_assigned';
    final onTap = switch (rawLeg) {
      'first_mile' => onOpenPickups,
      'final_mile' when isFinalOffer => onOpenBatches,
      'final_mile' => onOpenDeliveries,
      _ => null,
    };
    final footerLabel = switch (rawLeg) {
      'first_mile' => 'Open pickup orders',
      'final_mile' when isFinalOffer => 'Review final-mile batches',
      'final_mile' => 'Open delivery work',
      _ => null,
    };

    return _ReadOnlyDashboardCard(
      title: reference,
      badges: [
        if (legLabel != null)
          CourierStatusBadge(label: legLabel, tone: CourierStatusTone.info),
        CourierStatusBadge(
          label: statusLabel,
          tone: _dashboardStatusTone(rawStatus),
        ),
      ],
      contextLabels: [
        if (legLabel == null) 'Task leg unavailable',
        if (rawStatus == null) 'Task status unavailable',
      ],
      footerLabel: footerLabel,
      onTap: onTap,
      titleStyle: Theme.of(context).textTheme.titleMedium,
      borderColor: scheme.outlineVariant,
    );
  }
}

class _ReadOnlyDashboardCard extends StatelessWidget {
  const _ReadOnlyDashboardCard({
    required this.title,
    required this.contextLabels,
    this.badges = const [],
    this.footerLabel,
    this.onTap,
    this.titleStyle,
    this.borderColor,
  });

  final String title;
  final List<String> contextLabels;
  final List<Widget> badges;
  final String? footerLabel;
  final VoidCallback? onTap;
  final TextStyle? titleStyle;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CourierSurfaceCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: titleStyle ?? Theme.of(context).textTheme.titleSmall,
          ),
          if (badges.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, children: badges),
          ],
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
            Divider(height: 1, color: borderColor ?? scheme.outlineVariant),
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
  'assigned' || 'delivery_assigned' => 'Assigned',
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
  'assigned' || 'delivery_assigned' => CourierStatusTone.info,
  'accepted' ||
  'delivery_accepted' ||
  'picked_up_from_seller' ||
  'picked_up_from_hub' ||
  'in_transit' ||
  'out_for_delivery' ||
  'delivered' => CourierStatusTone.success,
  'rejected' => CourierStatusTone.critical,
  _ => CourierStatusTone.neutral,
};

String? _formatRefreshTime(BuildContext context, String? timestamp) {
  if (timestamp == null) return null;
  final parsed = DateTime.tryParse(timestamp);
  if (parsed == null) return null;
  return MaterialLocalizations.of(context)
      .formatTimeOfDay(TimeOfDay.fromDateTime(parsed.toLocal()));
}
