import '../../../shared/route_map/route_map_data.dart';
import 'linehaul_trip.dart';

class LinehaulHub {
  LinehaulHub.fromJson(Object? value) {
    final j = object(value);
    kind = text(j['kind']);
    if (!{'origin', 'destination'}.contains(kind)) fail();
    name = text(j['name']);
    final addressValue = j['address'];
    if (addressValue is! String) fail();
    address = addressValue;
    position = RoutePosition.parse(j['longitude'], j['latitude']);
  }
  late final String kind, name, address;
  late final RoutePosition? position;
}

class LinehaulRoute {
  LinehaulRoute.fromJson(Object? value) {
    final j = object(value);
    final status = text(j['status']);
    if (!{'ready', 'unavailable'}.contains(status)) fail();
    reason = nullableText(j['reason']);
    final raw = j['hubs'];
    if (raw is! List || raw.length != 2) fail();
    hubs = List.unmodifiable(raw.map(LinehaulHub.fromJson));
    if (hubs[0].kind != 'origin' || hubs[1].kind != 'destination') fail();
    final points = <RoutePosition>[];
    if (status == 'ready') {
      final geometry = object(j['geometry']);
      final coordinates = geometry['coordinates'];
      if (geometry['type'] != 'LineString' ||
          coordinates is! List ||
          coordinates.length < 2 ||
          coordinates.length > 10000) {
        fail();
      }
      for (final pair in coordinates) {
        if (pair is! List || pair.length != 2) fail();
        final point = RoutePosition.parse(pair[0], pair[1]);
        if (point == null) fail();
        points.add(point);
      }
      final summary = object(j['summary']);
      distanceMetres = metric(summary['distance_metres']);
      durationSeconds = metric(summary['duration_seconds']);
    }
    map = RouteMapData(
      markers: List.unmodifiable([
        for (var i = 0; i < hubs.length; i++)
          if (hubs[i].position case final p?)
            RouteMarker(position: p, label: '${i + 1}'),
      ]),
      line: List.unmodifiable(points),
      geometrySource: points.isEmpty ? null : 'geoapify_routing',
    );
  }
  late final List<LinehaulHub> hubs;
  late final RouteMapData map;
  late final String? reason;
  double? distanceMetres, durationSeconds;
}

double metric(Object? v) =>
    v is num && v.isFinite && v >= 0 ? v.toDouble() : fail();
