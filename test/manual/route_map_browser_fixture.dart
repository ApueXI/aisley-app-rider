// Browser renderer acceptance harness with synthetic data and an in-memory
// HTTP client. It never connects to a live API or reads secure token storage.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:aisley_app/app/courier_theme.dart';
import 'package:aisley_app/core/config/app_config.dart';
import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/core/security/courier_map_security.dart';
import 'package:aisley_app/core/security/token_storage.dart';
import 'package:aisley_app/features/delivery_route/domain/delivery_route_models.dart';
import 'package:aisley_app/shared/route_map/route_map_scope.dart';
import 'package:aisley_app/shared/route_map/route_map_view.dart';

import '../features/delivery_route/fixtures/route_fixtures.dart';

void main() => runApp(const _BrowserFixture());

class _FixtureStorage implements TokenStorage {
  @override
  Future<String?> read() async => 'synthetic-route-token';
  @override
  Future<void> write(String token) async {}
  @override
  Future<void> clear() async {}
}

class _BrowserFixture extends StatefulWidget {
  const _BrowserFixture();
  @override
  State<_BrowserFixture> createState() => _BrowserFixtureState();
}

class _BrowserFixtureState extends State<_BrowserFixture> {
  late final CourierMapSecurity security;
  var route = DeliveryRoute.fromResponse(finalRouteFixture());
  int styles = 0, tiles = 0, failures = 0;
  double shift = 0;

  @override
  void initState() {
    super.initState();
    const config = AppConfig(baseUrl: 'https://api.example');
    security = CourierMapSecurity(
      config: config,
      client: ApiClient(
        config: config,
        tokenStorage: _FixtureStorage(),
        client: MockClient((request) async {
          if (request.url.path.endsWith('/map-style')) {
            setState(() => styles++);
            return http.Response(jsonEncode(styleFixture()), 200);
          }
          setState(() => tiles++);
          return http.Response.bytes(
            base64Decode(
              'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGN49+7dfwAJYgPK1Rd34wAAAABJRU5ErkJggg==',
            ),
            200,
            headers: {
              'content-type': 'image/png',
              'cache-control': 'private, no-store',
            },
          );
        }),
      ),
    );
  }

  @override
  void dispose() {
    security.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RouteMapScope(
    security: security,
    child: MaterialApp(
      theme: buildCourierTheme(Brightness.light),
      home: Scaffold(
        appBar: AppBar(title: const Text('Synthetic map fixture')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('No live API or account data is used.'),
            RouteMapView(
              data: route.mapData,
              onFailure: (_) => setState(() => failures++),
            ),
            Text(
              'Fixture results: $styles styles, $tiles tiles, $failures failures.',
            ),
            TextButton(
              onPressed: () {
                final fixture = finalRouteFixture();
                final data = fixture['data'] as Map<String, dynamic>;
                shift += 0.05;
                (data['stops'] as List).last['longitude'] = 121.2 + shift;
                (data['stops'] as List).last['latitude'] = 14.7 + shift;
                ((data['geojson'] as Map)['features'] as List)
                    .first['geometry']['coordinates'][2] = [
                  121.2 + shift,
                  14.7 + shift,
                ];
                setState(() => route = DeliveryRoute.fromResponse(fixture));
              },
              child: const Text('Change fixture geometry'),
            ),
            TextButton(
              onPressed: security.invalidate,
              child: const Text('Invalidate fixture session'),
            ),
          ],
        ),
      ),
    ),
  );
}
