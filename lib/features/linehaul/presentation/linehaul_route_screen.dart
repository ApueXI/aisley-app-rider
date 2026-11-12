import 'package:flutter/material.dart';

import '../../../shared/presentation/courier_surface_card.dart';
import '../../../shared/route_map/route_map_view.dart';
import 'linehaul_controller.dart';

class LinehaulRouteScreen extends StatelessWidget {
  const LinehaulRouteScreen({required this.controller, super.key});

  final LinehaulController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final route = controller.route;
      return Scaffold(
        appBar: AppBar(title: const Text('Hub route')),
        body: RefreshIndicator(
          onRefresh: controller.loadRoute,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              if (controller.routeLoading) const LinearProgressIndicator(),
              if (controller.routeError case final error?) ...[
                CourierSurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(liveRegion: true, child: Text(error)),
                      TextButton.icon(
                        onPressed: controller.routeCoolingDown
                            ? null
                            : controller.loadRoute,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh route'),
                      ),
                    ],
                  ),
                ),
              ],
              if (route == null && !controller.routeLoading) ...[
                const CourierSurfaceCard(
                  child: Text(
                    'Route details are unavailable. Trip status and arrival actions remain available.',
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: controller.routeCoolingDown
                        ? null
                        : controller.loadRoute,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh route'),
                  ),
                ),
              ],
              if (route != null) ...[
                CourierSurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var index = 0; index < route.hubs.length; index++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                index == 0 ? 'Origin' : 'Destination',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              Text(
                                '${route.hubs[index].name} · ${route.hubs[index].address.isEmpty ? 'Address unavailable' : route.hubs[index].address}',
                              ),
                            ],
                          ),
                        ),
                      if (route.distanceMetres != null &&
                          route.durationSeconds != null) ...[
                        const Divider(height: 24),
                        Text(
                          'Advisory drive: ${(route.distanceMetres! / 1000).toStringAsFixed(1)} km · ${(route.durationSeconds! / 60).ceil()} min',
                        ),
                      ] else
                        const Text(
                          'Road distance and travel time are unavailable.',
                        ),
                      if (route.reason != null)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'The road route is unavailable. Known hub locations may still be shown.',
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                RouteMapView(
                  key: ValueKey(
                    '${controller.selectedId}:${controller.routeVersion}',
                  ),
                  data: route.map,
                  semanticLabel: 'Hub route map. 1 marks the origin hub; 2 marks the destination hub.',
                  legend: '1: Origin hub • 2: Destination hub',
                  onFailure: (_) {},
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed:
                        controller.routeLoading || controller.routeCoolingDown
                        ? null
                        : controller.loadRoute,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh route'),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
