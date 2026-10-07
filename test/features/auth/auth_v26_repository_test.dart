import 'dart:async';

import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/core/security/token_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'fixtures/auth_v26_fixture.dart';

void main() {
  for (final denial in [
    ...accountDenials,
    affiliationDenial,
    wrongRoleDenial,
  ]) {
    for (final restore in [false, true]) {
      test(
        '${restore ? 'me' : 'login'} retains exact ${denial.code} payload',
        () async {
          final api = AuthTestApi()..respond = (_) async => denial.response();
          api.storage.token = restore ? 'synthetic-restored-token' : null;
          await expectLater(
            restore
                ? api.repository.currentCourier()
                : api.repository.login(
                    email: 'courier@example.test',
                    password: 'Synthetic123',
                    deviceName: 'Test device',
                  ),
            throwsA(
              isA<ApiException>()
                  .having((e) => e.statusCode, 'status', 403)
                  .having((e) => e.code, 'code', denial.code)
                  .having((e) => e.message, 'message', denial.message),
            ),
          );
          expect(api.storage.writes, 0);
          expect(
            api.requests.single.url.path,
            '/api/v1/courier/auth/${restore ? 'me' : 'login'}',
          );
        },
      );
    }
  }

  test(
    'duplicate registration retains exact server email field error',
    () async {
      final api = AuthTestApi()
        ..respond = (_) async => duplicateEmailResponse();
      await expectLater(
        api.repository.register(registrationRequest()),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'EMAIL_ALREADY_REGISTERED')
              .having((e) => e.fieldErrors, 'field errors', {
                'email': [duplicateEmailMessage],
              }),
        ),
      );
      expect(api.storage.writes, 0);
      expect(api.requests.length, 1);
    },
  );

  test(
    'invalid credentials preserve generic message without token issuance',
    () async {
      final api = AuthTestApi()
        ..respond = (_) async => http.Response(
          '{"code":"INVALID_CREDENTIALS","message":"The email or password is incorrect."}',
          422,
        );
      await expectLater(
        api.repository.login(
          email: 'courier@example.test',
          password: 'Synthetic123',
          deviceName: 'Test device',
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'INVALID_CREDENTIALS')
              .having(
                (e) => e.message,
                'message',
                'The email or password is incorrect.',
              ),
        ),
      );
      expect(api.storage.writes, 0);
    },
  );

  for (final header in ['30', '-2', 'invalid']) {
    test(
      '429 parses Retry-After $header without automatically repeating request',
      () async {
        final api = AuthTestApi()
          ..respond = (_) async =>
              http.Response('{}', 429, headers: {'retry-after': header});
        await expectLater(
          api.repository.login(
            email: 'courier@example.test',
            password: 'Synthetic123',
            deviceName: 'Test device',
          ),
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'status', 429)
                .having(
                  (e) => e.retryAfter,
                  'delay',
                  int.tryParse(header) == null
                      ? null
                      : Duration(seconds: int.parse(header)),
                ),
          ),
        );
        expect(api.requests.length, 1);
      },
    );
  }

  for (final operation in ['read', 'write', 'clear']) {
    test('repository propagates secure-storage $operation failure', () async {
      final api = AuthTestApi()..respond = (_) async => loginResponse();
      api.storage.token = 'synthetic-restored-token';
      api.storage.failOperation = operation;
      final future = switch (operation) {
        'read' => api.repository.currentCourier(),
        'write' => api.repository.login(
          email: 'courier@example.test',
          password: 'Synthetic123',
          deviceName: 'Test device',
        ),
        _ => api.repository.clearStoredToken(),
      };
      await expectLater(
        future,
        throwsA(
          isA<TokenStorageException>().having(
            (e) => e.operation,
            'operation',
            operation,
          ),
        ),
      );
      if (operation == 'read') expect(api.requests, isEmpty);
    });
  }

  test(
    'HTTP client failure is offline with no automatic login retry',
    () async {
      final api = AuthTestApi()
        ..respond = (_) async => throw http.ClientException('private detail');
      await expectLater(
        api.repository.login(
          email: 'courier@example.test',
          password: 'Synthetic123',
          deviceName: 'Test device',
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.networkFailure,
            'failure',
            ApiNetworkFailure.offline,
          ),
        ),
      );
      expect(api.requests.length, 1);
    },
  );

  test(
    'elapsed transport timeout is recoverable and issues no token',
    () async {
      final api = AuthTestApi(timeout: const Duration(milliseconds: 5));
      final pending = Completer<http.Response>();
      api.respond = (_) => pending.future;
      await expectLater(
        api.repository.login(
          email: 'courier@example.test',
          password: 'Synthetic123',
          deviceName: 'Test device',
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.networkFailure,
            'failure',
            ApiNetworkFailure.timeout,
          ),
        ),
      );
      expect(api.storage.writes, 0);
      expect(api.requests.length, 1);
      pending.complete(loginResponse());
      await Future<void>.delayed(Duration.zero);
      expect(api.storage.writes, 0);
    },
  );
}
