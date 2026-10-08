import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:aisley_app/core/config/app_config.dart';
import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/core/security/token_storage.dart';
import 'package:aisley_app/features/delivery_route/data/delivery_route_repository.dart';
import 'package:aisley_app/features/delivery_route/domain/delivery_route_models.dart';
import 'package:aisley_app/features/pickup/domain/pickup_models.dart';
import 'package:aisley_app/shared/route_map/route_map_data.dart';

import 'fixtures/route_fixtures.dart';

class RouteTestStorage implements TokenStorage {
  String? token = 'synthetic-route-token';
  bool fail = false;
  @override
  Future<String?> read() async {
    if (fail) throw TokenStorageException('read', StateError('test'));
    return token;
  }

  @override
  Future<void> write(String value) async {
    token = value;
  }

  @override
  Future<void> clear() async {
    token = null;
  }
}

void main() {
  test(
    'nested first-mile tasks and metres/seconds match backend; hub returns',
    () {
      final manifest = PickupRouteManifest.fromResponse(pickupRouteFixture());
      expect(manifest.scheduleId, 'schedule-1');
      expect(manifest.stops[1].taskIds, ['task-1', 'task-2']);
      expect(manifest.stops[1].orderReferences, ['ORD-1', 'ORD-2']);
      expect(manifest.stops[1].waybillReferences, ['WB-1', 'WB-2']);
      expect(manifest.stops[1].legDistanceMeters, 1234);
      expect(manifest.stops[1].legTimeSeconds, 321);
      expect(manifest.stops.last.isHub, isTrue);
      final map = RouteMapData.sanitized(
        geoJson: manifest.geoJson,
        markers: [],
      );
      expect(map.line.first.longitude, 121);
      expect(map.line.first.latitude, 14.5);
      expect(map.line.last.longitude, map.line.first.longitude);
    },
  );
  test('nullable unavailable pickup and unreachable stops remain truthful', () {
    final fixture = pickupRouteFixture();
    final data = fixture['data'] as Map;
    (data['stops'] as List)[1]['reachable'] = false;
    (data['stops'] as List)[1]['leg_distance_metres'] = null;
    var manifest = PickupRouteManifest.fromResponse(fixture);
    expect(manifest.stops[1].reachable, false);
    expect(manifest.stops[1].legDistanceMeters, isNull);
    data.addAll(<String, dynamic>{
      'status': 'unavailable',
      'stops': [],
      'geojson': null,
      'calculated_at': null,
      'reason': 'provider_timeout',
    });
    manifest = PickupRouteManifest.fromResponse(fixture);
    expect(manifest.geoJson, isNull);
    expect(manifest.status, RouteManifestStatus.unavailable);
  });
  test(
    'final summary fields and server order are preserved without a hub return',
    () {
      final route = DeliveryRoute.fromResponse(finalRouteFixture());
      expect(route.summary!.stopCount, 2);
      expect(route.summary!.distanceMetres, 2345);
      expect(route.summary!.durationSeconds, 456);
      expect(route.stops.map((s) => s.taskId), [null, 'task-2', 'task-1']);
      expect(route.mapData.markers.map((m) => m.label), ['H', '1', '2']);
      expect(route.mapData.line.last.latitude, 14.7);
      expect(route.reason, isNull);
    },
  );
  test(
    'unavailable routes keep known locations and labelled server fallback',
    () {
      final route = DeliveryRoute.fromResponse(
        finalRouteFixture(
          status: 'unavailable',
          source: 'stop_sequence_fallback',
        ),
      );
      expect(route.summary, isNull);
      expect(route.mapData.isFallback, true);
      expect(route.mapData.markers.length, 3);
      final data = finalRouteFixture()['data'] as Map;
      data.addAll(<String, dynamic>{
        'status': 'unavailable',
        'reason': 'missing_hub_coordinates',
        'summary': null,
        'geojson': null,
        'map': null,
        'stops': [],
      });
      expect(DeliveryRoute.fromResponse({'data': data}).map, isNull);
    },
  );
  test('missing invalid or zero coordinates never create positions', () {
    for (final pair in [
      [null, 14.5],
      [121, null],
      [181, 14],
      [121, 91],
      [0, 0],
      [double.nan, 14],
    ]) {
      expect(RoutePosition.parse(pair[0], pair[1]), isNull);
    }
    final data = finalRouteFixture()['data'] as Map;
    data['stops'][1]['longitude'] = null;
    final route = DeliveryRoute.fromResponse({'data': data});
    expect(route.mapData.markers.length, 2);
    expect(route.stops.length, 3);
  });
  test(
    'unknown state is retained; unknown/malformed geometry draws no line',
    () {
      expect(
        DeliveryRoute.fromResponse(finalRouteFixture(status: 'future')).status,
        DeliveryRouteStatus.unknown,
      );
      expect(
        DeliveryRoute.fromResponse(finalRouteFixture(source: 'unapproved'))
            .mapData
            .line,
        isEmpty,
      );
      final data = finalRouteFixture()['data'] as Map;
      data['geojson']['features'][0]['geometry']['coordinates'][1] = [
        181,
        14.5,
      ];
      expect(DeliveryRoute.fromResponse({'data': data}).mapData.line, isEmpty);
    },
  );
  test(
    'route repository uses exact authenticated GET with no mutation',
    () async {
      final api = ApiClient(
        config: const AppConfig(baseUrl: 'https://api.example'),
        tokenStorage: RouteTestStorage(),
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(
            request.url.path,
            '/api/v1/courier/final-mile-batches/schedule-1/route',
          );
          expect(
            request.headers['authorization'],
            'Bearer synthetic-route-token',
          );
          expect(request.headers['cache-control'], 'no-store');
          return http.Response(jsonEncode(finalRouteFixture()), 200);
        }),
      );
      final route = await ApiDeliveryRouteRepository(client: api)
          .fetchRoute('schedule-1');
      expect(route.status, DeliveryRouteStatus.ready);
    },
  );
}
