import 'dart:async';

import 'package:aisley_app/features/linehaul/domain/linehaul_trip.dart';
import 'package:aisley_app/features/linehaul/domain/linehaul_route.dart';
import 'package:aisley_app/features/linehaul/data/linehaul_repository.dart';

Map<String, dynamic> tripJson({
  String id = 'trip-1',
  String status = 'scheduled',
  bool released = true,
  String direction = 'outbound',
  bool empty = false,
}) => {
  'id': id,
  'direction': direction,
  'status': status,
  'revision': 3,
  'from_hub': {'name': 'Origin hub'},
  'to_hub': {'name': 'Destination hub'},
  'truck': {'plate_number': 'DEMO-001', 'make': null, 'model': null},
  'parcel_count': empty ? 0 : 1,
  'references': empty ? [] : ['SYNTHETIC-001'],
  'lane_blocked': false,
  'empty_return': empty,
  'courier_can_depart': status == 'scheduled' && released,
  'courier_can_report_arrival': status == 'in_transfer',
  'scheduled_for': '2026-10-27T08:00:00Z',
  'released_for_departure_at': released ? '2026-10-26T01:00:00Z' : null,
  'departed_at': status == 'in_transfer' ? '2026-10-26T02:00:00Z' : null,
  'courier_arrived_at': null,
  'arrived_at': null,
  'unloading_closed_at': null,
  'unloading_outcome': null,
  'rejection_reason': null,
};
Map<String, dynamic> routeJson({bool ready = true}) => {
  'status': ready ? 'ready' : 'unavailable',
  'reason': ready ? null : 'quota_guard',
  'hubs': [
    <String, dynamic>{
      'kind': 'origin',
      'name': 'Origin hub',
      'address': 'Synthetic origin',
      'longitude': 121.0,
      'latitude': 14.5,
    },
    <String, dynamic>{
      'kind': 'destination',
      'name': 'Destination hub',
      'address': 'Synthetic destination',
      'longitude': 121.1,
      'latitude': 14.6,
    },
  ],
  'summary': ready ? {'distance_metres': 15000, 'duration_seconds': 900} : null,
  'geometry': ready
      ? {
          'type': 'LineString',
          'coordinates': [
            [121.0, 14.5],
            [121.1, 14.6],
          ],
        }
      : null,
};

class FakeLinehaulRepository implements LinehaulRepository {
  Map<String, dynamic> current = tripJson();
  Object? readError, routeError, actionError;
  int routeReads = 0;
  Completer<LinehaulTrip>? pendingAction;
  Completer<List<LinehaulTrip>>? pendingList;
  Completer<LinehaulRoute>? pendingRoute;
  final calls = <({String id, String action, int revision})>[];
  @override
  Future<List<LinehaulTrip>> trips() async {
    if (readError != null) throw readError!;
    return pendingList?.future ??
        Future.value([LinehaulTrip.fromJson(current)]);
  }

  @override
  Future<LinehaulRoute> route(String id) async {
    routeReads++;
    if (routeError != null) throw routeError!;
    return pendingRoute?.future ??
        Future.value(LinehaulRoute.fromJson(routeJson()));
  }

  @override
  Future<LinehaulTrip> confirm(String id, String action, int revision) async {
    calls.add((id: id, action: action, revision: revision));
    if (actionError != null) throw actionError!;
    if (pendingAction != null) return pendingAction!.future;
    current = {
      ...current,
      'revision': 4,
      if (action == 'depart') ...{
        'status': 'in_transfer',
        'departed_at': '2026-10-26T02:00:00Z',
        'courier_can_depart': false,
        'courier_can_report_arrival': true,
      } else ...{
        'courier_arrived_at': '2026-10-26T03:00:00Z',
        'courier_can_report_arrival': false,
      },
    };
    return LinehaulTrip.fromJson(current);
  }
}
