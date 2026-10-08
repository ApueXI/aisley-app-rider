import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';

import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/features/account/presentation/controllers/account_controller.dart';
import 'package:aisley_app/features/auth/presentation/controllers/auth_controller.dart';

import '../auth/fixtures/registration_screen_fixture.dart';

import 'fixtures/account_screen_fixture.dart';

void main() {
  setUp(() {
    final original = FileSelectorPlatform.instance;
    FileSelectorPlatform.instance = TestImagePicker();
    addTearDown(() => FileSelectorPlatform.instance = original);
  });
  testWidgets('renders the server-backed account form and read-only details', (
    WidgetTester tester,
  ) async {
    await openAccount(tester);

    expect(find.text('Personal information'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('Account details'), findsOneWidget);
    expect(find.text('Aisley Express'), findsOneWidget);
    expect(find.text('Main Hub'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('Security'), findsOneWidget);
    expect(find.text('Change password'), findsOneWidget);
  });

  for (final systemBack in [false, true]) {
    testWidgets(
      'account ${systemBack ? 'system' : 'toolbar'} Back protects profile drafts',
      (tester) async {
        await openAccount(tester);
        await enter(tester, 'First name', 'Edited');
        Future<void> back() async {
          if (systemBack) {
            await tester.binding.handlePopRoute();
          } else {
            await tester.tap(find.byTooltip('Back'));
          }
          await tester.pumpAndSettle();
        }

        await back();
        expect(find.text('Discard unsaved changes?'), findsOneWidget);
        await tester.tap(find.text('Keep editing'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(field('First name')).controller!.text,
          'Edited',
        );
        await back();
        await tester.tap(find.text('Discard'));
        await tester.pumpAndSettle();
        expect(find.text('Account destination'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'unchanged, reverted, and saved account profiles leave without a prompt',
    (tester) async {
      for (final mode in ['unchanged', 'reverted', 'saved']) {
        await openAccount(tester);
        if (mode != 'unchanged') await enter(tester, 'First name', 'Edited');
        if (mode == 'reverted') await enter(tester, 'First name', 'Ana');
        if (mode == 'saved') {
          await tester.ensureVisible(find.text('Save profile'));
          await tester.tap(find.text('Save profile'));
          await tester.pumpAndSettle();
        }
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('Account destination'), findsOneWidget);
        expect(find.byType(AlertDialog), findsNothing);
      }
    },
  );

  testWidgets(
    'password drafts are protected and successful change clears drafts without a second prompt',
    (tester) async {
      final (auth, account) = await openAccount(tester);
      await enter(tester, 'First name', 'Edited');
      await enter(tester, 'Current password', 'TestCurrent123');
      await enter(tester, 'New password', 'TestNew123');
      await enter(tester, 'Confirm new password', 'TestNew123');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Change password'));
      await tester.tap(find.text('Change password'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Unsaved profile changes'), findsOneWidget);
      await tester.tap(find.text('Change password').last);
      await tester.pumpAndSettle();
      expect(account.status, AccountStatus.signedOut);
      expect(auth.status, AuthStatus.signedOut);
      expect(find.text('Account destination'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets('pending photo alone is protected on exit', (tester) async {
    await openAccount(tester);
    await tester.ensureVisible(find.text('Choose photo'));
    await tester.tap(find.text('Choose photo'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Upload photo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'session expiry dismisses an open discard prompt and clears local drafts',
    (tester) async {
      final (auth, _) = await openAccount(tester);
      await enter(tester, 'First name', 'Edited');
      final draft = tester.widget<TextField>(field('First name')).controller!;
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await auth.signOut();
      await tester.pumpAndSettle();
      expect(draft.text, isEmpty);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Account destination'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'account denial clears drafts and exits without discard confirmation',
    (tester) async {
      final repository = FakeAccountRepository();
      final (_, account) = await openAccount(tester, repository: repository);
      await enter(tester, 'First name', 'Edited');
      repository.fetchError = const ApiException(
        statusCode: 403,
        code: 'LOGISTICS_ASSOCIATION_INVALID',
        message: 'Denied',
      );
      await account.loadAccount();
      await tester.pumpAndSettle();
      expect(find.text('Account destination'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets(
    'validation reveals first account error and preserves recoverable edits',
    (tester) async {
      final repository = FakeAccountRepository();
      repository.saveError = const ApiException(
        statusCode: 422,
        code: 'VALIDATION_ERROR',
        message: 'Invalid',
        fieldErrors: {
          'contact_number': ['Invalid contact.'],
          'first_name': ['Invalid first name.'],
        },
      );
      await openAccount(tester, repository: repository);
      await enter(tester, 'First name', 'Edited');
      await tester.ensureVisible(find.text('Save profile'));
      await tester.tap(find.text('Save profile'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(field('First name')).focusNode!.hasFocus,
        true,
      );
      expect(
        tester.widget<TextField>(field('First name')).controller!.text,
        'Edited',
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Discard unsaved changes?'), findsOneWidget);
    },
  );
}
