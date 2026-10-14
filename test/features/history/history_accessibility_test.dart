import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/features/history/domain/history_models.dart';
import 'package:aisley_app/features/history/presentation/controllers/history_controller.dart';
import 'package:aisley_app/features/history/presentation/history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/accessibility.dart';
import 'fixtures/history_search_fixture.dart';

void main() {
  for (final scenario in AccessibilityScenario.stress) {
    accessibilityTest(
      'history error, stale rows and retry: ${scenario.name}',
      scenario,
      (tester) async {
        final repository = HistorySearchRepository()
          ..error = const ApiException(
            statusCode: 503,
            code: 'FULFILLMENT_UNAVAILABLE',
            message: 'unavailable',
          );
        final controller = HistoryController(historyRepository: repository);
        final auth = historyAuth();
        await tester.pumpWidget(
          scenario.app(
            HistoryScreen(authController: auth, historyController: controller),
          ),
        );
        await tester.pumpAndSettle();
        await _checkHistoryAccessibility(tester);
        expect(
          find.text('No completed final-mile deliveries are available.'),
          findsNothing,
        );
        repository.error = null;
        await controller.search('ORDER-A');
        repository.error = const ApiException.network('offline');
        await controller.load();
        await tester.pumpAndSettle();
        expect(controller.items, isNotEmpty);
        await _checkHistoryAccessibility(tester);
        await _focusHistoryByKeyboard(
          tester,
          find.widgetWithText(TextButton, 'Retry'),
        );
        repository.error = null;
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(repository.references.last, 'ORDER-A');
        await unmount(tester, [controller, auth]);
      },
    );
  }
  for (final scenario in AccessibilityScenario.matrix) {
    accessibilityTest(
      'history search, keyboard focus and bounded results: ${scenario.name}',
      scenario,
      (tester) async {
        final repository = HistorySearchRepository()
          ..page = const DeliveryHistoryPage(items: []);
        final controller = HistoryController(historyRepository: repository);
        final auth = historyAuth();
        await tester.pumpWidget(
          scenario.app(
            HistoryScreen(authController: auth, historyController: controller),
          ),
        );
        await tester.pumpAndSettle();
        await _checkHistoryAccessibility(tester);
        await _focusHistoryByKeyboard(tester, find.byType(TextField));
        await tester.enterText(find.byType(TextField), 'ORDER-A');
        await _focusHistoryByKeyboard(
          tester,
          find.widgetWithText(FilledButton, 'Search'),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(repository.references.last, 'ORDER-A');
        await _checkHistoryAccessibility(tester);
        repository.page = DeliveryHistoryPage(
          items: [historyItem()],
          hasMore: true,
          nextCursor: 'unsupported-cursor',
        );
        await controller.load();
        await tester.pumpAndSettle();
        await _checkHistoryAccessibility(tester);
        expect(find.text('Load more'), findsNothing);
        expect(
          find.textContaining('Search by the full order reference'),
          findsOneWidget,
        );
        await _focusHistoryByKeyboard(
          tester,
          find.widgetWithText(TextButton, 'Clear'),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
          isTrue,
        );
        expect(repository.references.last, isNull);
        await unmount(tester, [controller, auth]);
      },
    );
  }
}

Future<void> _checkHistoryAccessibility(WidgetTester tester) async {
  // Align checks to whole controls: arbitrary page increments can clip a
  // field's semantics bounds and falsely report a reduced touch target.
  for (final control in [
    find.byType(TextField),
    find.widgetWithText(FilledButton, 'Search'),
    find.widgetWithText(TextButton, 'Clear'),
    if (find.byType(Card).evaluate().isNotEmpty) find.byType(Card).first,
    if (find.byType(ListTile).evaluate().isNotEmpty)
      find.byType(ListTile).first,
    if (find.widgetWithText(OutlinedButton, 'Retry').evaluate().isNotEmpty)
      find.widgetWithText(OutlinedButton, 'Retry'),
    if (find.widgetWithText(TextButton, 'Retry').evaluate().isNotEmpty)
      find.widgetWithText(TextButton, 'Retry'),
  ]) {
    await reveal(tester, control);
    await checkAccessibility(tester);
  }
}

Future<void> _focusHistoryByKeyboard(
  WidgetTester tester,
  Finder control,
) async {
  await reveal(tester, control);
  await tester.pumpAndSettle();
  final target = control.evaluate().single;
  for (var step = 0; step < 80; step++) {
    final context = FocusManager.instance.primaryFocus?.context;
    var ownsFocus = context == target;
    context?.visitAncestorElements((ancestor) {
      if (ancestor == target) ownsFocus = true;
      return !ownsFocus;
    });
    if (ownsFocus) {
      expect(control.hitTestable(), findsOneWidget);
      return;
    }
    await pressTab(tester);
    // Material reveals the caret after the focus frame. Finish the resulting
    // scroll and layout before measuring the focused control's hit target.
    await tester.pumpAndSettle();
  }
  fail('Keyboard traversal did not reach $control');
}
