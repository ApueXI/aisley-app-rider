// ignore: depend_on_referenced_packages
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/registration_screen_fixture.dart';

void main() {
  setUp(() {
    final original = FileSelectorPlatform.instance;
    FileSelectorPlatform.instance = TestImagePicker();
    addTearDown(() => FileSelectorPlatform.instance = original);
  });
  testWidgets('step Back retains evidence without an exit decision', (
    tester,
  ) async {
    final fixture = RegistrationScreenFixture();
    await fixture.open(tester);
    await fixture.fill(tester);
    expect(registrationStep(tester), 5);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(registrationStep(tester), 4);
    expect(find.text('test-image.png'), findsNWidgets(2));
    expect(find.byType(AlertDialog), findsNothing);
    await nextRegistrationStep(tester);
    expect(registrationStep(tester), 5);
    expect(
      tester.widget<TextField>(field('Password')).controller!.text,
      'TestInput123',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    fixture.auth.dispose();
  });
  testWidgets(
    'verification expiry preserves drafts and evidence and clears passwords',
    (tester) async {
      var now = DateTime.utc(2026, 10, 15);
      final fixture = RegistrationScreenFixture()
        ..verificationClock = () => now;
      fixture.repository.clock = () => now;
      await fixture.open(tester);
      await fixture.fill(tester);
      now = now.add(const Duration(minutes: 61));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(registrationStep(tester), 0);
      expect(find.textContaining('Email verification expired'), findsOneWidget);
      expect(
        tester.widget<TextField>(field('First name')).controller!.text,
        'Ana',
      );
      expect(
        find.text('test-image.png', skipOffstage: false),
        findsNWidgets(2),
      );
      expect(
        tester.widget<TextField>(field('Password')).controller!.text,
        isEmpty,
      );
      expect(
        tester.widget<TextField>(field('Confirm password')).controller!.text,
        isEmpty,
      );
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'registration_email',
      );
      expect(fixture.repository.submissions, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      fixture.auth.dispose();
    },
  );
}
