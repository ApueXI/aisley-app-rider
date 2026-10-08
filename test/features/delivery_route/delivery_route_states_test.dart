import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/features/delivery_route/data/delivery_route_repository.dart';
import 'package:aisley_app/features/delivery_route/domain/delivery_route_models.dart';
import 'package:aisley_app/features/delivery_route/presentation/delivery_route_controller.dart';
import 'package:aisley_app/features/delivery_route/presentation/delivery_route_screen.dart';

import '../../helpers/accessibility.dart';
import '../batch/fixtures/final_mile_batch_screen_fixture.dart';
import 'fixtures/route_fixtures.dart';

class _StateRoutes implements DeliveryRouteRepository {
  _StateRoutes({this.status = 'ready'});
  final String status;
  ApiException? error;
  int calls = 0;
  @override
  Future<DeliveryRoute> fetchRoute(String id) async {
    calls++;
    if (error != null) throw error!;
    return DeliveryRoute.fromResponse(finalRouteFixture(status: status));
  }
}

void main() {
  final scenario = AccessibilityScenario.stress.last;
  final errors = <(ApiException, String)>[
    (
      const ApiException(statusCode: 403, code: 'FORBIDDEN', message: 'test'),
      'This route is not available',
    ),
    (
      const ApiException(statusCode: 404, code: 'NOT_FOUND', message: 'test'),
      'This delivery route is no longer',
    ),
    (
      const ApiException(
        statusCode: 409,
        code: 'BATCH_STATE_CONFLICT',
        message: 'test',
      ),
      'This batch changed',
    ),
    (
      const ApiException(
        statusCode: 422,
        code: 'VALIDATION_ERROR',
        message: 'test',
      ),
      'The route request could not be accepted',
    ),
    (
      const ApiException(
        statusCode: 429,
        code: 'THROTTLED',
        message: 'test',
        retryAfter: Duration(seconds: 10),
      ),
      'Too many requests',
    ),
    (
      ApiException.network('test', networkFailure: ApiNetworkFailure.offline),
      'You are offline',
    ),
    (
      ApiException.network('test', networkFailure: ApiNetworkFailure.timeout),
      'The route request timed out',
    ),
  ];
  for (final (error, message) in errors) {
    accessibilityTest(
      'route recovery ${error.statusCode ?? error.networkFailure}: ${scenario.name}',
      scenario,
      (tester) async {
        final batch =
            (await (WidgetBatchRepository()..accepted = true).fetchBatches())
                .single;
        final repository = _StateRoutes();
        final controller = DeliveryRouteController(repository: repository);
        await tester.pumpWidget(
          scenario.app(
            DeliveryRouteScreen(batch: batch, controller: controller),
          ),
        );
        await tester.pumpAndSettle();
        repository.error = error;
        await controller.load(batch.id, refresh: true);
        await tester.pumpAndSettle();
        expect(find.textContaining(message), findsOneWidget);
        if (error.statusCode == null) {
          await reveal(tester, find.text('Area two'));
          expect(find.text('Area two'), findsOneWidget);
        }
        await checkScrollableAccessibility(tester);
        final refresh = find.widgetWithText(TextButton, 'Refresh route');
        await reveal(tester, refresh);
        expect(
          tester.widget<TextButton>(refresh).onPressed == null,
          error.statusCode == 429,
        );
        await unmount(tester, [controller]);
      },
    );
  }
  for (final status in ['pending', 'unavailable', 'future']) {
    accessibilityTest('route response $status: ${scenario.name}', scenario, (
      tester,
    ) async {
      final batch =
          (await (WidgetBatchRepository()..accepted = true).fetchBatches())
              .single;
      final repository = _StateRoutes(status: status);
      final controller = DeliveryRouteController(repository: repository);
      await tester.pumpWidget(
        scenario.app(DeliveryRouteScreen(batch: batch, controller: controller)),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining(switch (status) {
          'pending' => 'being prepared',
          'unavailable' => 'Partial route',
          _ => 'unsupported',
        }),
        findsOneWidget,
      );
      await reveal(tester, find.text('Area two'));
      expect(find.text('Area two'), findsOneWidget);
      await checkScrollableAccessibility(tester);
      await tester.pump(const Duration(minutes: 1));
      expect(
        repository.calls,
        1,
        reason: 'Route responses do not trigger polling',
      );
      await unmount(tester, [controller]);
    });
  }
}
