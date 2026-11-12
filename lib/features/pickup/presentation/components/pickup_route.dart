part of '../pickup_screen.dart';

class PickupRouteScreen extends StatefulWidget {
  const PickupRouteScreen({
    required this.pickupController,
    required this.scheduleId,
    this.schedule,
    this.onOpenPolicies,
    super.key,
  });

  final PickupController pickupController;
  final String scheduleId;
  final PickupSchedule? schedule;
  final VoidCallback? onOpenPolicies;

  @override
  State<PickupRouteScreen> createState() => _PickupRouteScreenState();
}

class _PickupRouteScreenState extends State<PickupRouteScreen> {
  int _mapVersion = 0;
  bool _mapFailed = false;
  @override
  void dispose() {
    widget.pickupController.releaseRouteManifest(widget.scheduleId);
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!widget.pickupController.canRetryRateLimit) return;
    setState(() {
      _mapFailed = false;
      _mapVersion++;
    });
    await widget.pickupController.loadRouteManifest(
      widget.scheduleId,
      refresh: true,
    );
  }

  Future<void> _mapFailure(ApiException? error) async {
    setState(() => _mapFailed = true);
    await widget.pickupController.loadRouteManifest(
      widget.scheduleId,
      refresh: true,
    );
    if (mounted &&
        error?.statusCode == 429 &&
        widget.pickupController.routeStatuses.containsKey(widget.scheduleId)) {
      widget.pickupController.holdRouteRetry(error!.retryAfter);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final id = widget.scheduleId;
    final controller = widget.pickupController;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          widget.scheduleId == id &&
          widget.pickupController == controller) {
        controller.loadRouteManifest(id);
      }
    });
  }

  @override
  void didUpdateWidget(PickupRouteScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scheduleId != widget.scheduleId ||
        oldWidget.pickupController != widget.pickupController) {
      oldWidget.pickupController.releaseRouteManifest(oldWidget.scheduleId);
      _mapFailed = false;
      _mapVersion++;
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.pickupController,
      builder: (context, child) {
        final controller = widget.pickupController;
        final status =
            controller.routeStatuses[widget.scheduleId] ??
            PickupSectionStatus.idle;
        final manifest = controller.routeManifests[widget.scheduleId];
        final error = controller.routeErrors[widget.scheduleId];
        final hasNoStops = manifest?.stops.isEmpty == true;
        return RouteSessionBoundary(
          child: Scaffold(
            appBar: AppBar(title: const Text('Pickup route')),
            body: hasNoStops
                ? RefreshIndicator(
                    onRefresh: _refresh,
                    child: LayoutBuilder(
                      builder: (context, constraints) => ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 24,
                                ),
                                child: _RouteEmptyState(message: error),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      children: [
                        _RouteSummary(
                          schedule: widget.schedule,
                          manifest: manifest,
                        ),
                        const SizedBox(height: 16),
                        if (status == PickupSectionStatus.loading &&
                            manifest == null)
                          const _PickupLoadingState()
                        else if (manifest == null && error != null)
                          _PickupErrorState(
                            message: error,
                            status: status,
                            onRetry: () =>
                                controller.loadRouteManifest(widget.scheduleId),
                            onOpenPolicies: widget.onOpenPolicies ?? () {},
                            showPolicyAction: widget.onOpenPolicies != null,
                          )
                        else if (manifest != null) ...[
                          if (status == PickupSectionStatus.loading)
                            const LinearProgressIndicator(),
                          _RouteStatusBanner(manifest: manifest),
                          if (_mapFailed)
                            const Text('Map could not be loaded.')
                          else if (manifest.stops.isNotEmpty &&
                              (manifest.status == RouteManifestStatus.ready ||
                                  manifest.status ==
                                      RouteManifestStatus.unavailable))
                            RouteMapView(
                              key: ValueKey(_mapVersion),
                              data: _pickupMapData(manifest),
                              onFailure: _mapFailure,
                            ),
                          const SizedBox(height: 16),
                          const CourierSectionHeader(title: 'Ordered stops'),
                          const SizedBox(height: 8),
                          ..._routeStopWidgets(context, manifest.stops),
                          if (error != null) ...[
                            const SizedBox(height: 8),
                            Text(error),
                          ],
                        ],
                        OutlinedButton.icon(
                          onPressed:
                              status == PickupSectionStatus.loading ||
                                  !controller.canRetryRateLimit
                              ? null
                              : _refresh,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh route'),
                        ),
                        if (!controller.canRetryRateLimit)
                          const Text('Wait before retrying the route.'),
                      ],
                    ),
                  ),
            bottomNavigationBar: hasNoStops
                ? _RouteEmptyActions(
                    onBack: () => Navigator.of(context).maybePop(),
                    onRefresh: _refresh,
                    refreshEnabled:
                        status != PickupSectionStatus.loading &&
                        controller.canRetryRateLimit,
                    waitMessage: controller.canRetryRateLimit
                        ? null
                        : 'Wait before retrying the route.',
                  )
                : null,
          ),
        );
      },
    );
  }
}

