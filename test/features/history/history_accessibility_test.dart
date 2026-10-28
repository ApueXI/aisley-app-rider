import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/features/history/domain/history_models.dart';
import 'package:aisley_app/features/history/presentation/controllers/history_controller.dart';
import 'package:aisley_app/features/history/presentation/history_screen.dart';
import 'package:aisley_app/shared/presentation/destination_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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
            DestinationScope(
              visible: true,
              onBack: () {},
              child: HistoryScreen(
                authController: auth,
                historyController: controller,
              ),
            ),
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
            DestinationScope(
              visible: true,
              onBack: () {},
              child: HistoryScreen(
                authController: auth,
                historyController: controller,
              ),
            ),
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
          find.widgetWithText(OutlinedButton, 'Clear'),
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
  final textScale = MediaQuery.textScalerOf(
    tester.element(find.byType(Scaffold).first),
  ).scale(1);
  final narrowScreen =
      MediaQuery.sizeOf(tester.element(find.byType(Scaffold).first)).width <=
      320;
  final orderReferences = find.byWidgetPredicate(
    (widget) => widget is Text && widget.data?.startsWith('ORDER-') == true,
  );
  // At 320 px, Flutter exposes each button's 36 px content semantics box
  // even though its padded render and hit-test target are 48 px. Check each
  // revealed target directly there; keep the global guideline on wider screens.
  for (final control in [
    if (find.byTooltip('Back to Work').evaluate().isNotEmpty)
      find.byTooltip('Back to Work'),
    find.byType(TextField),
    find.widgetWithText(FilledButton, 'Search'),
    find.widgetWithText(OutlinedButton, 'Clear'),
    if (orderReferences.evaluate().isNotEmpty)
      find.ancestor(of: orderReferences.first, matching: find.byType(InkWell)),
    if (find.widgetWithText(OutlinedButton, 'Retry').evaluate().isNotEmpty)
      find.widgetWithText(OutlinedButton, 'Retry'),
    if (find.widgetWithText(TextButton, 'Retry').evaluate().isNotEmpty)
      find.widgetWithText(TextButton, 'Retry'),
  ]) {
    await reveal(tester, control);
    if (textScale > 1.25 || narrowScreen) {
      final bounds = tester.getRect(control);
      expect(bounds.width, greaterThanOrEqualTo(48));
      expect(bounds.height, greaterThanOrEqualTo(48));
      expect(control.hitTestable(), findsOneWidget);
      final semantics = tester.getSemantics(control).getSemanticsData();
      expect(
        semantics.label.trim().isNotEmpty ||
            semantics.tooltip.trim().isNotEmpty,
        isTrue,
        reason: 'The revealed control has an accessible label or tooltip.',
      );
      expect(semantics.hasAction(SemanticsAction.tap), isTrue);
      expect(tester.takeException(), isNull);
    } else {
      await checkAccessibility(tester);
    }
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
