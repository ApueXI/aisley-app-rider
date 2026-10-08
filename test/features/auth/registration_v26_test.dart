import 'package:aisley_app/core/networking/api_client.dart';
// The existing picker dependency exposes its test platform through this package.
// ignore: depend_on_referenced_packages
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/accessibility.dart';
import 'fixtures/auth_v26_fixture.dart';
import 'fixtures/registration_screen_fixture.dart';

void main() {
  setUp(() => FileSelectorPlatform.instance = TestImagePicker());

  for (final failure in [
    'duplicate email',
    'offline',
    'timeout',
    'throttled',
  ]) {
    testWidgets(
      '$failure retains every non-password value and both evidence files',
      (tester) async {
        final fixture = RegistrationScreenFixture();
        addTearDown(fixture.auth.dispose);
        fixture.repository.error = switch (failure) {
          'duplicate email' => ApiException.fromResponse(
            duplicateEmailResponse(),
          ),
          'offline' => const ApiException.network('private detail'),
          'timeout' => const ApiException.network(
            'private detail',
            networkFailure: ApiNetworkFailure.timeout,
          ),
          _ => const ApiException(
            statusCode: 429,
            code: 'THROTTLED',
            message: 'private detail',
            retryAfter: Duration(seconds: 3),
          ),
        };
        await fixture.open(tester);
        await fixture.fill(tester);
        await enter(tester, 'Middle initial (optional)', 'Q');
        await enter(tester, 'Address line 2 (optional)', 'Unit 2');
        final before = _draft(tester);
        await fixture.submit(tester);
        expect(_draft(tester), before);
        expect(
          tester.widget<TextField>(field('Password')).controller!.text,
          isEmpty,
        );
        expect(
          tester.widget<TextField>(field('Confirm password')).controller!.text,
          isEmpty,
        );
        expect(find.text('test-image.png'), findsNWidgets(2));
        if (failure == 'duplicate email') {
          final email = tester.widget<TextField>(field('Email'));
          expect(email.decoration!.errorText, duplicateEmailMessage);
          expect(email.focusNode!.hasFocus, true);
        }
        if (failure == 'timeout') {
          expect(
            find.textContaining('registration request timed out'),
            findsOneWidget,
          );
        }
        if (failure == 'throttled') {
          final button = find.byWidgetPredicate((w) => w is FilledButton);
          expect(tester.widget<FilledButton>(button).onPressed, isNull);
          expect(
            find.text('Please wait before submitting your registration again.'),
            findsOneWidget,
          );
          await fixture.submit(tester);
          expect(fixture.repository.submissions, 1);
          await tester.pump(const Duration(seconds: 3));
          expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
          expect(fixture.repository.submissions, 1);
        }
        fixture.repository.error = null;
        // Attempting with cleared passwords must not send the old credentials.
        await fixture.submit(tester);
        expect(fixture.repository.submissions, 1);
        await enter(tester, 'Password', 'FreshInput123');
        await enter(tester, 'Confirm password', 'FreshInput123');
        await fixture.submit(tester);
        expect(fixture.repository.submissions, 2);
        expect(find.textContaining('pending'), findsWidgets);
      },
    );
  }

  for (final scenario in AccessibilityScenario.stress) {
    accessibilityTest(
      'registration cooldown remains readable: ${scenario.name}',
      scenario,
      (tester) async {
        final fixture = RegistrationScreenFixture();
        fixture.repository.error = const ApiException(
          statusCode: 429,
          code: 'THROTTLED',
          message: 'private detail',
          retryAfter: Duration(minutes: 5),
        );
        await fixture.open(tester, scenario: scenario);
        await fixture.fill(tester);
        await fixture.submit(tester);
        expect(
          find.text('Please wait before submitting your registration again.'),
          findsOneWidget,
        );
        await checkScrollableAccessibility(tester);
        expect(fixture.repository.submissions, 1);
        await unmount(tester, [fixture.auth]);
      },
    );
  }
}

Map<String, Object?> _draft(WidgetTester tester) => {
  for (final label in [
    'First name',
    'Last name',
    'Middle initial (optional)',
    'Contact number',
    'Birth date',
    'Email',
    'Street / house detail',
    'Address line 2 (optional)',
    'Region',
    'Province',
    'City / municipality',
    'Barangay',
    'Postal code',
    'Plate number',
  ])
    label: tester.widget<TextField>(field(label)).controller!.text,
  for (final dropdown in tester.widgetList<DropdownButtonFormField<String>>(
    find.byType(DropdownButtonFormField<String>),
  ))
    dropdown.decoration.labelText!: dropdown.initialValue,
};
