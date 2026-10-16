import 'package:aisley_app/core/networking/api_contract_exception.dart';
import 'package:aisley_app/features/pickup/domain/pickup_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final status in ['pending', 'ready', 'unavailable', 'future']) {
    test('$status accepts an explicitly empty stop list', () {
      final manifest = PickupRouteManifest.fromResponse({
        'data': {'status': status, 'stops': <Object>[]},
      });
      expect(manifest.stops, isEmpty);
    });
  }

  for (final status in ['pending', 'unavailable']) {
    for (final includeNull in [false, true]) {
      test(
        '$status preserves missing/null stops compatibility: $includeNull',
        () {
          final manifest = PickupRouteManifest.fromResponse({
            'data': {'status': status, if (includeNull) 'stops': null},
          });
          expect(manifest.stops, isEmpty);
        },
      );
    }
  }

  for (final stops in <Object>[<String, Object>{}, 'invalid', 1, false]) {
    test('rejects a non-list stops value: ${stops.runtimeType}', () {
      expect(
        () => PickupRouteManifest.fromResponse({
          'data': {'status': 'unavailable', 'stops': stops},
        }),
        throwsA(isA<ApiContractException>()),
      );
    });
  }

  test('rejects malformed stop entries', () {
    expect(
      () => PickupRouteManifest.fromResponse({
        'data': {
          'status': 'ready',
          'stops': [null],
        },
      }),
      throwsA(isA<ApiContractException>()),
    );
  });
}
