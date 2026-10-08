import '../../../core/networking/api_contract_exception.dart';
import '../../../shared/route_map/route_map_data.dart';

enum DeliveryRouteStatus { ready, pending, unavailable, unknown }

class DeliveryRouteSummary {
  const DeliveryRouteSummary({
    required this.stopCount,
    this.distanceMetres,
    this.durationSeconds,
  });
  final int stopCount;
  final double? distanceMetres;
  final int? durationSeconds;
  factory DeliveryRouteSummary.fromJson(Map value) => DeliveryRouteSummary(
    stopCount: _integer(value['stop_count'], 'route.summary.stop_count'),
    distanceMetres: _number(value['distance_metres']),
    durationSeconds: value['duration_seconds'] == null
        ? null
        : _integer(value['duration_seconds'], 'route.summary.duration_seconds'),
  );
}

class DeliveryRouteMap {
  const DeliveryRouteMap({required this.styleUrl, required this.attribution});
  final String styleUrl;
  final List<String> attribution;
  factory DeliveryRouteMap.fromJson(Map value) {
    if (value['style_url'] != '/api/v1/courier/map-style' ||
        value['attribution'] is! List) {
      throw const ApiContractException('route.map');
    }
    return DeliveryRouteMap(
      styleUrl: value['style_url'] as String,
      attribution: List.unmodifiable(
        (value['attribution'] as List).whereType<String>(),
      ),
    );
  }
}

class DeliveryRouteStop {
  const DeliveryRouteStop({
    required this.sequence,
    required this.kind,
    required this.label,
    this.taskId,
    this.position,
  });
  final int sequence;
  final String kind;
  final String label;
  final String? taskId;
  final RoutePosition? position;
  bool get isHub => kind == 'hub';
  factory DeliveryRouteStop.fromJson(Map value) => DeliveryRouteStop(
    sequence: _integer(value['sequence'], 'route.stop.sequence'),
    kind: _string(value['kind']) ?? 'unknown',
    label: _string(value['label']) ?? 'Location unavailable',
    taskId: _string(value['task_id']),
    position: RoutePosition.parse(value['longitude'], value['latitude']),
  );
}

class DeliveryRoute {
  const DeliveryRoute({
    required this.status,
    required this.stops,
    this.reason,
    this.summary,
    this.geoJson,
    this.map,
  });
  final DeliveryRouteStatus status;
  final String? reason;
  final DeliveryRouteSummary? summary;
  final List<DeliveryRouteStop> stops;
  final Map<String, dynamic>? geoJson;
  final DeliveryRouteMap? map;

  RouteMapData get mapData => RouteMapData.sanitized(
    geoJson: geoJson,
    markers: [
      for (final stop in stops)
        if (stop.position != null && (stop.isHub || stop.kind == 'delivery'))
          RouteMarker(
            position: stop.position!,
            label: stop.isHub ? 'H' : '${stop.sequence}',
            isHub: stop.isHub,
          ),
    ],
  );

  factory DeliveryRoute.fromResponse(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is! Map ||
        data['stops'] is! List ||
        (data['stops'] as List).length > 16) {
      throw const ApiContractException('route.data');
    }
    Map? optionalMap(String key) {
      final value = data[key];
      if (value == null) return null;
      if (value is! Map) throw ApiContractException('route.$key');
      return value;
    }

    final stops = <DeliveryRouteStop>[];
    for (final value in data['stops'] as List) {
      if (value is! Map) throw const ApiContractException('route.stop');
      stops.add(DeliveryRouteStop.fromJson(value));
    }
    final summary = optionalMap('summary'),
        map = optionalMap('map'),
        geometry = optionalMap('geojson');
    return DeliveryRoute(
      status: switch (data['status']) {
        'ready' => DeliveryRouteStatus.ready,
        'pending' => DeliveryRouteStatus.pending,
        'unavailable' => DeliveryRouteStatus.unavailable,
        _ => DeliveryRouteStatus.unknown,
      },
      reason: _string(data['reason']),
      summary: summary == null ? null : DeliveryRouteSummary.fromJson(summary),
      map: map == null ? null : DeliveryRouteMap.fromJson(map),
      geoJson: geometry == null ? null : Map<String, dynamic>.from(geometry),
      stops: List.unmodifiable(stops),
    );
  }
}

String? _string(Object? value) {
  if (value == null) return null;
  if (value is! String) throw const ApiContractException('route.string');
  return value.trim().isEmpty ? null : value.trim();
}

int _integer(Object? value, String field) {
  if (value is! int || value < 0) throw ApiContractException(field);
  return value;
}

double? _number(Object? value) {
  if (value == null) return null;
  if (value is! num || !value.isFinite || value < 0) {
    throw const ApiContractException('route.number');
  }
  return value.toDouble();
}
