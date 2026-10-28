import 'package:flutter/material.dart';

import '../../../shared/presentation/courier_section_header.dart';
import '../../../shared/presentation/courier_status_badge.dart';
import '../../../shared/presentation/courier_surface_card.dart';
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CourierSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CourierSectionHeader(
                title: trip.direction == 'return'
                    ? 'Return hub transfer'
                    : 'Outbound hub transfer',
                subtitle: '${trip.fromHub} → ${trip.toHub}',
                trailing: CourierStatusBadge(
                  label: _tripStatusLabel(trip),
                  tone: _tripStatusTone(trip),
                ),
              ),
              const SizedBox(height: 8),
              Text(trip.guidance),
              if (trip.rejectionReason case final reason?) ...[
                const SizedBox(height: 8),
                Text('Rejection reason: $reason'),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        CourierSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CourierSectionHeader(title: 'Trip details'),
              const SizedBox(height: 8),
              _TripDetailRow(label: 'Origin', value: trip.fromHub),
              _TripDetailRow(label: 'Destination', value: trip.toHub),
              _TripDetailRow(
                label: 'Company truck',
                value: trip.truckLabel.isEmpty
                    ? 'Truck details unavailable'
                    : trip.truckLabel,
              ),
              _TripDetailRow(
                label: 'Scheduled departure',
                value: formatTripDate(trip.scheduledFor),
              ),
              const Text(
                'The scheduled time is a plan. Departure is reported after the released load physically leaves the origin hub.',
              ),
              if (trip.releasedAt != null)
                _TripDetailRow(
                  label: 'Released for departure',
                  value: formatTripDate(trip.releasedAt),
                ),
              if (trip.emptyReturn)
                const _TripDetailRow(label: 'Load', value: 'Empty return'),
              if (trip.laneBlocked)
                const Text(
                  'Sorting lane blocked. Origin Logistics must resolve this before departure.',
                ),
              if (trip.departedAt != null)
                _TripDetailRow(
                  label: 'Departed',
                  value: formatTripDate(trip.departedAt),
                ),
              if (trip.courierArrivedAt != null)
                _TripDetailRow(
                  label: 'Arrival reported',
                  value: formatTripDate(trip.courierArrivedAt),
                ),
              if (trip.arrivedAt != null)
                _TripDetailRow(
                  label: 'Logistics arrival confirmed',
                  value: formatTripDate(trip.arrivedAt),
                ),
              if (trip.unloadingClosedAt != null)
                _TripDetailRow(
                  label: 'Unloading closed',
                  value:
                      '${formatTripDate(trip.unloadingClosedAt)} · ${trip.unloadingOutcome ?? 'Outcome unavailable'}',
                ),
            ],
          ),
        ),
        if (trip.canDepart || trip.canReportArrival) ...[
          const SizedBox(height: 12),
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
            label: Text(trip.canDepart ? 'Depart' : 'Report arrival at hub'),
          ),
        ],
        const SizedBox(height: 12),
        CourierSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CourierSectionHeader(title: 'Hub route'),
              const SizedBox(height: 8),
              if (controller.routeLoading) const LinearProgressIndicator(),
              if (controller.routeError case final message?)
                Semantics(liveRegion: true, child: Text(message)),
              if (route != null) ...[
                for (var i = 0; i < route.hubs.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '${i + 1}. ${route.hubs[i].name} — ${route.hubs[i].address.isEmpty ? 'Address unavailable' : route.hubs[i].address}',
                    ),
                  ),
                if (route.distanceMetres != null &&
                    route.durationSeconds != null)
                  Text(
                    'Drive ${(route.distanceMetres! / 1000).toStringAsFixed(1)} km · ${(route.durationSeconds! / 60).ceil()} min advisory',
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
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed:
                      controller.saving ||
                          controller.routeLoading ||
                          controller.routeCoolingDown ||
                          controller.coolingDown
                      ? null
                      : controller.loadRoute,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh route'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CourierSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CourierSectionHeader(title: 'Parcels (${trip.parcelCount})'),
              if (trip.references.isEmpty && !trip.emptyReturn) ...[
                const SizedBox(height: 8),
                const Text('Parcel references unavailable.'),
              ],
              for (final reference in trip.references)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(reference),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TripDetailRow extends StatelessWidget {
  const _TripDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        Text(value),
      ],
    ),
  );
}

String _tripStatusLabel(LinehaulTrip trip) => switch (trip.status) {
  'pending_acceptance' => 'Awaiting approval',
  'scheduled' => 'Scheduled',
  'rejected' => 'Rejected',
  'cancelled' => 'Cancelled',
  'in_transfer' =>
    trip.courierArrivedAt == null ? 'In transfer' : 'Arrival reported',
  'receiving' => 'Receiving',
  'received' => 'Received',
  _ => 'Status unavailable',
};

CourierStatusTone _tripStatusTone(LinehaulTrip trip) => switch (trip.status) {
  'received' => CourierStatusTone.success,
  'rejected' || 'cancelled' => CourierStatusTone.critical,
  'in_transfer' || 'receiving' => CourierStatusTone.info,
  _ => CourierStatusTone.neutral,
};

String formatTripDate(DateTime? value) {
  if (value == null) return 'Not recorded';
  final p = value.toUtc().add(const Duration(hours: 8));
  return '${p.year}-${p.month.toString().padLeft(2, '0')}-${p.day.toString().padLeft(2, '0')} ${p.hour.toString().padLeft(2, '0')}:${p.minute.toString().padLeft(2, '0')} (Philippine time)';
}
