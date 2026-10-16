import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aisley_app/features/delivery/domain/failed_delivery_attempt.dart';
import 'package:aisley_app/features/delivery/presentation/controllers/delivery_controller.dart';
import 'package:aisley_app/features/delivery/presentation/components/failed_delivery_attempt_form.dart';
import 'package:aisley_app/features/delivery/presentation/delivery_screen.dart';

import '../../helpers/accessibility.dart';
import 'fixtures/delivery_screen_fixture.dart';
import 'fixtures/failed_attempt_fixture.dart';

void main() {
  for (final scenario in AccessibilityScenario.matrix) {
    accessibilityTest(
      'report form, validation and history: ${scenario.name}',
      scenario,
      (tester) async {
        final repo = FailedAttemptRepository();
        final c = await readyFailedAttemptController(repo);
        final auth = deliveryAuthController();
        await tester.pumpWidget(
          scenario.app(
            DeliveryTaskScreen(
              authController: auth,
              deliveryController: c,
              task: outForDeliveryTask,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await reveal(tester, find.text('Report failed attempt'));
        await focusByKeyboard(
          tester,
          find.widgetWithText(OutlinedButton, 'Report failed attempt'),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        await checkScrollableAccessibility(tester);
        await reveal(tester, find.text('Submit report'));
        await tester.tap(find.text('Submit report'));
        await tester.pumpAndSettle();
        expect(find.text('Choose a reason.'), findsOneWidget);
        expect(repo.requests, isEmpty);
        await reveal(
          tester,
          find.byType(DropdownButtonFormField<FailedDeliveryReason>),
        );
        await tester.tap(
          find.byType(DropdownButtonFormField<FailedDeliveryReason>),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Other').last);
        await tester.pumpAndSettle();
        await reveal(tester, find.text('Submit report'));
        await tester.tap(find.text('Submit report'));
        await tester.pumpAndSettle();
        expect(
          find.text('Describe what prevented this delivery.'),
          findsOneWidget,
        );
        await reveal(tester, find.byType(TextFormField));
        await tester.enterText(find.byType(TextFormField), 'Building closed');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        await reveal(tester, find.text('Submit report'));
        await tester.tap(find.text('Submit report'));
        await tester.pumpAndSettle();
        expect(repo.requests, hasLength(1));
        expect(repo.requests.single.reason, FailedDeliveryReason.other);
        expect(find.byType(FailedDeliveryAttemptForm), findsNothing);
        await reveal(tester, find.text('Recorded attempts: 1'));
        expect(find.textContaining('Building closed'), findsOneWidget);
        expect(
          find.text(
            'Failed attempt recorded. Use a fresh photo for the next delivery.',
          ),
          findsOneWidget,
        );
        await checkScrollableAccessibility(tester);
        await unmount(tester, [c, auth]);
      },
    );
  }

  testWidgets(
    'uncertain payload remains locked across Back and reopen; exact retry succeeds',
    (tester) async {
      final repo = FailedAttemptRepository()
        ..reportError = const ApiException.network('offline');
      final c = await readyFailedAttemptController(repo);
      final auth = deliveryAuthController();
      await tester.pumpWidget(
        MaterialApp(
          home: DeliveryTaskScreen(
            authController: auth,
            deliveryController: c,
            task: outForDeliveryTask,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Report failed attempt'));
      await tester.tap(find.text('Report failed attempt'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byType(DropdownButtonFormField<FailedDeliveryReason>),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Recipient unavailable').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit report'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField)).enabled,
        isFalse,
      );
      await tester.tap(find.text('Back to delivery'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Review unconfirmed report'));
      await tester.tap(find.text('Review unconfirmed report'));
      await tester.pumpAndSettle();
      expect(find.text('Recipient unavailable'), findsOneWidget);
      repo.reportError = null;
      await reveal(tester, find.text('Retry same report'));
      await tester.tap(find.text('Retry same report'));
      await tester.pumpAndSettle();
      expect(repo.requests, hasLength(2));
      expect(
        repo.requests.first.idempotencyKey,
        repo.requests.last.idempotencyKey,
      );
      await unmount(tester, [c, auth]);
    },
  );

  testWidgets('cancel confirms unsent draft; keeping it preserves user input', (
    tester,
  ) async {
    final repo = FailedAttemptRepository();
    final c = await readyFailedAttemptController(repo);
    final auth = deliveryAuthController();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => FailedDeliveryAttemptForm(
                    task: outForDeliveryTask,
                    controller: c,
                    authController: auth,
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Draft note');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Discard this draft?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Draft note'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard draft'));
    await tester.pumpAndSettle();
    expect(find.byType(FailedDeliveryAttemptForm), findsNothing);
    expect(repo.requests, isEmpty);
    await unmount(tester, [c, auth]);
  });

  testWidgets('pending completion disables reporting on the task', (
    tester,
  ) async {
    final repo = FailedAttemptRepository()..pendingCompletion = true;
    final c = await readyFailedAttemptController(repo);
    final auth = deliveryAuthController();
    await tester.pumpWidget(
      MaterialApp(
        home: DeliveryTaskScreen(
          authController: auth,
          deliveryController: c,
          task: outForDeliveryTask,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Report failed attempt'));
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Report failed attempt'),
          )
          .onPressed,
      isNull,
    );
    expect(
      find.text(
        'Reporting is unavailable while Logistics reviews this delivery.',
      ),
      findsOneWidget,
    );
    await unmount(tester, [c, auth]);
  });
  testWidgets(
    'busy form blocks duplicate submits; logout clears local draft and leaves private routes',
    (tester) async {
      final repo = FailedAttemptRepository()..delayedReport = Completer();
      final c = await readyFailedAttemptController(repo);
      final auth = deliveryAuthController();
      await tester.pumpWidget(
        MaterialApp(
          home: DeliveryTaskScreen(
            authController: auth,
            deliveryController: c,
            task: outForDeliveryTask,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Report failed attempt'));
      await tester.tap(find.text('Report failed attempt'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byType(DropdownButtonFormField<FailedDeliveryReason>),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Other').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Private draft');
      await reveal(tester, find.text('Submit report'));
      await tester.tap(find.text('Submit report'));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Retry same report'),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField)).enabled,
        isFalse,
      );
      c.clear();
      await auth.signOut();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(auth.status, isNot(AuthStatus.authenticated));
      expect(find.byType(FailedDeliveryAttemptForm), findsNothing);
      repo.delayedReport!.complete(
        receiptFor(
          outForDeliveryTask.id,
          FailedDeliveryReason.other,
          'Private draft',
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(c.failedAttemptReceipts, isEmpty);
      expect(c.pendingFailedAttempt(outForDeliveryTask), isNull);
      await unmount(tester, [c, auth]);
    },
  );
}
