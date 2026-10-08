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
        return RouteSessionBoundary(
          child: Scaffold(
            appBar: AppBar(title: const Text('Pickup route order')),
            body: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: [
                  _RouteSummary(schedule: widget.schedule, manifest: manifest),
                  const SizedBox(height: 16),
                  if (status == PickupSectionStatus.loading && manifest == null)
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
                      const Text(
                        'Map could not be loaded. Route stops remain available below.',
                      )
                    else if (manifest.status == RouteManifestStatus.ready ||
                        manifest.status == RouteManifestStatus.unavailable)
                      RouteMapView(
                        key: ValueKey(_mapVersion),
                        data: _pickupMapData(manifest),
                        onFailure: _mapFailure,
                      ),
                    const SizedBox(height: 16),
                    if (manifest.stops.isEmpty)
                      const _PickupEmptyState(title: 'route stops')
                    else
                      ..._routeStopWidgets(context, manifest.stops),
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text(error),
                    ],
                  ],
                  TextButton.icon(
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
          ),
        );
      },
    );
  }
}

class _RouteSummary extends StatelessWidget {
  const _RouteSummary({required this.schedule, required this.manifest});

  final PickupSchedule? schedule;
  final PickupRouteManifest? manifest;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Authorized stop order',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'This is a schedule-scoped pickup sequence. It is not a Buyer delivery route.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
    );
  }
}

class _RouteStatusBanner extends StatelessWidget {
  const _RouteStatusBanner({required this.manifest});

  final PickupRouteManifest manifest;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (message, icon) = switch (manifest.status) {
      RouteManifestStatus.pending => (
        'The route manifest is still being prepared. Pickup details remain available.',
        Icons.hourglass_top_outlined,
      ),
      RouteManifestStatus.ready => (
        manifest.stops.any((s) => s.reachable == false)
            ? 'Partial route — some stops are unreachable. All authorized stops are listed below.'
            : 'The server provided an ordered pickup route returning to the hub.',
        Icons.route_outlined,
      ),
      RouteManifestStatus.unavailable => (
        'Route presentation is unavailable. Continue with the authorized stop and address list.',
        Icons.route_outlined,
      ),
      RouteManifestStatus.unknown => (
        'The server returned an unsupported route state. Continue with the stop list if present.',
        Icons.info_outline,
      ),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
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
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
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