class _RouteEmptyState extends StatelessWidget {
  const _RouteEmptyState({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.surfaceContainerHighest,
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Icon(
            Icons.alt_route,
            color: scheme.onSurfaceVariant,
            size: 30,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'No route stops available',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'No route stops are available. Return to pickup tasks to review your work.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        if (message != null) ...[
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(
              message!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.error),
            ),
          ),
        ],
      ],
    );
  }
}

class _RouteEmptyActions extends StatelessWidget {
  const _RouteEmptyActions({
    required this.onBack,
    required this.onRefresh,
    required this.refreshEnabled,
    this.waitMessage,
  });

  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final bool refreshEnabled;
  final String? waitMessage;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: onBack,
              child: const Text('Back to pickup tasks'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: refreshEnabled ? onRefresh : null,
              child: const Text('Refresh route'),
            ),
          ),
          if (waitMessage != null) ...[
            const SizedBox(height: 4),
            Text(waitMessage!, textAlign: TextAlign.center),
          ],
        ],
      ),
    ),
  );
}

class _RouteSummary extends StatelessWidget {
  const _RouteSummary({required this.schedule, required this.manifest});

  final PickupSchedule? schedule;
  final PickupRouteManifest? manifest;

  @override
  Widget build(BuildContext context) {
    return CourierSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CourierSectionHeader(
            title: schedule?.displayId ?? 'Pickup route',
            subtitle: 'Pickup stops for this schedule.',
          ),
          if (_formatWindow(schedule) != null) ...[
            const SizedBox(height: 8),
            Text(_formatWindow(schedule)!),
          ],
          if (manifest?.calculatedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Calculated ${_formatManilaTimestamp(manifest!.calculatedAt!)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _RouteStatusBanner extends StatelessWidget {
  const _RouteStatusBanner({required this.manifest});

  final PickupRouteManifest manifest;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasStops = manifest.stops.isNotEmpty;
    final (message, icon) = switch (manifest.status) {
      RouteManifestStatus.pending => (
        hasStops
            ? 'The pickup route is still being prepared. Available stops are listed below.'
            : 'The pickup route is still being prepared.',
        Icons.hourglass_top_outlined,
      ),
      RouteManifestStatus.ready => (
        !hasStops
            ? 'Route stops were not provided.'
            : manifest.stops.any((s) => s.reachable == false)
            ? 'Partial route — some stops are unreachable. All authorized stops are listed below.'
            : 'The server provided an ordered pickup route returning to the hub.',
        Icons.route_outlined,
      ),
      RouteManifestStatus.unavailable => (
        hasStops
            ? 'Route presentation is unavailable. Available stops and addresses are listed below.'
            : 'Route stops are unavailable.',
        Icons.route_outlined,
      ),
      RouteManifestStatus.unknown => (
        hasStops
            ? 'This pickup route cannot be displayed. Available stops are listed below.'
            : 'This pickup route cannot be displayed.',
        Icons.info_outline,
      ),
    };
    return CourierSurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(
                hasStops
                    ? message
                    : '$message Return to pickup tasks for pickup addresses.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

RouteMapData _pickupMapData(PickupRouteManifest manifest) {
  var number = 0;
  return RouteMapData.sanitized(
    geoJson: manifest.geoJson,
    markers: [
      for (final stop in manifest.stops)
        if (stop.isHub || stop.kind == 'pickup') ...[
          if (!stop.isHub)
            ..._pickupMarker(stop, '${++number}')
          else
            ..._pickupMarker(stop, 'H'),
        ],
    ],
  );
}

List<RouteMarker> _pickupMarker(PickupRouteStop stop, String label) {
  final position = RoutePosition.parse(stop.longitude, stop.latitude);
  return position == null
      ? []
      : [RouteMarker(position: position, label: label, isHub: stop.isHub)];
}

List<Widget> _routeStopWidgets(
  BuildContext context,
  List<PickupRouteStop> stops,
) {
  final ordered = List<PickupRouteStop>.from(stops)
    ..sort((a, b) => a.sequence.compareTo(b.sequence));
  return [
    for (final stop in ordered) ...[
      Semantics(
        container: true,
        label: _routeStopSemantics(stop),
        child: CourierSurfaceCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                child: Text(stop.isHub ? 'H' : '${stop.sequence}'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stop.isHub
                          ? 'Logistics hub (${stop.sequence == 0 ? 'start' : 'return'})'
                          : 'Pickup stop ${stop.sequence}',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if (stop.addressSummary != null) ...[
                      const SizedBox(height: 4),
                      Text(stop.addressSummary!),
                    ],
                    if (stop.orderReferences.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('Orders: ${stop.orderReferences.join(', ')}'),
                    ],
                    if (stop.reachable == false) ...[
                      const SizedBox(height: 6),
                      Text(
                        'This stop is unreachable in the current manifest.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 8),
    ],
  ];
}

String _routeStopSemantics(PickupRouteStop stop) {
  final label = stop.isHub ? 'Logistics hub' : 'Pickup stop';
  return [
    stop.isHub
        ? '$label ${stop.sequence == 0 ? 'start' : 'return'}'
        : '$label ${stop.sequence}',
    if (stop.addressSummary != null) stop.addressSummary!,
    if (stop.orderReferences.isNotEmpty)
      'Orders ${stop.orderReferences.join(', ')}',
    if (stop.reachable == false) 'unreachable in current manifest',
  ].join('. ');
}
