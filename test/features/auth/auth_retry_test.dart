import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'fixtures/auth_v26_fixture.dart';

void main() {
  for (final flow in ['login', 'restore', 'registration']) {
    for (final header in ['3', '', '-5', 'invalid']) {
      testWidgets(
        '$flow honors $header Retry-After and never retries automatically',
        (tester) async {
          final api = AuthTestApi()
            ..respond = (_) async =>
                http.Response('{}', 429, headers: {'retry-after': header});
          api.storage.token = 'synthetic-restored-token';
          final auth = api.controller();
          Future<void> attempt() async {
            if (flow == 'login') {
              await auth.signIn(
                email: 'courier@example.test',
                password: 'Synthetic123',
              );
            }
            if (flow == 'restore') await auth.initialize();
            if (flow == 'registration') {
              await expectLater(
                auth.register(registrationRequest()),
                throwsA(
                  isA<ApiException>().having(
                    (e) => e.statusCode,
                    'status',
                    429,
                  ),
                ),
              );
            }
          }

          bool canRetry() => switch (flow) {
            'login' => auth.canSignIn,
            'restore' => auth.canRetrySession,
            _ => auth.canRegister,
          };
          await attempt();
          expect(canRetry(), false);
          if (flow == 'restore') {
            expect(auth.status, AuthStatus.recoverableNetworkFailure);
            expect(api.storage.token, isNotNull);
          }
          await attempt();
          expect(api.requests.length, 1);
          final seconds = header == '3' ? 3 : 1;
          await tester.pump(Duration(milliseconds: seconds * 1000 - 1));
          expect(canRetry(), false);
          expect(api.requests.length, 1);
          await tester.pump(const Duration(milliseconds: 1));
          expect(canRetry(), true);
          expect(api.requests.length, 1);
          await attempt();
          expect(api.requests.length, 2);
          auth.dispose();
          // Explicit disposal here verifies active timers cannot later notify.
          await tester.pump(const Duration(seconds: 4));
        },
      );
    }
  }

  testWidgets('login and registration cooldowns do not block one another', (
    tester,
  ) async {
    final api = AuthTestApi()
      ..respond = (_) async =>
          http.Response('{}', 429, headers: {'retry-after': '3'});
    final auth = api.controller();
    addTearDown(auth.dispose);
    await auth.signIn(email: 'courier@example.test', password: 'Synthetic123');
    expect(auth.canSignIn, false);
    expect(auth.canRegister, true);
    await expectLater(
      auth.register(registrationRequest()),
      throwsA(isA<ApiException>()),
    );
    expect(auth.canRegister, false);
    expect(api.requests.length, 2);
    await tester.pump(const Duration(seconds: 3));
    expect(auth.canSignIn, true);
    expect(auth.canRegister, true);
  });
}
