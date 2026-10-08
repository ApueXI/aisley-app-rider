// Synthetic values using the exact resource shapes at Laravel 51d9694.
// Sources: FinalMileRouteService, PickupRouteManifestController, and
// BuildPickupRouteManifest. This is contract evidence, not a live API capture.
import 'dart:convert';

Map<String, dynamic> finalRouteFixture({
  String status = 'ready',
  String source = 'geoapify_routing',
}) => _json({
  'data': {
    'status': status,
    'reason': status == 'ready' ? null : 'missing_destination_coordinates',
    'summary': status == 'ready'
        ? {'stop_count': 2, 'distance_metres': 2345, 'duration_seconds': 456}
        : null,
    'stops': [
      {
        'sequence': 0,
        'kind': 'hub',
        'task_id': null,
        'label': 'Logistics hub',
        'longitude': 121.0,
        'latitude': 14.5,
      },
      {
        'sequence': 1,
        'kind': 'delivery',
        'task_id': 'task-2',
        'label': 'Area two',
        'longitude': 121.1,
        'latitude': 14.6,
      },
      {
        'sequence': 2,
        'kind': 'delivery',
        'task_id': 'task-1',
        'label': 'Area one',
        'longitude': 121.2,
        'latitude': 14.7,
      },
    ],
    'geojson': {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              [121.0, 14.5],
              [121.1, 14.6],
              [121.2, 14.7],
            ],
          },
          'properties': {'kind': 'route_line', 'geometry_source': source},
        },
      ],
    },
    'map': {
      'style_url': '/api/v1/courier/map-style',
      'attribution': ['Geoapify', 'OpenStreetMap contributors', 'OpenMapTiles'],
    },
  },
});

Map<String, dynamic> pickupRouteFixture() {
  final data = finalRouteFixture()['data'] as Map<String, dynamic>;
  data['schedule'] = {
    'id': 'schedule-1',
    'reference': 'PICK-1',
    'starts_at': '2026-10-08T00:00:00Z',
    'ends_at': '2026-10-08T04:00:00Z',
    'timezone': 'UTC',
    'order_count': 2,
  };
  data['revision'] = 2;
  data['coordinate_source'] = 'exact';
  data['calculated_at'] = '2026-10-08T00:00:00Z';
  data['summary'] = {
    'pickup_stop_count': 1,
    'parcel_count': 2,
    'unreachable_stop_count': 0,
    'distance_metres': 3456,
    'duration_seconds': 678,
    'estimated_credits': 4,
    'heuristic': 'nearest_next_stop',
    'returns_to_hub': true,
  };
  data['stops'] = [
    {
      'sequence': 0,
      'kind': 'hub',
      'tasks': [],
      'latitude': 14.5,
      'longitude': 121.0,
      'address_summary': 'Hub area',
      'coordinate_source': 'exact',
      'leg_distance_metres': 0,
      'leg_duration_seconds': 0,
      'reachable': true,
    },
    {
      'sequence': 1,
      'kind': 'pickup',
      'tasks': [
        {
          'task_id': 'task-1',
          'order_id': 'order-1',
          'order_reference': 'ORD-1',
          'waybill_reference': 'WB-1',
          'tracking_id': 'WB-1',
        },
        {
          'task_id': 'task-2',
          'order_id': 'order-2',
          'order_reference': 'ORD-2',
          'waybill_reference': 'WB-2',
          'tracking_id': 'WB-2',
        },
      ],
      'latitude': 14.6,
      'longitude': 121.1,
      'address_summary': 'Seller area',
      'coordinate_source': 'address_default',
      'leg_distance_metres': 1234,
      'leg_duration_seconds': 321,
      'reachable': true,
    },
    {
      'sequence': 2,
      'kind': 'hub',
      'tasks': [],
      'latitude': 14.5,
      'longitude': 121.0,
      'address_summary': 'Hub area',
      'coordinate_source': 'exact',
      'leg_distance_metres': 2222,
      'leg_duration_seconds': 357,
      'reachable': true,
    },
  ];
  data['geojson'] = {
    'type': 'FeatureCollection',
    'features': [
      {
        'type': 'Feature',
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            [121.0, 14.5],
            [121.1, 14.6],
            [121.0, 14.5],
          ],
        },
        'properties': {
          'kind': 'route_line',
          'geometry_source': 'geoapify_routing',
        },
      },
    ],
  };
  return _json({'data': data});
}

Map<String, dynamic> styleFixture([
  String tile = 'https://api.example/api/v1/courier/map-tiles/{z}/{x}/{y}.png',
]) => {
  'version': 8,
  'name': 'Aisley Courier Pickup Map',
  'sources': {
    'geoapify': {
      'type': 'raster',
      'tiles': [tile],
      'tileSize': 256,
      'maxzoom': 18,
      'attribution':
          'Powered by Geoapify | © OpenStreetMap contributors | © OpenMapTiles',
    },
  },
  'layers': [
    {'id': 'geoapify-base', 'type': 'raster', 'source': 'geoapify'},
  ],
};

Map<String, dynamic> _json(Map<String, dynamic> value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
