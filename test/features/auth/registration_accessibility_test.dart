import 'dart:async';

import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/features/auth/domain/auth_models.dart';
// ignore: depend_on_referenced_packages
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/accessibility.dart';
import 'fixtures/registration_screen_fixture.dart';

void main() {
  setUp(() {
    final original = FileSelectorPlatform.instance;
    FileSelectorPlatform.instance = TestImagePicker();
    addTearDown(() => FileSelectorPlatform.instance = original);
  });
  for (final scenario in AccessibilityScenario.matrix) {
    accessibilityTest('registration accessible: ${scenario.name}', scenario, (
      tester,
    ) async {
      final fixture = RegistrationScreenFixture();
      await fixture.open(tester, scenario: scenario);
      await checkScrollableAccessibility(tester);
      await fixture.fill(tester);
      await checkScrollableAccessibility(tester);
      expect(fixture.repository.submissions, 0);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await checkAccessibility(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(TextField), findsWidgets);
      expect(fixture.repository.submissions, 0);
      await unmount(tester, [fixture.auth]);
    });
  }
  for (final scenario in AccessibilityScenario.stress) {
    accessibilityTest(
      'registration validation and keyboard: ${scenario.name}',
      scenario,
      (tester) async {
        final fixture = RegistrationScreenFixture();
        await fixture.open(tester, scenario: scenario);
        await fixture.submit(tester);
        expect(
          tester.widget<TextField>(field('First name')).focusNode!.hasFocus,
          isTrue,
        );
        await checkAccessibility(tester);
        await tester.testTextInput.receiveAction(TextInputAction.next);
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(field('Last name')).focusNode!.hasFocus,
          isTrue,
        );
        await pressTab(tester, reverse: true);
        expect(
          tester.widget<TextField>(field('First name')).focusNode!.hasFocus,
          isTrue,
        );
        expect(fixture.repository.submissions, 0);
        await unmount(tester, [fixture.auth]);
      },
    );
  }
  for (final scenario in AccessibilityScenario.stress) {
    accessibilityTest(
      'registration organizations loading, offline and retry: ${scenario.name}',
      scenario,
      (tester) async {
        final pending = Completer<List<LogisticsOption>>();
        final fixture = RegistrationScreenFixture();
        fixture.repository.pendingOptions = pending;
        await fixture.open(tester, scenario: scenario, settle: false);
        await checkScrollableAccessibility(tester);
        pending.completeError(const ApiException.network('Test offline'));
        fixture.repository.pendingOptions = null;
        await tester.pumpAndSettle();
        await checkScrollableAccessibility(tester);
        await reveal(tester, find.text('Retry organizations'));
        await tester.tap(find.text('Retry organizations'));
        await tester.pumpAndSettle();
        await checkScrollableAccessibility(tester);
        expect(fixture.repository.submissions, 0);
        await unmount(tester, [fixture.auth]);
      },
    );
  }
}
