import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_app/core/config/app_config.dart';
import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/core/security/courier_map_security.dart';
import 'package:aisley_app/features/batch/presentation/controllers/final_mile_batch_controller.dart';
import 'package:aisley_app/features/batch/presentation/final_mile_batch_screen.dart';
import 'package:aisley_app/features/delivery_route/presentation/delivery_route_screen.dart';
import 'package:aisley_app/features/delivery_route/presentation/delivery_route_controller.dart';
import 'package:aisley_app/features/delivery_route/domain/delivery_route_models.dart';
import 'package:aisley_app/features/pickup/presentation/pickup_screen.dart';
import 'package:aisley_app/features/pickup/presentation/controllers/pickup_controller.dart';
import 'package:aisley_app/features/pickup/domain/pickup_models.dart';
import 'package:aisley_app/features/pickup/data/pickup_repository.dart';
import 'package:aisley_app/shared/route_map/route_map_scope.dart';

import '../../helpers/accessibility.dart';
import '../batch/fixtures/final_mile_batch_screen_fixture.dart';
import 'delivery_route_contract_test.dart' show RouteTestStorage;
import 'delivery_route_controller_test.dart' show FakeRouteRepository;
import 'fixtures/route_fixtures.dart';

class WidgetPickupRoutes implements PickupRepository {
  @override
  Future<PickupRouteManifest> fetchRouteManifest(String id) async =>
      PickupRouteManifest.fromResponse(pickupRouteFixture());
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  CourierMapSecurity security() => CourierMapSecurity(
    config: const AppConfig(baseUrl: 'https://api.example'),
    client: ApiClient(
      config: const AppConfig(baseUrl: 'https://api.example'),
      tokenStorage: RouteTestStorage(),
    ),
  );

