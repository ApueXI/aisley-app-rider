import 'dart:async';

import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/features/batch/domain/final_mile_batch_models.dart';
import 'package:aisley_app/features/batch/presentation/controllers/final_mile_batch_controller.dart';
import 'package:aisley_app/features/batch/presentation/final_mile_batch_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/accessibility.dart';
import 'fixtures/final_mile_batch_screen_fixture.dart';

void main() {
  for (final scenario in AccessibilityScenario.matrix) {
    accessibilityTest('batch details accessible: ${scenario.name}', scenario, (
      tester,
    ) async {
      final repository = WidgetBatchRepository();
      final controller = FinalMileBatchController(repository: repository);
      final auth = batchAuthController();
      await tester.pumpWidget(
        scenario.app(
          FinalMileBatchDetailScreen(
            authController: auth,
            batchController: controller,
            scheduleId: 'schedule-1',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('DSP-100'), findsOneWidget);
      await checkScrollableAccessibility(tester);
      await focusByKeyboard(
        tester,
        find.widgetWithText(FilledButton, 'Accept entire batch'),
      );
      expect(repository.acceptCalls, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Accept this entire batch?'), findsOneWidget);
      await checkAccessibility(tester);
      await focusByKeyboard(tester, find.widgetWithText(TextButton, 'Cancel'));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expectKeyboardFocus(
        find.widgetWithText(FilledButton, 'Accept entire batch'),
      );
      expect(repository.acceptCalls, 0);
      await controller.accept('schedule-1');
      await tester.pumpAndSettle();
      await checkScrollableAccessibility(tester);
      expect(find.text('Entire batch accepted'), findsOneWidget);
      await unmount(tester, [controller, auth]);
    });
  }
  for (final scenario in AccessibilityScenario.stress) {
    accessibilityTest(
      'batch loading, unavailable and retry: ${scenario.name}',
      scenario,
      (tester) async {
        final pending = Completer<FinalMileBatch>();
        final repository = WidgetBatchRepository()..pendingRead = pending;
        final controller = FinalMileBatchController(repository: repository);
        final auth = batchAuthController();
        await tester.pumpWidget(
          scenario.app(
            FinalMileBatchDetailScreen(
              authController: auth,
              batchController: controller,
              scheduleId: 'schedule-1',
            ),
          ),
        );
        await tester.pump();
        await checkAccessibility(tester);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        pending.completeError(const ApiException.network('Test offline'));
        repository.pendingRead = null;
        await tester.pumpAndSettle();
        await checkScrollableAccessibility(tester);
        expect(find.text('Accept entire batch'), findsNothing);
        await reveal(tester, find.text('Retry'));
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
        await checkScrollableAccessibility(tester);
        expect(repository.acceptCalls, 0);
        await unmount(tester, [controller, auth]);
      },
    );
  }
}
