import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:aisley_app/core/config/app_config.dart';
import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/core/networking/api_contract_exception.dart';
import 'package:aisley_app/core/security/courier_map_security.dart';
import 'package:aisley_app/core/security/token_storage.dart';

import 'delivery_route_contract_test.dart' show RouteTestStorage;
import 'fixtures/route_fixtures.dart';

void main() {
  const config = AppConfig(baseUrl: 'https://api.example');
  CourierMapSecurity security({
    Future<http.Response> Function(http.Request)? handler,
    RouteTestStorage? storage,
  }) => CourierMapSecurity(
    config: config,
    client: ApiClient(
      config: config,
      tokenStorage: storage ?? RouteTestStorage(),
      client: MockClient(
        handler ?? (_) async => http.Response(jsonEncode(styleFixture()), 200),
      ),
    ),
  );
  test('raw authenticated style is parsed without data envelope', () async {
    final map = security(
      handler: (request) async {
        expect(request.url.path, '/api/v1/courier/map-style');
        expect(request.followRedirects, false);
        expect(
          request.headers['authorization'],
          'Bearer synthetic-route-token',
        );
        return http.Response(jsonEncode(styleFixture()), 200);
      },
    );
    expect(await map.loadStyle(), 18);
    map.dispose();
  });
  test('tile URL checks reject lookalike hosts paths queries and alternate schemes', () {
    final map = security();
    expect(
      map.acceptsTileUrl(
        'https://api.example/api/v1/courier/map-tiles/10/123/45.png',
      ),
      true,
    );
    expect(map.validateStyle(styleFixture()), 18);
    for (final url in [
      'https://api.example.evil/api/v1/courier/map-tiles/1/0/0.png',
      'https://api.example@evil/api/v1/courier/map-tiles/1/0/0.png',
      'http://api.example/api/v1/courier/map-tiles/1/0/0.png',
      'https://api.example:444/api/v1/courier/map-tiles/1/0/0.png',
      'https://api.example/api/v1/courier/map-tiles-extra/1/0/0.png',
      'https://api.example/api/v1/courier/map-tiles/1/0/0.png/evil',
      'https://api.example/api/v1/courier/map-tiles/1/0/0.png?url=evil',
      'https://api.example/api/v1/courier/map-tiles/1/0/0.png#fragment',
      'https://api.example/api/v1/courier/map-tiles/%2e%2e/0/0.png',
    ]) {
      expect(map.acceptsTileUrl(url), false, reason: url);
    }
    map.dispose();
  });
  test(
    'reject all undeclared style resources before the SDK can request them',
    () {
      final map = security();
      for (final key in ['sprite', 'glyphs', 'imports', 'terrain']) {
        final style = styleFixture()
          ..[key] = 'https://evil/credential-collector';
        expect(
          () => map.validateStyle(style),
          throwsA(isA<ApiContractException>()),
        );
      }
      for (final url in [
        'https://api.example.evil/api/v1/courier/map-tiles/{z}/{x}/{y}.png',
        'https://api.example/api/v1/courier/map-tiles/{z}/{x}/{y}.png?key=test',
      ]) {
        expect(
          () => map.validateStyle(styleFixture(url)),
          throwsA(isA<ApiContractException>()),
        );
      }
      final style = styleFixture();
      (style['sources'] as Map)['extra'] = {
        'type': 'vector',
        'url': 'https://evil',
      };
      expect(
        () => map.validateStyle(style),
        throwsA(isA<ApiContractException>()),
      );
      map.dispose();
    },
  );
  test('tile requests authenticate only the fixed API path, no redirects or SDK headers', () async {
    final map = security(
      handler: (request) async {
        expect(
          request.url.toString(),
          'https://api.example/api/v1/courier/map-tiles/1/0/1.png',
        );
        expect(request.followRedirects, false);
        expect(request.headers['cache-control'], 'no-store');
        expect(
          request.headers['authorization'],
          'Bearer synthetic-route-token',
        );
        return http.Response.bytes([137, 80, 78, 71, 13, 10, 26, 10, 0], 200);
      },
    );
    expect((await map.tile(1, 0, 1)).length, 9);
    await expectLater(map.tile(1, 2, 1), throwsA(isA<ApiContractException>()));
    map.dispose();
  });
  test('session invalidation discards a late tile response', () async {
    final pending = Completer<http.Response>();
    final map = security(handler: (_) => pending.future);
    final result = map.tile(1, 0, 0);
    final check = expectLater(result, throwsA(isA<MapSessionEnded>()));
    map.invalidate();
    pending.complete(
      http.Response.bytes([137, 80, 78, 71, 13, 10, 26, 10, 0], 200),
    );
    await check;
    map.dispose();
  });
  test('storage failure never becomes map or screen token state', () async {
    final map = security(storage: RouteTestStorage()..fail = true);
    await expectLater(map.loadStyle(), throwsA(isA<TokenStorageException>()));
    map.dispose();
  });
  test('disposal discards a late style response', () async {
    final pending = Completer<http.Response>();
    final map = security(handler: (_) => pending.future);
    final read = map.loadStyle();
    final check = expectLater(read, throwsA(isA<MapSessionEnded>()));
    map.dispose();
    pending.complete(http.Response(jsonEncode(styleFixture()), 200));
    await check;
  });
  test('Retry-After accepts seconds and HTTP dates', () {
    final response = http.Response('{}', 429, headers: {'retry-after': '60'});
    expect(
      ApiException.fromResponse(response).retryAfter,
      const Duration(seconds: 60),
    );
    expect(
      ApiException.fromResponse(
        http.Response(
          '{}',
          429,
          headers: {'retry-after': 'Wed, 01 Jan 2099 00:00:00 GMT'},
        ),
      ).retryAfter!.inDays,
      greaterThan(100),
    );
  });
}