  for (final scenario in AccessibilityScenario.matrix) {
    accessibilityTest(
      'delivery route and failed map: ${scenario.name}',
      scenario,
      (tester) async {
        final batch =
            (await (WidgetBatchRepository()..accepted = true).fetchBatches())
                .single;
        final repository = FakeRouteRepository();
        final controller = DeliveryRouteController(repository: repository);
        final mapSecurity = security();
        await tester.pumpWidget(
          RouteMapScope(
            security: mapSecurity,
            renderer: (context, data, onFailure) => SizedBox(
              height: 240,
              child: Column(
                children: [
                  const Text('Injected route map'),
                  TextButton(
                    onPressed: onFailure,
                    child: const Text('Simulate map failure'),
                  ),
                ],
              ),
            ),
            child: scenario.app(
              DeliveryRouteScreen(batch: batch, controller: controller),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('Last refreshed'), findsOneWidget);
        expect(find.textContaining('Calculated'), findsNothing);
        await tester.scrollUntilVisible(find.text('Area two'), 200);
        expect(find.text('Area two'), findsOneWidget);
        await checkScrollableAccessibility(tester);
        final mapFailureButton = find.widgetWithText(
          TextButton,
          'Simulate map failure',
        );
        await reveal(tester, mapFailureButton);
        await tester.ensureVisible(mapFailureButton);
        await tester.pumpAndSettle();
        await tester.tap(mapFailureButton);
        await tester.pumpAndSettle();
        expect(controller.mapFailed, true);
        expect(controller.route!.stops.length, 3);
        expect(
          find.text(
            'Map could not be loaded. Route stops remain available below.',
          ),
          findsOneWidget,
        );
        await tester.scrollUntilVisible(find.text('Area two'), 200);
        expect(find.text('Area two'), findsOneWidget);
        expect(repository.calls, 2);
        await checkScrollableAccessibility(tester);
        await unmount(tester, [controller, mapSecurity]);
      },
    );
  }
  for (final scenario in AccessibilityScenario.stress) {
    accessibilityTest(
      'pickup map above preserved stop list: ${scenario.name}',
      scenario,
      (tester) async {
        final controller = PickupController(
          pickupRepository: WidgetPickupRoutes(),
        );
        final mapSecurity = security();
        await tester.pumpWidget(
          RouteMapScope(
            security: mapSecurity,
            renderer: (context, data, onFailure) {
              expect(data.markers.map((m) => m.label), ['H', '1', 'H']);
              expect(data.line.last.latitude, data.line.first.latitude);
              return const SizedBox(
                height: 200,
                child: Text('Injected pickup map'),
              );
            },
            child: scenario.app(
              PickupRouteScreen(
                pickupController: controller,
                scheduleId: 'schedule-1',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('Orders: ORD-1, ORD-2'), 200);
        expect(find.text('Orders: ORD-1, ORD-2'), findsOneWidget);
        await checkScrollableAccessibility(tester);
        await unmount(tester, [controller, mapSecurity]);
        expect(controller.routeManifests, isEmpty);
      },
    );
  }
  testWidgets(
    'route action is secondary and gated by accepted batch; opening only reads',
    (tester) async {
      final repository = WidgetBatchRepository();
      final routes = FakeRouteRepository();
      final routeController = DeliveryRouteController(repository: routes);
      final controller = FinalMileBatchController(
        repository: repository,
        routeController: routeController,
      );
      final auth = batchAuthController();
      await tester.pumpWidget(
        MaterialApp(
          home: FinalMileBatchDetailScreen(
            authController: auth,
            batchController: controller,
            scheduleId: 'schedule-1',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('View delivery route'), findsNothing);
      repository.accepted = true;
      await controller.loadDetail('schedule-1');
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(TextButton, 'View delivery route'),
        findsOneWidget,
      );
      await tester.tap(find.text('View delivery route'));
      await tester.pumpAndSettle();
      expect(find.text('Delivery route'), findsOneWidget);
      expect(routes.calls, 1);
      expect(repository.acceptCalls, 0);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(routeController.route, isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      routeController.dispose();
      auth.dispose();
    },
  );
  testWidgets('unknown and partial route states keep readable stops', (
    tester,
  ) async {
    final batch =
        (await (WidgetBatchRepository()..accepted = true).fetchBatches())
            .single;
    final controller = DeliveryRouteController(
      repository: FakeRouteRepository(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: DeliveryRouteScreen(batch: batch, controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    controller.route = DeliveryRoute.fromResponse(
      finalRouteFixture(
        status: 'unavailable',
        source: 'stop_sequence_fallback',
      ),
    );
    controller.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.textContaining('Partial route'), findsOneWidget);
    expect(find.text('Area two'), findsOneWidget);
    controller.route = DeliveryRoute.fromResponse(
      finalRouteFixture(status: 'future'),
    );
    controller.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.textContaining('unsupported'), findsOneWidget);
    expect(find.text('Area two'), findsOneWidget);
    controller.clear();
    await tester.pumpAndSettle();
    expect(find.text('Area two'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
  testWidgets(
    'logout removes pushed route screens and releases private widget state',
    (tester) async {
      final batch =
          (await (WidgetBatchRepository()..accepted = true).fetchBatches())
              .single;
      final controller = DeliveryRouteController(
        repository: FakeRouteRepository(),
      );
      final mapSecurity = security();
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        RouteMapScope(
          security: mapSecurity,
          renderer: (context, data, onFailure) =>
              const Text('Injected route map'),
          child: MaterialApp(
            navigatorKey: navigator,
            home: const Scaffold(body: Text('Identity gate')),
          ),
        ),
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) =>
              DeliveryRouteScreen(batch: batch, controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Area two'), findsOneWidget);
      mapSecurity.invalidate();
      controller.clear();
      await tester.pumpAndSettle();
      expect(find.text('Identity gate'), findsOneWidget);
      expect(find.byType(DeliveryRouteScreen), findsNothing);
      expect(controller.route, isNull);
      await unmount(tester, [controller, mapSecurity]);
    },
  );
}
