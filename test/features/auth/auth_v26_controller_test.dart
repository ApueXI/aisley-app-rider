import 'dart:async';

import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'fixtures/auth_v26_fixture.dart';

void main() {
  for (final restore in [false, true]) {
    final flow = restore ? 'restored session' : 'login';
    for (final denial in [
      ...accountDenials,
      affiliationDenial,
      wrongRoleDenial,
    ]) {
      test('$flow consumes ${denial.code} and clears private state', () async {
        final api = AuthTestApi();
        var sessionEnded = 0;
        final privateState = <String>['private account data'];
        final auth = api.controller(
          onSessionEnded: () {
            sessionEnded++;
            privateState.clear();
          },
        );
        addTearDown(auth.dispose);
        api.storage.token = 'synthetic-restored-token';
        api.respond = (_) async => denial.response();
        if (restore) {
          await auth.initialize();
        } else {
          await auth.signIn(
            email: 'courier@example.test',
            password: 'Synthetic123',
          );
        }
        expect(auth.status, denial.status);
        expect(auth.courier, isNull);
        expect(auth.dashboard, isNull);
        expect(privateState, isEmpty);
        expect(sessionEnded, greaterThan(0));
        expect(api.storage.token, isNull);
        expect(api.storage.writes, 0);
      });
    }
    for (final denial in accountDenials) {
      for (final condition in invalidAffiliationConditions) {
        test(
          '$flow account-first fixture ${denial.code} with $condition',
          () async {
            final api = AuthTestApi();
            api.storage.token = restore ? 'synthetic-restored-token' : null;
            // Auth v2.6 emits only the account denial even when affiliation is
            // invalid. No affiliation DTO is returned in this response.
            api.respond = (_) async => denial.response();
            final auth = api.controller();
            addTearDown(auth.dispose);
            if (restore) {
              await auth.initialize();
            } else {
              await auth.signIn(
                email: 'courier@example.test',
                password: 'Synthetic123',
              );
            }
            expect(auth.status, denial.status);
            expect(auth.status, isNot(AuthStatus.invalidAffiliation));
          },
        );
      }
    }
  }

  test(
    'active account with rejected affiliation remains invalid affiliation',
    () async {
      final api = AuthTestApi()
        ..respond = (_) async => affiliationDenial.response();
      final auth = api.controller();
      addTearDown(auth.dispose);
      await auth.signIn(
        email: 'courier@example.test',
        password: 'Synthetic123',
      );
      expect(auth.status, AuthStatus.invalidAffiliation);
      expect(auth.status, isNot(AuthStatus.rejected));
    },
  );

  test(
    '401 clears an established session, dashboard, and feature callback state',
    () async {
      final api = AuthTestApi()..respond = (_) async => loginResponse();
      final privateState = <String>[];
      final auth = api.controller(onSessionEnded: privateState.clear);
      addTearDown(auth.dispose);
      await auth.signIn(
        email: 'courier@example.test',
        password: 'Synthetic123',
      );
      await auth.loadDashboard();
      privateState.add('private proof and messages');
      expect(auth.dashboard, isNotNull);
      await auth.handleAccountAuthFailure(
        ApiException.fromResponse(unauthorizedResponse()),
      );
      expect(auth.status, AuthStatus.signedOut);
      expect(auth.courier, isNull);
      expect(auth.dashboard, isNull);
      expect(auth.dashboardStatus, DashboardLoadStatus.idle);
      expect(api.storage.token, isNull);
      expect(privateState, isEmpty);
    },
  );

  test(
    'restored invalid token clears storage and returns to sign in',
    () async {
      final api = AuthTestApi()..respond = (_) async => unauthorizedResponse();
      api.storage.token = 'synthetic-expired-token';
      final auth = api.controller();
      addTearDown(auth.dispose);
      await auth.initialize();
      expect(auth.status, AuthStatus.signedOut);
      expect(api.storage.token, isNull);
    },
  );

  test(
    'policy consent preserves token/identity until explicit completion',
    () async {
      final api = AuthTestApi()..respond = (_) async => loginResponse();
      var ended = 0;
      final auth = api.controller(onSessionEnded: () => ended++);
      addTearDown(auth.dispose);
      await auth.signIn(
        email: 'courier@example.test',
        password: 'Synthetic123',
      );
      await auth.loadDashboard();
      final identity = auth.courier;
      final token = api.storage.token;
      final initialEnded = ended;
      await auth.handlePolicyAuthFailure(
        ApiException.fromResponse(policyRequiredResponse()),
      );
      expect(auth.status, AuthStatus.policyConsentRequired);
      expect(auth.courier, same(identity));
      expect(api.storage.token, token);
      expect(api.storage.clears, 0);
      expect(ended, initialEnded);
      expect(auth.dashboard, isNull);
      await auth.loadDashboard();
      expect(auth.dashboard, isNull);
      await auth.completePolicyConsent();
      expect(auth.status, AuthStatus.authenticated);
      expect(api.storage.token, token);
      expect(api.storage.writes, 1);
    },
  );

  for (final operation in ['read', 'write', 'clear']) {
    test(
      'secure-storage $operation failure blocks access and clears memory',
      () async {
        final api = AuthTestApi()..respond = (_) async => loginResponse();
        var ended = 0;
        final auth = api.controller(onSessionEnded: () => ended++);
        addTearDown(auth.dispose);
        if (operation == 'clear') {
          await auth.signIn(
            email: 'courier@example.test',
            password: 'Synthetic123',
          );
          await auth.loadDashboard();
        }
        api.storage.failOperation = operation;
        if (operation == 'read') {
          await auth.initialize();
        }
        if (operation == 'write') {
          await auth.signIn(
            email: 'courier@example.test',
            password: 'Synthetic123',
          );
        }
        if (operation == 'clear') {
          await auth.handleAccountAuthFailure(
            ApiException.fromResponse(unauthorizedResponse()),
          );
          expect(api.storage.token, isNotNull);
        }
        expect(auth.status, AuthStatus.secureStorageFailure);
        expect(auth.courier, isNull);
        expect(auth.dashboard, isNull);
        expect(auth.dashboardStatus, DashboardLoadStatus.idle);
        expect(auth.errorMessage, isNot(contains('private')));
        expect(auth.errorMessage, isNot(contains('not changed')));
        expect(ended, greaterThan(0));
      },
    );
  }

  for (final restore in [false, true]) {
    for (final failure in ApiNetworkFailure.values) {
      test(
        '${restore ? 'restore' : 'login'} $failure supports explicit retry',
        () async {
          final api = AuthTestApi()
            ..respond = (_) async {
              if (failure == ApiNetworkFailure.timeout) {
                throw TimeoutException('private detail');
              }
              throw http.ClientException('private network detail');
            };
          final auth = api.controller();
          addTearDown(auth.dispose);
          if (restore) api.storage.token = 'synthetic-restored-token';
          if (restore) {
            await auth.initialize();
          } else {
            await auth.signIn(
              email: 'courier@example.test',
              password: 'Synthetic123',
            );
          }
          expect(
            auth.status,
            restore
                ? AuthStatus.recoverableNetworkFailure
                : AuthStatus.signedOut,
          );
          expect(auth.errorMessage, isNot(contains('private')));
          expect(
            auth.errorMessage,
            failure == ApiNetworkFailure.timeout
                ? contains('timed out')
                : contains('connection'),
          );
          if (restore) expect(api.storage.token, isNotNull);
          api.respond = (_) async =>
              restore ? identityResponse() : loginResponse();
          if (restore) {
            await auth.retry();
          } else {
            await auth.signIn(
              email: 'courier@example.test',
              password: 'Synthetic123',
            );
          }
          expect(auth.status, AuthStatus.authenticated);
        },
      );
    }
  }

  test('restore 5xx retains token and offers retry', () async {
    final api = AuthTestApi()..respond = (_) async => http.Response('{}', 503);
    api.storage.token = 'synthetic-restored-token';
    final auth = api.controller();
    addTearDown(auth.dispose);
    await auth.initialize();
    expect(auth.status, AuthStatus.recoverableNetworkFailure);
    expect(api.storage.token, isNotNull);
  });

  for (final statusCode in [200, 401]) {
    test('logout $statusCode clears only the local current session', () async {
      final api = AuthTestApi()..respond = (_) async => loginResponse();
      final auth = api.controller();
      addTearDown(auth.dispose);
      await auth.signIn(
        email: 'courier@example.test',
        password: 'Synthetic123',
      );
      api.respond = (_) async => http.Response('{}', statusCode);
      expect(await auth.signOut(), isTrue);
      expect(auth.status, AuthStatus.signedOut);
      expect(api.storage.token, isNull);
    });
  }
}
