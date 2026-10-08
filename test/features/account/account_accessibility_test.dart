import 'dart:async';

import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/features/account/domain/account_models.dart';
// ignore: depend_on_referenced_packages
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/accessibility.dart';
import '../auth/fixtures/registration_screen_fixture.dart';
import 'fixtures/account_screen_fixture.dart';

void main() {
  setUp(() {
    final original = FileSelectorPlatform.instance;
    FileSelectorPlatform.instance = TestImagePicker();
    addTearDown(() => FileSelectorPlatform.instance = original);
  });
  for (final scenario in AccessibilityScenario.matrix) {
    accessibilityTest('account accessible: ${scenario.name}', scenario, (
      tester,
    ) async {
      final (auth, account) = await openAccount(tester, scenario: scenario);
      await checkScrollableAccessibility(tester);
      await reveal(tester, find.text('Choose photo'));
      await tester.tap(find.text('Choose photo'));
      await tester.pumpAndSettle();
      await checkScrollableAccessibility(tester);
      await enter(tester, 'First name', 'Edited');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await checkAccessibility(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        tester.widget<TextField>(field('First name')).controller!.text,
        'Edited',
      );
      await unmount(tester, [account, auth]);
    });
  }
  for (final scenario in AccessibilityScenario.stress) {
    accessibilityTest(
      'account password keyboard and validation: ${scenario.name}',
      scenario,
      (tester) async {
        final (auth, account) = await openAccount(tester, scenario: scenario);
        await reveal(tester, find.text('Change password'));
        await tester.tap(find.text('Change password'));
        await tester.pumpAndSettle();
        final current = field('Current password');
        expect(tester.widget<TextField>(current).focusNode!.hasFocus, isTrue);
        await checkAccessibility(tester);
        await focusByKeyboard(tester, find.byTooltip('Show password').first);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(current).obscureText, isFalse);
        await enter(tester, 'Current password', 'TestCurrent123');
        await enter(tester, 'New password', 'TestNew123');
        await enter(tester, 'Confirm new password', 'TestNew123');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(find.text('Change password?'), findsOneWidget);
        await checkAccessibility(tester);
        await focusByKeyboard(
          tester,
          find.widgetWithText(TextButton, 'Cancel'),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        await unmount(tester, [account, auth]);
      },
    );
  }
  for (final scenario in AccessibilityScenario.stress) {
    accessibilityTest(
      'account loading, offline and retry: ${scenario.name}',
      scenario,
      (tester) async {
        final pending = Completer<CourierAccount>();
        final repository = FakeAccountRepository()..pendingRead = pending;
        final (auth, account) = await openAccount(
          tester,
          scenario: scenario,
          repository: repository,
          settle: false,
        );
        await checkAccessibility(tester);
        expect(find.bySemanticsLabel('Loading your account'), findsOneWidget);
        pending.completeError(const ApiException.network('Test offline'));
        repository.pendingRead = null;
        await tester.pumpAndSettle();
        await checkScrollableAccessibility(tester);
        expect(find.text('Retry'), findsOneWidget);
        expect(field('First name'), findsNothing);
        await focusByKeyboard(
          tester,
          find.widgetWithText(FilledButton, 'Retry'),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        await checkScrollableAccessibility(tester);
        await unmount(tester, [account, auth]);
      },
    );
  }
}
