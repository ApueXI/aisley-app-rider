import 'dart:async';

import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/features/auth/domain/auth_models.dart';
// ignore: depend_on_referenced_packages
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/registration_screen_fixture.dart';

void main() {
  setUp(() {
    final original = FileSelectorPlatform.instance;
    FileSelectorPlatform.instance = TestImagePicker();
    addTearDown(() => FileSelectorPlatform.instance = original);
  });

  for (final exit in ['Back', 'Sign in', 'System Back']) {
    Future<void> leave(WidgetTester tester) async {
      if (exit == 'System Back') {
        await tester.binding.handlePopRoute();
      } else if (exit == 'Back') {
        await tester.tap(find.byTooltip('Return to sign in'));
      } else {
        await tester.ensureVisible(find.text('Already registered? Sign in'));
        await tester.tap(find.text('Already registered? Sign in'));
      }
      await tester.pumpAndSettle();
    }

    testWidgets(
      'untouched registration leaves through $exit without a prompt',
      (tester) async {
        await RegistrationScreenFixture().open(tester);
        await leave(tester);
        expect(find.text('Sign in destination'), findsOneWidget);
        expect(find.byType(AlertDialog), findsNothing);
      },
    );

    testWidgets(
      '$exit preserves a draft on Keep editing and leaves on Discard',
      (tester) async {
        await RegistrationScreenFixture().open(tester);
        await enter(tester, 'First name', 'Ana');
        await leave(tester);
        expect(find.text('Discard unsaved changes?'), findsOneWidget);
        await tester.tap(find.text('Keep editing'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(field('First name')).controller!.text,
          'Ana',
        );
        await leave(tester);
        await tester.tap(find.text('Discard'));
        await tester.pumpAndSettle();
        expect(find.text('Sign in destination'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'selected evidence alone is protected and cancelled exit retains it',
    (tester) async {
      await RegistrationScreenFixture().open(tester);
      await tester.ensureVisible(find.text('Choose').first);
      await tester.tap(find.text('Choose').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Return to sign in'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('test-image.png'), findsOneWidget);
    },
  );

  testWidgets(
    'password toggles are independent and keyboard Next/Tab follow field order',
    (tester) async {
      await RegistrationScreenFixture().open(tester);
      await enter(tester, 'Password', 'TestInput123');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Show password'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      expect(tester.widget<TextField>(field('Password')).obscureText, false);
      expect(
        tester.widget<TextField>(field('Confirm password')).obscureText,
        true,
      );
      await tester.ensureVisible(find.byTooltip('Show confirm password'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Show confirm password'));
      await tester.pump();
      expect(
        tester.widget<TextField>(field('Confirm password')).obscureText,
        false,
      );
      await enter(tester, 'First name', 'Ana');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(field('Last name')).focusNode!.hasFocus,
        true,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(field('Middle initial (optional)'))
            .focusNode!
            .hasFocus,
        true,
      );
    },
  );

  testWidgets(
    'local validation scrolls to and focuses the first invalid field at large text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final fixture = RegistrationScreenFixture();
      await fixture.open(tester, textScale: 1.8);
      await fixture.submit(tester);
      expect(
        tester.widget<TextField>(field('First name')).focusNode!.hasFocus,
        true,
      );
      expect(field('First name').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('missing evidence receives focus and is not submitted', (
    tester,
  ) async {
    final fixture = RegistrationScreenFixture();
    await fixture.open(tester);
    await fixture.fill(tester, evidence: false);
    await fixture.submit(tester);
    expect(find.text('Select a government ID image.'), findsWidgets);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'government_id');
    expect(fixture.repository.submissions, 0);
  });

  testWidgets(
    'server errors use form order, preserve input/files, and clear passwords',
    (tester) async {
      final fixture = RegistrationScreenFixture();
      fixture.repository.error = const ApiException(
        statusCode: 422,
        code: 'VALIDATION_ERROR',
        message: 'The given data was invalid.',
        fieldErrors: {
          'address[postal_code]': ['Invalid postal code.'],
          'email': ['Choose another email.'],
        },
      );
      await fixture.open(tester);
      await fixture.fill(tester);
      await fixture.submit(tester);
      expect(
        tester.widget<TextField>(field('Email')).focusNode!.hasFocus,
        true,
      );
      expect(
        tester.widget<TextField>(field('First name')).controller!.text,
        'Ana',
      );
      expect(
        tester.widget<TextField>(field('Password')).controller!.text,
        isEmpty,
      );
      expect(
        tester.widget<TextField>(field('Confirm password')).controller!.text,
        isEmpty,
      );
      expect(find.text('test-image.png'), findsNWidgets(2));
      expect(find.text('Invalid postal code.'), findsOneWidget);
    },
  );

  testWidgets('a missing PSGC selection scrolls to and focuses Region', (
    tester,
  ) async {
    final fixture = RegistrationScreenFixture();
    await fixture.open(tester);
    await fixture.fill(tester, manualAddress: false);
    await fixture.submit(tester);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'address.region');
    expect(
      find.text('Select a region from the address directory.'),
      findsWidgets,
    );
    expect(fixture.repository.submissions, 0);
  });

  testWidgets(
    'server bracket address errors navigate to the matching manual field',
    (tester) async {
      final fixture = RegistrationScreenFixture();
      fixture.repository.error = const ApiException(
        statusCode: 422,
        code: 'VALIDATION_ERROR',
        message: 'Invalid',
        fieldErrors: {
          'address[postal_code]': ['Invalid postal code.'],
        },
      );
      await fixture.open(tester);
      await fixture.fill(tester);
      await fixture.submit(tester);
      expect(
        tester.widget<TextField>(field('Postal code')).focusNode!.hasFocus,
        true,
      );
      expect(field('Postal code').hitTestable(), findsOneWidget);
    },
  );

  testWidgets(
    'large-text discard dialog exposes both actions and defaults to Keep editing',
    (tester) async {
      final semantics = tester.ensureSemantics();

      await tester.binding.setSurfaceSize(const Size(390, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await RegistrationScreenFixture().open(tester, textScale: 1.8);
      await enter(tester, 'First name', 'Ana');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Keep editing'), findsOneWidget);
      expect(find.bySemanticsLabel('Discard'), findsOneWidget);
      expect(find.text('Keep editing').hitTestable(), findsOneWidget);
      expect(find.text('Discard').hitTestable(), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        tester.widget<TextField>(field('First name')).controller!.text,
        'Ana',
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets('successful registration returns to sign in without discard', (
    tester,
  ) async {
    final fixture = RegistrationScreenFixture();
    await fixture.open(tester);
    await fixture.fill(tester);
    await fixture.submit(tester);
    expect(find.text('Application submitted'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Sign in destination'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets(
    'submission blocks Back; cancellation clears passwords and protects remaining draft',
    (tester) async {
      final fixture = RegistrationScreenFixture();
      fixture.repository.pending = Completer<RegistrationResult>();
      await fixture.open(tester);
      await fixture.fill(tester);
      await tester.ensureVisible(find.text('Submit registration'));
      await tester.tap(find.text('Submit registration'));
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Sign in destination'), findsNothing);
      await tester.ensureVisible(find.text('Cancel upload'));
      await tester.tap(find.text('Cancel upload'));
      await tester.pumpAndSettle();
      expect(fixture.repository.cancelled, true);
      expect(
        tester.widget<TextField>(field('Password')).controller!.text,
        isEmpty,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Discard unsaved changes?'), findsOneWidget);
    },
  );
}
