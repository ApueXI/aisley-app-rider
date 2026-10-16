import 'dart:async';

import 'package:aisley_app/core/config/app_config.dart';
import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/core/security/courier_map_security.dart';
import 'package:aisley_app/features/pickup/domain/pickup_models.dart';
import 'package:aisley_app/features/pickup/presentation/controllers/pickup_controller.dart';
import 'package:aisley_app/features/pickup/presentation/pickup_screen.dart';
import 'package:aisley_app/shared/route_map/route_map_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/accessibility.dart';
import '../batch/fixtures/final_mile_batch_screen_fixture.dart'
    show batchAuthController;
import '../delivery_route/delivery_route_contract_test.dart'
    show RouteTestStorage;
import 'fixtures/pickup_route_repository.dart';

void main() {
  late PickupRouteRepository repository;
  late PickupController controller;

  setUp(() {
    repository = PickupRouteRepository();
    controller = PickupController(pickupRepository: repository);
  });
  tearDown(() => controller.dispose());

  Future<void> show(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PickupRouteScreen(
          pickupController: controller,
          scheduleId: 'schedule-a',
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'refresh recovers empty route stops without changing task state',
    (tester) async {
      await show(tester);
      expect(find.text('Back to pickup tasks'), findsOneWidget);
      repository.response = populatedPickupRoute();
      await tester.tap(find.text('Refresh route'));
      await tester.pumpAndSettle();

      expect(find.text('Back to pickup tasks'), findsNothing);
      expect(find.textContaining('Route stops are unavailable.'), findsNothing);
      await reveal(tester, find.text('Orders: ORD-1, ORD-2'));
      expect(repository.routeReads, ['schedule-a', 'schedule-a']);
      expect(repository.queries, isEmpty);
      expect(repository.finalMileReads, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'malformed stop lists show a recoverable error instead of empty work',
    (tester) async {
      (repository.response['data'] as Map)['stops'] = <String, Object>{};
      await show(tester);
      expect(
        controller.routeStatuses['schedule-a'],
        PickupSectionStatus.failed,
      );
      expect(controller.routeManifests, isEmpty);
      expect(find.textContaining('unexpected response'), findsOneWidget);
      expect(find.textContaining('No route stops are assigned'), findsNothing);
      repository.response = populatedPickupRoute();
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Orders: ORD-1, ORD-2'));
      expect(find.textContaining('unexpected response'), findsNothing);
      expect(repository.routeReads, ['schedule-a', 'schedule-a']);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('route refresh honors Retry-After without automatic requests', (
    tester,
  ) async {
    await show(tester);
    repository.onRouteRead = (_) async => throw const ApiException(
      statusCode: 429,
      code: 'TOO_MANY_REQUESTS',
      message: '',
      retryAfter: Duration(seconds: 5),
    );
    await tester.tap(find.text('Refresh route'));
    await tester.pumpAndSettle();
    final refresh = find.widgetWithText(TextButton, 'Refresh route');
    expect(tester.widget<TextButton>(refresh).onPressed, isNull);
    expect(find.text('Wait before retrying the route.'), findsOneWidget);
    expect(find.text('Back to pickup tasks'), findsOneWidget);
    await controller.loadRouteManifest('schedule-a', refresh: true);
    expect(repository.routeReads, hasLength(2));

    repository.onRouteRead = null;
    repository.response = populatedPickupRoute();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(repository.routeReads, hasLength(2));
    await tester.tap(refresh);
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Orders: ORD-1, ORD-2'));
    expect(repository.routeReads, hasLength(3));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final statusCode in [401, 403, 409]) {
    testWidgets('$statusCode removes route data without showing empty work', (
      tester,
    ) async {
      repository.response = populatedPickupRoute();
      await show(tester);
      repository.onRouteRead = (_) async => throw ApiException(
        statusCode: statusCode,
        code: 'UNAVAILABLE',
        message: '',
      );
      await reveal(tester, find.text('Refresh route'));
      await tester.tap(find.text('Refresh route'));
      await tester.pumpAndSettle();
      expect(controller.routeManifests, isEmpty);
      expect(controller.routeErrors['schedule-a'], isNotNull);
      expect(find.text('Seller area'), findsNothing);
      expect(find.text('Back to pickup tasks'), findsNothing);
      expect(find.textContaining('No route stops are assigned'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'Back to pickup tasks preserves the selected schedule and scroll',
    (tester) async {
      final auth = batchAuthController();
      await tester.pumpWidget(
        MaterialApp(
          home: PickupScreen(
            authController: auth,
            pickupController: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await controller.selectFirstMileSchedule('schedule-a');
      await tester.pumpAndSettle();
      final tasks = controller.firstMileTasks;
      await reveal(tester, find.text('Route order'));
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      final scrollOffset = position.pixels;
      await tester.tap(find.text('Route order'));
      await tester.pumpAndSettle();
      expect(find.byType(PickupRouteScreen), findsOneWidget);

      final back = find.byWidgetPredicate((widget) => widget is FilledButton);
      await focusByKeyboard(tester, back);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(PickupRouteScreen), findsNothing);
      expect(controller.firstMileScheduleId, 'schedule-a');
      expect(controller.firstMileTasks, same(tasks));
      expect(controller.routeManifests, isEmpty);
      expect(repository.queries, [null, 'schedule-a']);
      expect(repository.routeReads, ['schedule-a']);
      expect(position.pixels, scrollOffset);
      await tester.pumpWidget(const SizedBox.shrink());
      auth.dispose();
    },
  );

  testWidgets(
    'map revalidation with no stops offers return instead of promising a list',
    (tester) async {
      repository.response = populatedPickupRoute();
      final security = _security();
      await tester.pumpWidget(
        RouteMapScope(
          security: security,
          renderer: (_, _, onFailure) => TextButton(
            onPressed: onFailure,
            child: const Text('Simulate map failure'),
          ),
          child: MaterialApp(
            home: PickupRouteScreen(
              pickupController: controller,
              scheduleId: 'schedule-a',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      repository.response = emptyPickupRoute();
      await tester.tap(find.text('Simulate map failure'));
      await tester.pumpAndSettle();
      expect(find.text('Map could not be loaded.'), findsOneWidget);
      expect(
        find.textContaining('Route stops are unavailable.'),
        findsOneWidget,
      );
      expect(find.text('Back to pickup tasks'), findsOneWidget);
      expect(
        find.textContaining('Route stops remain available below'),
        findsNothing,
      );
      expect(find.text('Seller area'), findsNothing);
      expect(repository.routeReads, ['schedule-a', 'schedule-a']);
      await tester.pumpWidget(const SizedBox.shrink());
      security.dispose();
    },
  );

  testWidgets('session loss closes the route and ignores late private stops', (
    tester,
  ) async {
    repository.response = populatedPickupRoute();
    final navigator = GlobalKey<NavigatorState>();
    final security = _security();
    await tester.pumpWidget(
      RouteMapScope(
        security: security,
        renderer: (_, _, _) => const Text('Injected map'),
        child: MaterialApp(
          navigatorKey: navigator,
          home: const Scaffold(body: Text('Identity gate')),
        ),
      ),
    );
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => PickupRouteScreen(
          pickupController: controller,
          scheduleId: 'schedule-a',
        ),
      ),
    );
    await tester.pumpAndSettle();
    final response = Completer<PickupRouteManifest>();
    repository.onRouteRead = (_) => response.future;
    final refresh = controller.loadRouteManifest('schedule-a', refresh: true);
    await tester.pump();
    security.invalidate();
    controller.clear();
    await tester.pumpAndSettle();
    response.complete(PickupRouteManifest.fromResponse(populatedPickupRoute()));
    await refresh;
    await tester.pumpAndSettle();
    expect(find.text('Identity gate'), findsOneWidget);
    expect(find.byType(PickupRouteScreen), findsNothing);
    expect(find.text('Seller area'), findsNothing);
    expect(controller.routeManifests, isEmpty);
    expect(controller.routeStatuses, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    security.dispose();
  });
}

CourierMapSecurity _security() {
  const config = AppConfig(baseUrl: 'https://api.example');
  return CourierMapSecurity(
    config: config,
    client: ApiClient(config: config, tokenStorage: RouteTestStorage()),
  );
}
