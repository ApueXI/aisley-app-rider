/// Sanitized presentation data. No task IDs, addresses, or credentials enter
/// the map SDK; geographic positions are already authorized by the route read.
class RoutePosition {
  const RoutePosition(this.longitude, this.latitude);
  final double longitude;
  final double latitude;

  @override
  bool operator ==(Object other) =>
      other is RoutePosition &&
      longitude == other.longitude &&
      latitude == other.latitude;
  @override
  int get hashCode => Object.hash(longitude, latitude);

  static RoutePosition? parse(Object? longitude, Object? latitude) {
    final lng = double.tryParse(longitude?.toString() ?? '');
    final lat = double.tryParse(latitude?.toString() ?? '');
    if (lng == null ||
        lat == null ||
        !lng.isFinite ||
        !lat.isFinite ||
        lng.abs() > 180 ||
        lat.abs() > 90 ||
        (lng == 0 && lat == 0)) {
      return null;
    }
    return RoutePosition(lng, lat);
  }
}

class RouteMarker {
  const RouteMarker({
    required this.position,
    required this.label,
    this.isHub = false,
  });
  final RoutePosition position;
  final String label;
  final bool isHub;

  @override
  bool operator ==(Object other) =>
      other is RouteMarker &&
      position == other.position &&
      label == other.label &&
      isHub == other.isHub;
  @override
  int get hashCode => Object.hash(position, label, isHub);
}

class RouteMapData {
  const RouteMapData({
    this.markers = const [],
    this.line = const [],
    this.geometrySource,
  });
  final List<RouteMarker> markers;
  final List<RoutePosition> line;
  final String? geometrySource;
  bool get isFallback => geometrySource == 'stop_sequence_fallback';
  List<RoutePosition> get positions => [
    ...line,
    ...markers.map((m) => m.position),
  ];

  factory RouteMapData.sanitized({
    required Object? geoJson,
    required List<RouteMarker> markers,
  }) {
    final rawFeatures = geoJson is Map ? geoJson['features'] : null;
    if (rawFeatures is List) {
      for (final feature in rawFeatures.take(64)) {
        if (feature is! Map) continue;
        final geometry = feature['geometry'];
        final properties = feature['properties'];
        if (geometry is! Map ||
            properties is! Map ||
            properties['kind'] != 'route_line' ||
            geometry['type'] != 'LineString') {
          continue;
        }
        final source = properties['geometry_source'];
        if (source != 'geoapify_routing' &&
            source != 'stop_sequence_fallback') {
          continue;
        }
        final raw = geometry['coordinates'];
        if (raw is! List || raw.length < 2 || raw.length > 10000) continue;
        final line = <RoutePosition>[];
        for (final pair in raw) {
          if (pair is! List || pair.length != 2) break;
          final position = RoutePosition.parse(pair[0], pair[1]);
          if (position == null) break;
          line.add(position);
        }
        if (line.length == raw.length) {
          return RouteMapData(
            markers: List.unmodifiable(markers),
            line: List.unmodifiable(line),
            geometrySource: source as String,
          );
        }
      }
    }
    return RouteMapData(markers: List.unmodifiable(markers));
  }
}
