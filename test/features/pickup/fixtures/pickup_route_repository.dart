import 'package:aisley_app/features/pickup/domain/pickup_models.dart';

import '../../delivery_route/fixtures/route_fixtures.dart';
import 'schedule_filter_repository.dart';

class PickupRouteRepository extends ScheduleFilterRepository {
  Map<String, dynamic> response = emptyPickupRoute();
  Future<PickupRouteManifest> Function(String)? onRouteRead;
  final routeReads = <String>[];

  @override
  Future<PickupRouteManifest> fetchRouteManifest(String scheduleId) async {
    routeReads.add(scheduleId);
    if (onRouteRead != null) return onRouteRead!(scheduleId);
    return PickupRouteManifest.fromResponse(response);
  }
}

Map<String, dynamic> emptyPickupRoute({String status = 'unavailable'}) => {
  'data': {
    'status': status,
    'schedule': {'id': 'schedule-a'},
    'stops': <Object>[],
  },
};

Map<String, dynamic> populatedPickupRoute({bool coordinates = true}) {
  final response = pickupRouteFixture();
  final data = response['data'] as Map<String, dynamic>;
  (data['schedule'] as Map<String, dynamic>)['id'] = 'schedule-a';
  if (!coordinates) {
    data['geojson'] = null;
    for (final stop in data['stops'] as List) {
      (stop as Map<String, dynamic>)['latitude'] = null;
      stop['longitude'] = null;
    }
  }
  return response;
}
