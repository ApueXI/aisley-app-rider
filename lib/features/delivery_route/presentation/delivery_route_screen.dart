import 'package:flutter/material.dart';

import '../../../shared/route_map/route_map_view.dart';
import '../../../shared/route_map/route_session_boundary.dart';
import '../../batch/domain/final_mile_batch_models.dart';
import '../domain/delivery_route_models.dart';
import 'delivery_route_controller.dart';

class DeliveryRouteScreen extends StatefulWidget {
  const DeliveryRouteScreen({
    required this.batch,
    required this.controller,
    this.onOpenPolicies,
    super.key,
  });
  final FinalMileBatch batch;
  final DeliveryRouteController controller;
  final VoidCallback? onOpenPolicies;
  @override
  State<DeliveryRouteScreen> createState() => _DeliveryRouteScreenState();
}

class _DeliveryRouteScreenState extends State<DeliveryRouteScreen> {
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final id = widget.batch.id;
    final controller = widget.controller;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          widget.batch.id == id &&
          widget.batch.isAccepted &&
          widget.controller == controller) {
        controller.load(id, refresh: true);
      }
    });
  }

  @override
  void didUpdateWidget(DeliveryRouteScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.batch.id != widget.batch.id ||
        oldWidget.controller != widget.controller) {
      oldWidget.controller.clear();
      _load();
    }
  }

  @override
  void dispose() {
    widget.controller.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final route = controller.scheduleId == widget.batch.id
          ? controller.route
          : null;
      final summary = route?.summary;
      final points = route?.mapData;
      return RouteSessionBoundary(
        child: Scaffold(
          appBar: AppBar(title: const Text('Delivery route')),
          body: RefreshIndicator(
            onRefresh: () => controller.retry(widget.batch.id),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                Text(
                  widget.batch.reference,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (!widget.batch.isAccepted)
                  const Text(
                    'Accept the entire batch before viewing its delivery route.',
                  )
                else ...[
                  if (controller.status == DeliveryRouteLoadStatus.loading)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: LinearProgressIndicator(),
                    ),
                  if (controller.message != null)
                    Semantics(
                      liveRegion: true,
                      child: Text(controller.message!),
                    ),
                  if (route != null) ...[
                    Semantics(
                      liveRegion: true,
                      child: Text(_routeStatus(route)),
                    ),
                    if (controller.lastRefreshed != null)
                      Text(
                        'Last refreshed ${_time(controller.lastRefreshed!)}',
                      ),
                    if (summary != null)
                      Text(
                        '${summary.stopCount} delivery stops • ${summary.distanceMetres == null ? 'Distance unavailable' : '${(summary.distanceMetres! / 1000).toStringAsFixed(1)} km'} • ${summary.durationSeconds == null ? 'Travel time unavailable' : '${(summary.durationSeconds! / 60).ceil()} min (advisory)'}',
                      ),
                    const SizedBox(height: 12),
                    if (controller.mapFailed)
                      const Text(
                        'Map could not be loaded. Route stops remain available below.',
                      )
                    else if (points != null &&
                        points.positions.isNotEmpty &&
                        route.status != DeliveryRouteStatus.unknown)
                      RouteMapView(
                        key: ValueKey(controller.mapVersion),
                        data: points,
                        onFailure: (error) => controller.mapFailure(
                          widget.batch.id,
                          error: error,
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      'Delivery stops',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    for (final stop in route.stops)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          stop.isHub
                              ? 'Logistics hub (start)'
                              : 'Stop ${stop.sequence}',
                        ),
                        subtitle: Text(
                          '${stop.label}${stop.position == null ? '\nCoordinates unavailable' : ''}',
                        ),
                      ),
                    if (route.stops.isEmpty)
                      const Text('Ordered route stops are unavailable.'),
                    for (final task in widget.batch.tasks.where(
                      (task) =>
                          !route.stops.any((stop) => stop.taskId == task.id),
                    ))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Delivery location — route order unavailable',
                        ),
                        subtitle: Text(task.destination.summary),
                      ),
                  ],
                  const SizedBox(height: 12),
                  if (controller.status ==
                          DeliveryRouteLoadStatus.consentRequired &&
                      widget.onOpenPolicies != null)
                    TextButton(
                      onPressed: widget.onOpenPolicies,
                      child: const Text('Review policies'),
                    ),
                  TextButton.icon(
                    onPressed: controller.canRetry
                        ? () => controller.retry(widget.batch.id)
                        : null,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh route'),
                  ),
                  if (controller.status == DeliveryRouteLoadStatus.rateLimited)
                    const Text(
                      'Retry is available after the server’s waiting period.',
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

String _routeStatus(DeliveryRoute route) => switch (route.status) {
  DeliveryRouteStatus.pending =>
    'The delivery route is being prepared. Refresh when ready.',
  DeliveryRouteStatus.unknown =>
    'This route state is unsupported. Readable stops remain available.',
  DeliveryRouteStatus.unavailable =>
    route.reason == 'missing_destination_coordinates'
        ? 'Partial route — some destination coordinates are unavailable. Showing known locations.'
        : 'Road route unavailable. Known locations and any server fallback remain available.',
  DeliveryRouteStatus.ready =>
    'Server-provided delivery order. Travel estimates are advisory.',
};
String _time(DateTime timestamp) {
  final local = timestamp.toUtc().add(const Duration(hours: 8));
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')} (Asia/Manila)';
}
