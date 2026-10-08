import 'dart:async';

import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/features/support/domain/support_ticket_models.dart';
import 'package:aisley_app/features/support/presentation/controllers/support_ticket_controller.dart';
import 'package:aisley_app/features/support/presentation/support_ticket_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/accessibility.dart';
import 'fixtures/support_ticket_screen_fixture.dart';

void main() {
  for (final scenario in AccessibilityScenario.matrix) {
    accessibilityTest(
      'support list, create, detail and reply: ${scenario.name}',
      scenario,
      (tester) async {
        final repository = WidgetSupportRepository();
        final controller = SupportTicketController(repository: repository);
        final auth = supportAuthController();
        await tester.pumpWidget(
          scenario.app(
            SupportTicketScreen(controller: controller, authController: auth),
          ),
        );
        await tester.pumpAndSettle();
        await checkScrollableAccessibility(tester);
        expect(
          find.text('No support tickets match these filters.'),
          findsOneWidget,
        );
        await focusByKeyboard(
          tester,
          find.widgetWithText(FilledButton, 'Create support ticket'),
        );
        expect(repository.createCount, 0);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        await checkScrollableAccessibility(tester);
        final subject = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == 'Subject',
        );
        final message = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == 'Message',
        );
        await reveal(tester, subject);
        await tester.enterText(subject, 'Accessibility test issue');
        await focusByKeyboard(tester, message);
        await tester.enterText(message, 'Please help with the assigned task.');
        await pressTab(tester);
        await pressTab(tester, reverse: true);
        expect(repository.createCount, 0);
        await reveal(tester, find.text('Create ticket'));
        await tester.tap(find.text('Create ticket'));
        await tester.pumpAndSettle();
        expect(repository.createCount, 1);
        await checkScrollableAccessibility(tester);
        await focusByKeyboard(
          tester,
          find.widgetWithText(FilledButton, 'Send reply'),
        );
        expect(repository.replyCount, 0);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(repository.replyCount, 0); // Empty reply cannot be submitted.
        await tester.enterText(
          find.byType(TextField).last,
          'Additional test details',
        );
        await checkScrollableAccessibility(tester);
        expect(repository.replyCount, 0);
        await unmount(tester, [controller, auth]);
      },
    );
  }
  for (final scenario in AccessibilityScenario.stress) {
    accessibilityTest(
      'support offline retry and unread list: ${scenario.name}',
      scenario,
      (tester) async {
        final repository = WidgetSupportRepository()..showTicket = true;
        final controller = SupportTicketController(repository: repository);
        final auth = supportAuthController();
        await tester.pumpWidget(
          scenario.app(
            SupportTicketScreen(controller: controller, authController: auth),
          ),
        );
        await tester.pumpAndSettle();
        await checkScrollableAccessibility(tester);
        expect(
          find.bySemanticsLabel(RegExp('SUP-0001.*2 unread updates')),
          findsOneWidget,
        );
        await reveal(tester, find.text('Create support ticket'));
        await tester.tap(find.text('Create support ticket'));
        await tester.pumpAndSettle();
        final subject = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == 'Subject',
        );
        final message = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == 'Message',
        );
        await reveal(tester, subject);
        await tester.enterText(subject, 'Delivery issue');
        await reveal(tester, message);
        await tester.enterText(message, 'Task unavailable.');
        await tester.pumpAndSettle();
        repository.offlineCreate = true;
        await reveal(tester, find.text('Create ticket'));
        await tester.tap(find.text('Create ticket'));
        await tester.pumpAndSettle();
        await checkScrollableAccessibility(tester);
        expect(find.text('Retry same request'), findsOneWidget);
        expect(repository.createCount, 1);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        await checkAccessibility(tester);
        await focusByKeyboard(
          tester,
          find.widgetWithText(TextButton, 'Keep editing'),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(repository.createCount, 1);
        await unmount(tester, [controller, auth]);
      },
    );
  }
  for (final scenario in AccessibilityScenario.stress) {
    accessibilityTest(
      'support loading, offline and stale results: ${scenario.name}',
      scenario,
      (tester) async {
        final pending = Completer<SupportTicketPage>();
        final repository = WidgetSupportRepository()..pendingList = pending;
        final controller = SupportTicketController(repository: repository);
        final auth = supportAuthController();
        await tester.pumpWidget(
          scenario.app(
            SupportTicketScreen(controller: controller, authController: auth),
          ),
        );
        await tester.pump();
        await checkScrollableAccessibility(tester);
        pending.completeError(const ApiException.network('Test offline'));
        repository.pendingList = null;
        await tester.pumpAndSettle();
        await checkScrollableAccessibility(tester);
        expect(
          find.text('No support tickets match these filters.'),
          findsNothing,
        );
        repository.showTicket = true;
        await controller.refreshList();
        await tester.pumpAndSettle();
        repository.listError = const ApiException.network('Test offline');
        await controller.refreshList();
        await tester.pumpAndSettle();
        await checkScrollableAccessibility(tester);
        expect(find.textContaining('Showing saved results.'), findsOneWidget);
        expect(repository.createCount, 0);
        expect(repository.replyCount, 0);
        await unmount(tester, [controller, auth]);
      },
    );
  }
  for (final scenario in AccessibilityScenario.stress) {
    accessibilityTest(
      'support filter keyboard menu: ${scenario.name}',
      scenario,
      (tester) async {
        final repository = WidgetSupportRepository();
        final controller = SupportTicketController(repository: repository);
        final auth = supportAuthController();
        await tester.pumpWidget(
          scenario.app(
            SupportTicketScreen(controller: controller, authController: auth),
          ),
        );
        await tester.pumpAndSettle();
        final filter = find.byType(
          DropdownButtonFormField<SupportTicketStatusFilter>,
        );
        await focusByKeyboard(tester, filter);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pumpAndSettle();
        await checkAccessibility(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expectKeyboardFocus(filter);
        expect(controller.statusFilter, SupportTicketStatusFilter.all);
        expect(repository.createCount, 0);
        await unmount(tester, [controller, auth]);
      },
    );
  }
}
