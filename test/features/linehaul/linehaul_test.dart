import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:aisley_app/core/config/app_config.dart';
import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/core/networking/api_contract_exception.dart';
import 'package:aisley_app/core/security/token_storage.dart';
import 'package:aisley_app/features/linehaul/data/linehaul_repository.dart';
import 'package:aisley_app/features/linehaul/domain/linehaul_trip.dart';
import 'package:aisley_app/features/linehaul/domain/linehaul_route.dart';
import 'package:aisley_app/features/linehaul/presentation/linehaul_controller.dart';
import 'package:aisley_app/features/linehaul/presentation/linehaul_screen.dart';

import '../../helpers/accessibility.dart';
import '../delivery/fixtures/delivery_screen_fixture.dart';
import 'linehaul_fixture.dart';

class Tokens implements TokenStorage {
  @override
  Future<String?> read() async => 'synthetic-token';
  @override
  Future<void> write(String value) async {}
  @override
  Future<void> clear() async {}
}

void main() {
  test('exact Courier bearer paths and strict confirmation body', () async {
    final requests = <http.Request>[];
    final repo = ApiLinehaulRepository(
      ApiClient(
        config: const AppConfig(baseUrl: 'https://api.example.test'),
        tokenStorage: Tokens(),
        client: MockClient((r) async {
          requests.add(r);
          return http.Response(
            jsonEncode({
              'data': r.url.path.endsWith('/linehaul-trips')
                  ? [tripJson()]
                  : r.url.path.endsWith('/route')
                  ? routeJson()
                  : tripJson(status: 'in_transfer'),
            }),
            200,
          );
        }),
      ),
    );
    await repo.trips();
    await repo.route('trip-1');
    await repo.confirm('trip-1', 'depart', 3);
    await repo.confirm('trip-1', 'arrival', 3);
    expect(requests.map((r) => r.url.path), [
      '/api/v1/courier/linehaul-trips',
      '/api/v1/courier/linehaul-trips/trip-1/route',
      '/api/v1/courier/linehaul-trips/trip-1/depart',
      '/api/v1/courier/linehaul-trips/trip-1/arrival',
    ]);
    for (final r in requests) {
      expect(r.headers['authorization'], 'Bearer synthetic-token');
      expect(r.headers.containsKey('cookie'), false);
      expect(r.headers.containsKey('idempotency-key'), false);
    }
    expect(jsonDecode(requests[2].body), {
      'expected_revision': 3,
      'confirmation': true,
    });
  });
  test(
    'strict DTO nullability, enums, geometry and no invented fallback metrics',
    () {
      final trip = LinehaulTrip.fromJson(
        tripJson(direction: 'return', empty: true),
      );
      expect(trip.emptyReturn, true);
      expect(trip.arrivedAt, isNull);
      expect(
        () => LinehaulTrip.fromJson({...tripJson(), 'revision': null}),
        throwsA(isA<ApiContractException>()),
      );
      expect(
        () => LinehaulTrip.fromJson({...tripJson(), 'status': 'arrived'}),
        throwsA(isA<ApiContractException>()),
      );
      final missing = routeJson(ready: false);
      (missing['hubs'] as List)[0]['latitude'] = null;
      final route = LinehaulRoute.fromJson(missing);
      expect(route.map.line, isEmpty);
      expect(route.distanceMetres, isNull);
      expect(route.map.markers, hasLength(1));
      final broken = routeJson();
      broken['geometry'] = {
        'type': 'LineString',
        'coordinates': [
          [121, 14],
          [999, 14],
        ],
      };
      expect(
        () => LinehaulRoute.fromJson(broken),
        throwsA(isA<ApiContractException>()),
      );
    },
  );
  test(
    'released driver departure and arrival preserve receiving authority',
    () async {
      final repo = FakeLinehaulRepository();
      final c = LinehaulController(repo);
      addTearDown(c.dispose);
      await c.load();
      expect(await c.confirm('depart'), true);
      expect(c.selected!.status, 'in_transfer');
      expect(await c.confirm('arrival'), true);
      expect(c.selected!.statusLabel, 'Arrival reported');
      expect(c.selected!.status, 'in_transfer');
      expect(c.selected!.unloadingClosedAt, isNull);
      expect(await c.confirm('arrival'), false);
    },
  );
  test(
    'unreleased departure is unavailable even before scheduled time',
    () async {
      final repo = FakeLinehaulRepository()
        ..current = tripJson(released: false);
      final c = LinehaulController(repo);
      addTearDown(c.dispose);
      await c.load();
      expect(await c.confirm('depart'), false);
      expect(repo.calls, isEmpty);
    },
  );
  for (final failure in [
    const ApiException.network('offline'),
    const ApiException(
      statusCode: 503,
      code: 'UNAVAILABLE',
      message: 'failure',
    ),
    const ApiContractException('reply'),
  ]) {
    test('uncertain confirmation preserves action/body $failure', () async {
      final repo = FakeLinehaulRepository()..actionError = failure;
      final c = LinehaulController(repo);
      addTearDown(c.dispose);
      await c.load();
      expect(await c.confirm('depart'), false);
      expect(c.uncertain, true);
      expect(await c.confirm('arrival'), false);
      repo.actionError = null;
      expect(await c.retry(), true);
      expect(repo.calls[0], repo.calls[1]);
    });
  }
  test('refresh reconciles lost departure receipt without resending', () async {
    final repo = FakeLinehaulRepository()
      ..actionError = const ApiException.network('lost reply');
    final c = LinehaulController(repo);
    addTearDown(c.dispose);
    await c.load();
    await c.confirm('depart');
    repo.current = tripJson(status: 'in_transfer');
    await c.load();
    expect(c.uncertain, false);
    expect(repo.calls, hasLength(1));
  });
  test('conflict refresh requires a new explicit decision', () async {
    final repo = FakeLinehaulRepository()
      ..actionError = const ApiException(
        statusCode: 409,
        code: 'LINEHAUL_TRIP_CHANGED',
        message: 'changed',
      );
    final c = LinehaulController(repo);
    addTearDown(c.dispose);
    await c.load();
    expect(await c.confirm('depart'), false);
    expect(c.uncertain, false);
    expect(c.error, contains('Review'));
    expect(repo.calls, hasLength(1));
  });
  for (final status in [401, 403, 404]) {
    test('denied trip clears private details $status', () async {
      var denied = 0;
      final repo = FakeLinehaulRepository();
      final c = LinehaulController(
        repo,
        onAuthFailure: (_) async {
          denied++;
        },
      );
      addTearDown(c.dispose);
      await c.load();
      repo.routeError = ApiException(
        statusCode: status,
        code: 'DENIED',
        message: 'no',
      );
      await c.loadRoute();
      expect(c.trips, isEmpty);
      expect(c.route, isNull);
      expect(denied, status == 404 ? 0 : 1);
    });
  }
  test('route quota never blocks driver actions', () async {
    final repo = FakeLinehaulRepository()
      ..routeError = const ApiException(
        statusCode: 429,
        code: 'THROTTLED',
        message: 'wait',
      );
    final c = LinehaulController(repo);
    addTearDown(c.dispose);
    await c.load();
    expect(c.routeError, isNotNull);
    expect(c.routeCoolingDown, true);
    await c.loadRoute();
    expect(repo.routeReads, 1);
    expect(await c.confirm('depart'), true);
  });
  test(
    'late reads and writes after session loss cannot restore private data',
    () async {
      final repo = FakeLinehaulRepository();
      final c = LinehaulController(repo);
      addTearDown(c.dispose);
      await c.load();
      repo.pendingAction = Completer<LinehaulTrip>();
      final request = c.confirm('depart');
      expect(await c.confirm('depart'), false);
      c.clear();
      repo.pendingAction!.complete(
        LinehaulTrip.fromJson(tripJson(status: 'in_transfer')),
      );
      expect(await request, false);
      expect(c.trips, isEmpty);
      expect(c.route, isNull);
    },
  );
  test('failed refresh removes stale details', () async {
    final repo = FakeLinehaulRepository();
    final c = LinehaulController(repo);
    addTearDown(c.dispose);
    await c.load();
    repo.readError = const ApiException.network('offline');
    await c.load();
    expect(c.trips, isEmpty);
    expect(c.route, isNull);
    expect(c.error, isNotNull);
  });
  for (final scenario in AccessibilityScenario.matrix) {
    accessibilityTest(
      'linehaul confirmation and fallback ${scenario.name}',
      scenario,
      (tester) async {
        final repo = FakeLinehaulRepository()
          ..routeError = const ApiException.network('provider');
        final c = LinehaulController(repo);
        final auth = deliveryAuthController();
        await tester.pumpWidget(
          scenario.app(LinehaulScreen(controller: c, authController: auth)),
        );
        await tester.pumpAndSettle();
        await checkScrollableAccessibility(tester);
        await reveal(tester, find.text('Depart'));
        await tester.tap(find.text('Depart'));
        await tester.pumpAndSettle();
        expect(repo.calls, isEmpty);
        expect(find.text('Confirm departure?'), findsOneWidget);
        await checkAccessibility(tester);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(repo.calls, isEmpty);
        await unmount(tester, [c, auth]);
      },
    );
  }
}
