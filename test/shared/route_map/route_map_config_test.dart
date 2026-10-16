import 'package:aisley_app/core/config/app_config.dart';
import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/core/security/courier_map_security.dart';
import 'package:aisley_app/shared/route_map/route_map_data.dart';
import 'package:aisley_app/shared/route_map/route_map_scope.dart';
import 'package:aisley_app/shared/route_map/route_map_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../features/delivery_route/delivery_route_contract_test.dart'
    show RouteTestStorage;

void main() {
  testWidgets(
    'disabled maps retain readable stops without rendering or retrying',
    (tester) async {
      final config = AppConfig.fromDotEnv('MAPS_ENABLED=false');
      var requests = 0;
      var renderCalls = 0;
      var failures = 0;
      final security = CourierMapSecurity(
        config: config,
        client: ApiClient(
          config: config,
          tokenStorage: RouteTestStorage(),
          client: MockClient((_) async {
            requests++;
            return http.Response('{}', 200);
          }),
        ),
      );
      addTearDown(security.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: RouteMapScope(
            security: security,
            renderer: (_, _, _) {
              renderCalls++;
              return const Text('Rendered map');
            },
            child: Scaffold(
              body: Column(
                children: [
                  RouteMapView(
                    data: const RouteMapData(
                      markers: [
                        RouteMarker(
                          position: RoutePosition(121, 14),
                          label: '1',
                        ),
                      ],
                    ),
                    onFailure: (_) => failures++,
                  ),
                  const Text('Stop 1: authorized destination'),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 30));

      expect(
        find.text('Map unavailable. Route stops remain available below.'),
        findsOneWidget,
      );
      expect(find.text('Stop 1: authorized destination'), findsOneWidget);
      expect(renderCalls, 0);
      expect(requests, 0);
      expect(failures, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
