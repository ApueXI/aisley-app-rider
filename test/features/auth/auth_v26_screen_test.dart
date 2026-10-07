import 'package:aisley_app/app/courier_app.dart';
import 'package:aisley_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aisley_app/features/auth/presentation/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../helpers/accessibility.dart';
import 'fixtures/auth_v26_fixture.dart';

void main() {
  for (final denial in [
    ...accountDenials,
    affiliationDenial,
    wrongRoleDenial,
  ]) {
    testWidgets('${denial.code} shows the documented blocked destination', (
      tester,
    ) async {
      final api = AuthTestApi()..respond = (_) async => denial.response();
      api.storage.token = 'synthetic-restored-token';
      final auth = api.controller();
      addTearDown(auth.dispose);
      await auth.initialize();
      await tester.pumpWidget(CourierApp(authController: auth));
      await tester.pumpAndSettle();
      final expectedKey = switch (denial.status) {
        AuthStatus.pendingApproval => 'pending-approval',
        AuthStatus.rejected => 'rejected',
        AuthStatus.suspendedOrDeactivated => 'suspended',
        AuthStatus.invalidAffiliation => 'invalid-affiliation',
        _ => 'access-denied',
      };
      expect(find.byKey(ValueKey(expectedKey)), findsOneWidget);
      expect(find.text('Return to sign in'), findsOneWidget);
      expect(find.text('Courier dashboard'), findsNothing);
      await tester.tap(find.text('Return to sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Courier sign in'), findsOneWidget);
    });
  }

  testWidgets('expired restored session opens sign in', (tester) async {
    final api = AuthTestApi()..respond = (_) async => unauthorizedResponse();
    api.storage.token = 'synthetic-expired-token';
    final auth = api.controller();
    addTearDown(auth.dispose);
    await auth.initialize();
    await tester.pumpWidget(CourierApp(authController: auth));
    await tester.pumpAndSettle();
    expect(find.text('Courier sign in'), findsOneWidget);
    expect(api.storage.token, isNull);
  });

  for (final scenario in AccessibilityScenario.stress) {
    accessibilityTest(
      'sign-in cooldown blocks taps and keyboard: ${scenario.name}',
      scenario,
      (tester) async {
        final api = AuthTestApi()
          ..respond = (_) async =>
              http.Response('{}', 429, headers: {'retry-after': '30'});
        final auth = api.controller();
        addTearDown(auth.dispose);
        await auth.initialize();
        await tester.pumpWidget(
          scenario.app(LoginScreen(authController: auth, onRegister: () {})),
        );
        await tester.pumpAndSettle();
        Finder field(String label) => find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == label,
        );
        await reveal(tester, field('Email'));
        await tester.enterText(field('Email'), 'courier@example.test');
        await reveal(tester, field('Password'));
        await tester.enterText(field('Password'), 'Synthetic123');
        await reveal(tester, find.text('Sign in'));
        await tester.tap(find.text('Sign in'));
        await tester.pumpAndSettle();
        expect(api.requests.length, 1);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
        expect(
          find.text('Please wait before trying to sign in again.'),
          findsOneWidget,
        );
        expect(
          tester.widget<TextField>(field('Email')).controller!.text,
          'courier@example.test',
        );
        expect(
          tester.widget<TextField>(field('Password')).controller!.text,
          isEmpty,
        );
        await reveal(tester, field('Password'));
        await tester.enterText(field('Password'), 'Synthetic123');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        expect(api.requests.length, 1);
        await checkScrollableAccessibility(tester);
        await tester.pump(const Duration(seconds: 30));
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNotNull,
        );
        expect(api.requests.length, 1);
        api.respond = (_) async => loginResponse();
        await reveal(tester, find.text('Sign in'));
        await tester.tap(find.text('Sign in'));
        await tester.pumpAndSettle();
        expect(auth.status, AuthStatus.authenticated);
        expect(api.requests.length, 2);
      },
    );
  }

  testWidgets(
    'restored-session 429 keeps token and disables Retry until expiry',
    (tester) async {
      final api = AuthTestApi()
        ..respond = (_) async =>
            http.Response('{}', 429, headers: {'retry-after': '3'});
      api.storage.token = 'synthetic-restored-token';
      final auth = api.controller();
      addTearDown(auth.dispose);
      await auth.initialize();
      await tester.pumpWidget(CourierApp(authController: auth));
      await tester.pump();
      expect(
        find.text('Please wait before checking your session again.'),
        findsOneWidget,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(api.storage.token, isNotNull);
      await auth.retry();
      expect(api.requests.length, 1);
      await tester.pump(const Duration(seconds: 3));
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      expect(api.requests.length, 1);
      api.respond = (_) async => identityResponse();
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(auth.status, AuthStatus.authenticated);
    },
  );
}
