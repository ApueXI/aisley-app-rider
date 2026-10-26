import 'package:flutter/material.dart';

import '../../../shared/route_map/route_map_view.dart';
import '../domain/linehaul_trip.dart';
import 'linehaul_controller.dart';

class LinehaulTripDetail extends StatelessWidget {
  const LinehaulTripDetail({
    required this.trip,
    required this.controller,
    required this.onConfirm,
    super.key,
  });
  final LinehaulTrip trip;
  final LinehaulController controller;
  final void Function(String) onConfirm;
  @override
  Widget build(BuildContext context) {
    final route = controller.route;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${trip.fromHub} → ${trip.toHub}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              trip.statusLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(trip.guidance),
            const SizedBox(height: 12),
            Text(
              'Company truck: ${trip.truckLabel.isEmpty ? 'Details unavailable' : trip.truckLabel}',
            ),
            Text('Scheduled: ${formatTripDate(trip.scheduledFor)}'),
            const Text(
              'The schedule does not restrict early or late departure.',
            ),
            if (trip.emptyReturn) const Text('Empty return · No cargo'),
            if (trip.laneBlocked)
              const Text(
                'Sorting lane blocked. Origin Logistics must resolve this before departure.',
              ),
            if (trip.rejectionReason case final reason?)
              Text('Rejection: $reason'),
            if (trip.releasedAt != null)
              Text('Load released: ${formatTripDate(trip.releasedAt)}'),
            if (trip.departedAt != null)
              Text('Departed: ${formatTripDate(trip.departedAt)}'),
            if (trip.courierArrivedAt != null)
              Text(
                'Driver arrival reported: ${formatTripDate(trip.courierArrivedAt)}',
              ),
            if (trip.arrivedAt != null)
              Text(
                'Logistics arrival confirmed: ${formatTripDate(trip.arrivedAt)}',
              ),
            if (trip.unloadingClosedAt != null)
              Text(
                'Unloading closed: ${formatTripDate(trip.unloadingClosedAt)} · ${trip.unloadingOutcome ?? 'Outcome unavailable'}',
              ),
            const SizedBox(height: 12),
            if (trip.canDepart || trip.canReportArrival)
              FilledButton.icon(
                onPressed:
                    controller.locked ||
                        controller.loading ||
                        controller.coolingDown
                    ? null
                    : () => onConfirm(trip.canDepart ? 'depart' : 'arrival'),
                icon: Icon(
                  trip.canDepart
                      ? Icons.local_shipping_outlined
                      : Icons.flag_outlined,
                ),
                label: Text(trip.canDepart ? 'Depart' : 'Arrived at hub'),
              ),
            const Divider(height: 32),
            Text('Hub route', style: Theme.of(context).textTheme.titleMedium),
            if (controller.routeLoading) const LinearProgressIndicator(),
            if (controller.routeError case final message?) Text(message),
            if (route != null) ...[
              for (var i = 0; i < route.hubs.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '${i + 1}. ${route.hubs[i].name} — ${route.hubs[i].address.isEmpty ? 'Address unavailable' : route.hubs[i].address}',
                  ),
                ),
              if (route.distanceMetres != null && route.durationSeconds != null)
                Text(
                  'Drive ${(route.distanceMetres! / 1000).toStringAsFixed(1)} km · ${(route.durationSeconds! / 60).ceil()} min (advisory)',
                ),
              if (route.reason != null)
                const Text(
                  'Road route unavailable. Known hub pins are shown; no road distance or travel time is available.',
                ),
              RouteMapView(
                key: ValueKey('${trip.id}:${controller.routeVersion}'),
                data: route.map,
                semanticLabel: 'Hub route map. 1 marks the origin hub; 2 marks the destination hub.',
                legend: '1: Origin hub • 2: Destination hub',
                onFailure: (_) {},
              ),
            ],
            TextButton.icon(
              onPressed:
                  controller.saving ||
                      controller.routeLoading ||
                      controller.routeCoolingDown ||
                      controller.coolingDown
                  ? null
                  : controller.loadRoute,
              icon: const Icon(Icons.refresh),
              label: const Text('Reload hub route'),
            ),
            const Divider(height: 32),
            Text(
              'Parcels (${trip.parcelCount})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (trip.references.isEmpty && !trip.emptyReturn)
              const Text('Parcel references unavailable.'),
            for (final reference in trip.references)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(reference),
              ),
          ],
        ),
      ),
    );
  }
}

String formatTripDate(DateTime? value) {
  if (value == null) return 'Not recorded';
  final p = value.toUtc().add(const Duration(hours: 8));
  return '${p.year}-${p.month.toString().padLeft(2, '0')}-${p.day.toString().padLeft(2, '0')} ${p.hour.toString().padLeft(2, '0')}:${p.minute.toString().padLeft(2, '0')} (Philippine time)';
}
