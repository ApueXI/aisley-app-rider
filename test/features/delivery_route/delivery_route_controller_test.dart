import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/core/security/token_storage.dart';
import 'package:aisley_app/features/delivery_route/data/delivery_route_repository.dart';
import 'package:aisley_app/features/delivery_route/domain/delivery_route_models.dart';
import 'package:aisley_app/features/delivery_route/presentation/delivery_route_controller.dart';
import 'package:aisley_app/features/pickup/data/pickup_repository.dart';
import 'package:aisley_app/features/pickup/domain/pickup_models.dart';
import 'package:aisley_app/features/pickup/presentation/controllers/pickup_controller.dart';

import 'fixtures/route_fixtures.dart';

class FakeRouteRepository implements DeliveryRouteRepository {
  Object? error;
  int calls = 0;
  Completer<DeliveryRoute>? pending;
  @override
  Future<DeliveryRoute> fetchRoute(String id) async {
    calls++;
    if (pending != null) return pending!.future;
    if (error != null) throw error!;
    return DeliveryRoute.fromResponse(finalRouteFixture());
  }
}

class FakePickupRoutes implements PickupRepository {
  final reads = <Completer<PickupRouteManifest>>[];
  @override
  Future<PickupRouteManifest> fetchRouteManifest(String id) {
    final read = Completer<PickupRouteManifest>();
    reads.add(read);
    return read.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final (routeSeconds, tileSeconds) in [(10, 1), (1, 10)]) {
    testWidgets(
      'delivery route and tile cooldowns preserve the longer delay ($routeSeconds/$tileSeconds)',
      (tester) async {
        final repository = FakeRouteRepository();
        final controller = DeliveryRouteController(repository: repository);
        await controller.load('one');
        repository.error = ApiException(
          statusCode: 429,
          code: 'THROTTLED',
          message: 'test',
          retryAfter: Duration(seconds: routeSeconds),
        );
        await controller.mapFailure(
          'one',
          error: ApiException(
            statusCode: 429,
            code: 'THROTTLED',
            message: 'test',
            retryAfter: Duration(seconds: tileSeconds),
          ),
        );
        await tester.pump(const Duration(seconds: 2));
        expect(controller.canRetry, false);
        await tester.pump(const Duration(seconds: 9));
        expect(controller.canRetry, true);
        controller.dispose();
      },
    );
    testWidgets(
      'pickup route and tile cooldowns preserve the longer delay ($routeSeconds/$tileSeconds)',
      (tester) async {
        final repository = FakePickupRoutes();
        final controller = PickupController(pickupRepository: repository);
        final read = controller.loadRouteManifest('one');
        repository.reads.single.completeError(
          ApiException(
            statusCode: 429,
            code: 'THROTTLED',
            message: 'test',
            retryAfter: Duration(seconds: routeSeconds),
          ),
        );
        await read;
        controller.holdRouteRetry(Duration(seconds: tileSeconds));
        await tester.pump(const Duration(seconds: 2));
        expect(controller.canRetryRateLimit, false);
        await tester.pump(const Duration(seconds: 9));
        expect(controller.canRetryRateLimit, true);
        controller.dispose();
      },
    );
  }
  for (final entry in {
    401: DeliveryRouteLoadStatus.unauthorized,
    403: DeliveryRouteLoadStatus.forbidden,
    404: DeliveryRouteLoadStatus.unavailable,
    409: DeliveryRouteLoadStatus.conflict,
    422: DeliveryRouteLoadStatus.invalid,
    429: DeliveryRouteLoadStatus.rateLimited,
  }.entries) {
    test(
      '${entry.key} is a distinct route failure; auth cleanup receives confirmed errors',
      () async {
        final repository = FakeRouteRepository();
        final failures = <ApiException>[];
        final controller = DeliveryRouteController(
          repository: repository,
          onAuthFailure: (e) async {
            failures.add(e);
          },
        );
        await controller.load('one');
        repository.error = ApiException(
          statusCode: entry.key,
          code: 'TEST',
          message: 'synthetic',
          retryAfter: const Duration(seconds: 5),
        );
        await controller.load('one', refresh: true);
        expect(controller.status, entry.value);
        expect(failures.length, entry.key == 401 || entry.key == 403 ? 1 : 0);
        if (entry.key < 429) expect(controller.route, isNull);
        if (entry.key == 429) {
          final calls = repository.calls;
          await controller.retry('one');
          expect(repository.calls, calls);
          expect(controller.canRetry, false);
        }
        controller.dispose();
      },
    );
  }
  test('policy consent follows auth policy handling', () async {
    ApiException? failure;
    final repository = FakeRouteRepository()
      ..error = const ApiException(
        statusCode: 403,
        code: 'POLICY_CONSENT_REQUIRED',
        message: 'test',
      );
    final controller = DeliveryRouteController(
      repository: repository,
      onAuthFailure: (e) async {
        failure = e;
      },
    );
    await controller.load('one');
    expect(controller.status, DeliveryRouteLoadStatus.consentRequired);
    expect(failure!.code, 'POLICY_CONSENT_REQUIRED');
    controller.dispose();
  });
  for (final failure in ApiNetworkFailure.values) {
    test(
      '$failure retains last authorized stops with explicit failure',
      () async {
        final repository = FakeRouteRepository();
        final controller = DeliveryRouteController(repository: repository);
        await controller.load('one');
        final route = controller.route;
        repository.error = ApiException.network(
          'test',
          networkFailure: failure,
        );
        await controller.load('one', refresh: true);
        expect(controller.route, same(route));
        expect(
          controller.status,
          failure == ApiNetworkFailure.offline
              ? DeliveryRouteLoadStatus.offline
              : DeliveryRouteLoadStatus.timeout,
        );
        controller.dispose();
      },
    );
  }
  test('storage failure clears private route memory', () async {
    final repository = FakeRouteRepository();
    final controller = DeliveryRouteController(repository: repository);
    await controller.load('one');
    repository.error = TokenStorageException('read', StateError('test'));
    await controller.load('one', refresh: true);
    expect(controller.status, DeliveryRouteLoadStatus.storageFailure);
    expect(controller.route, isNull);
    controller.dispose();
  });
  test(
    'older response ignored after schedule change, refresh and logout',
    () async {
      final repository = FakeRouteRepository();
      final controller = DeliveryRouteController(repository: repository);
      final pending = Completer<DeliveryRoute>();
      repository.pending = pending;
      final old = controller.load('one');
      repository.pending = null;
      await controller.load('two', refresh: true);
      final current = controller.route;
      pending.complete(
        DeliveryRoute.fromResponse(finalRouteFixture(status: 'unavailable')),
      );
      await old;
      expect(controller.route, same(current));
      expect(controller.scheduleId, 'two');
      repository.pending = Completer<DeliveryRoute>();
      final logout = controller.load('two', refresh: true);
      controller.clear();
      repository.pending!.complete(current!);
      await logout;
      expect(controller.route, isNull);
      expect(controller.lastRefreshed, isNull);
      expect(controller.status, DeliveryRouteLoadStatus.idle);
      controller.dispose();
    },
  );
  test(
    'map failure preserves stops and revalidates; confirmed 401 clears session',
    () async {
      final repository = FakeRouteRepository();
      var failures = 0;
      late DeliveryRouteController controller;
      controller = DeliveryRouteController(
        repository: repository,
        onAuthFailure: (e) async {
          failures++;
          controller.clear();
        },
      );
      await controller.load('one');
      await controller.mapFailure('one');
      expect(controller.mapFailed, true);
      expect(controller.route!.stops.length, 3);
      expect(repository.calls, 2);
      repository.error = const ApiException(
        statusCode: 401,
        code: 'UNAUTHENTICATED',
        message: 'test',
      );
      await controller.mapFailure('one');
      expect(failures, 1);
      expect(controller.route, isNull);
      controller.dispose();
    },
  );
  test('pickup route rejects obsolete refresh and logout responses', () async {
    final repository = FakePickupRoutes();
    final controller = PickupController(pickupRepository: repository);
    final old = controller.loadRouteManifest('one');
    final newer = controller.loadRouteManifest('one', refresh: true);
    repository.reads[1].complete(
      const PickupRouteManifest(status: RouteManifestStatus.ready),
    );
    await newer;
    repository.reads[0].complete(
      const PickupRouteManifest(status: RouteManifestStatus.pending),
    );
    await old;
    expect(controller.routeManifests['one']!.status, RouteManifestStatus.ready);
    final logout = controller.loadRouteManifest('one');
    controller.clear();
    repository.reads.last.complete(
      const PickupRouteManifest(status: RouteManifestStatus.ready),
    );
    await logout;
    expect(controller.routeManifests, isEmpty);
    expect(controller.routeStatuses, isEmpty);
    controller.dispose();
  });
  test('tile throttling revalidates once and blocks manual refresh until Retry-After', () async {
    final repository = FakeRouteRepository();
    final controller = DeliveryRouteController(repository: repository);
    await controller.load('one');
    await controller.mapFailure(
      'one',
      error: const ApiException(
        statusCode: 429,
        code: 'THROTTLED',
        message: 'test',
        retryAfter: Duration(seconds: 10),
      ),
    );
    expect(repository.calls, 2);
    expect(controller.route, isNotNull);
    expect(controller.canRetry, false);
    await controller.retry('one');
    expect(repository.calls, 2);
    controller.clear();
    await controller.mapFailure('one');
    expect(repository.calls, 2);
    expect(controller.route, isNull);
    controller.dispose();
  });
  test(
    'pickup route leaves scope before late failure, with no restored error',
    () async {
      final repository = FakePickupRoutes();
      final controller = PickupController(pickupRepository: repository);
      final pending = controller.loadRouteManifest('one');
      controller.releaseRouteManifest('one');
      repository.reads.single.completeError(
        const ApiException(statusCode: 403, code: 'FORBIDDEN', message: 'test'),
      );
      await pending;
      expect(controller.routeErrors, isEmpty);
      controller.dispose();
    },
  );
}
