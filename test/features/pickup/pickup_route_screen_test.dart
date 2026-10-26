import 'package:aisley_app/core/config/app_config.dart';
import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/core/security/courier_map_security.dart';
import 'package:aisley_app/features/pickup/presentation/controllers/pickup_controller.dart';
import 'package:aisley_app/features/pickup/presentation/pickup_screen.dart';
import 'package:aisley_app/shared/route_map/route_map_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../helpers/accessibility.dart';
import '../delivery_route/delivery_route_contract_test.dart'
    show RouteTestStorage;
import 'fixtures/pickup_route_repository.dart';

void main() {
  for (final scenario in AccessibilityScenario.matrix) {
    for (final (status, message) in [
      ('pending', 'The pickup route is still being prepared.'),
      ('ready', 'Route stops were not provided.'),
      ('unavailable', 'Route stops are unavailable.'),
      ('future', 'This pickup route cannot be displayed.'),
    ]) {
      accessibilityTest('empty $status route: ${scenario.name}', scenario, (
        tester,
      ) async {
        final repository = PickupRouteRepository()
          ..response = emptyPickupRoute(status: status);
        final controller = PickupController(pickupRepository: repository);
        await tester.pumpWidget(
          scenario.app(
            PickupRouteScreen(
              pickupController: controller,
              scheduleId: 'schedule-a',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining(message), findsOneWidget);
        await reveal(tester, find.text('Back to pickup tasks'));
        expect(find.text('Back to pickup tasks'), findsOneWidget);
        expect(
          find.textContaining('Route stops remain available below'),
          findsNothing,
        );
        expect(
          find.textContaining('No route stops are assigned'),
          findsNothing,
        );
        expect(
          find.textContaining('ordered pickup route returning'),
          findsNothing,
        );
        expect(find.text('Authorized stop order'), findsNothing);
        expect(repository.routeReads, ['schedule-a']);
        await checkScrollableAccessibility(tester);

        await unmount(tester, [controller]);
        expect(controller.routeManifests, isEmpty);
      });
    }
  }

  for (final scenario in AccessibilityScenario.stress) {
    for (final mode in [
      'missing coordinates',
      'disabled maps',
      'map failure',
    ]) {
      accessibilityTest(
        '$mode preserves pickup stops: ${scenario.name}',
        scenario,
        (tester) async {
          final repository = PickupRouteRepository()
            ..response = populatedPickupRoute(
              coordinates: mode != 'missing coordinates',
            );
          final controller = PickupController(pickupRepository: repository);
          final config = AppConfig(
            baseUrl: 'https://api.example',
            mapsEnabled: mode != 'disabled maps',
          );
          var mapRequests = 0;
          var renders = 0;
          final security = CourierMapSecurity(
            config: config,
            client: ApiClient(
              config: config,
              tokenStorage: RouteTestStorage(),
              client: MockClient((_) async {
                mapRequests++;
                return http.Response('{}', 200);
              }),
            ),
          );
          await tester.pumpWidget(
            RouteMapScope(
              security: security,
              renderer: mode == 'missing coordinates'
                  ? null
                  : (_, _, onFailure) {
                      renders++;
                      return TextButton(
                        onPressed: onFailure,
                        child: const Text('Simulate map failure'),
                      );
                    },
              child: scenario.app(
                PickupRouteScreen(
                  pickupController: controller,
                  scheduleId: 'schedule-a',
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (mode == 'map failure') {
            await reveal(tester, find.text('Simulate map failure'));
            await tester.tap(find.text('Simulate map failure'));
            await tester.pumpAndSettle();
            expect(find.text('Map could not be loaded.'), findsOneWidget);
            expect(repository.routeReads, ['schedule-a', 'schedule-a']);
          } else {
            await reveal(tester, find.text('Map unavailable.'));
            expect(find.text('Map unavailable.'), findsOneWidget);
            expect(renders, 0);
          }
          expect(mapRequests, 0);
          expect(controller.routeManifests['schedule-a']!.stops, hasLength(3));
          await reveal(tester, find.text('Seller area'));
          expect(find.text('Orders: ORD-1, ORD-2'), findsOneWidget);
          expect(find.text('Back to pickup tasks'), findsNothing);
          await checkScrollableAccessibility(tester);
          expect(
            find.text('Route stops remain available below.'),
            findsNothing,
          );
          await unmount(tester, [controller, security]);
        },
      );
    }
  }
}
