import 'dart:async';

import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aisley_app/features/history/domain/history_models.dart';
import 'package:aisley_app/features/history/presentation/controllers/history_controller.dart';
import 'package:aisley_app/features/history/presentation/history_screen.dart';
import 'package:aisley_app/features/policy/data/policy_repository.dart';
import 'package:aisley_app/features/policy/domain/policy_models.dart';
import 'package:aisley_app/features/policy/presentation/controllers/policy_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/accessibility.dart';
import 'fixtures/history_search_fixture.dart';

void main() {
  testWidgets(
    'reopening History restores the submitted reference and its completed record',
    (tester) async {
      final repository = HistorySearchRepository()
        ..handler = (reference) async => historyPage(reference ?? 'UNFILTERED');
      final controller = HistoryController(historyRepository: repository);
      final auth = historyAuth();
      await controller.search('KNOWN-ORDER');
      await tester.pumpWidget(
        MaterialApp(
          home: HistoryScreen(
            key: const ValueKey('first'),
            authController: auth,
            historyController: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'UNSUBMITTED');
      await tester.pumpWidget(
        MaterialApp(
          home: HistoryScreen(
            key: const ValueKey('reopened'),
            authController: auth,
            historyController: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.references, [
        'KNOWN-ORDER',
        'KNOWN-ORDER',
        'KNOWN-ORDER',
      ]);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'KNOWN-ORDER',
      );
      expect(
        find.descendant(
          of: find.byType(ListTile),
          matching: find.text('KNOWN-ORDER'),
        ),
        findsOneWidget,
      );
      await unmount(tester, [controller, auth]);
    },
  );

  testWidgets(
    'account cleanup hides the record snapshot in an open detail screen',
    (tester) async {
      final controller = HistoryController(
        historyRepository: HistorySearchRepository(),
      );
      final auth = historyAuth();
      await tester.pumpWidget(
        MaterialApp(
          home: HistoryDetailScreen(
            authController: auth,
            historyController: controller,
            item: historyItem('PRIVATE-ORDER'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('PRIVATE-ORDER'), findsOneWidget);
      controller.clear();
      await tester.pumpAndSettle();
      expect(find.text('PRIVATE-ORDER'), findsNothing);
      expect(find.textContaining('no longer available'), findsOneWidget);
      await unmount(tester, [controller, auth]);
    },
  );

  testWidgets(
    'button search, draft editing, refresh, retry and Clear keep exact scope',
    (tester) async {
      final repository = HistorySearchRepository();
      final controller = HistoryController(historyRepository: repository);
      final auth = historyAuth();
      await tester.pumpWidget(
        MaterialApp(
          home: HistoryScreen(
            authController: auth,
            historyController: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.references, [null]);
      await tester.enterText(find.byType(TextField), '  ORDER-A  ');
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();
      expect(repository.references, [null, 'ORDER-A']);
      await tester.enterText(find.byType(TextField), 'UNSUBMITTED');
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pumpAndSettle();
      expect(repository.references.last, 'ORDER-A');
      expect(find.text('Results for order reference: ORDER-A'), findsOneWidget);
      repository.error = const ApiException.network('offline');
      await controller.load();
      await tester.pumpAndSettle();
      expect(find.text('Retry'), findsOneWidget);
      repository.error = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(repository.references.last, 'ORDER-A');
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
      expect(repository.references.last, isNull);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
        isTrue,
      );
      await unmount(tester, [controller, auth]);
    },
  );

  testWidgets('keyboard Search shows filtered empty and readable errors', (
    tester,
  ) async {
    final repository = HistorySearchRepository()
      ..page = const DeliveryHistoryPage(items: []);
    final controller = HistoryController(historyRepository: repository);
    final auth = historyAuth();
    await tester.pumpWidget(
      MaterialApp(
        home: HistoryScreen(
          authController: auth,
          historyController: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'KNOWN-REFERENCE');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(repository.references.last, 'KNOWN-REFERENCE');
    expect(
      find.text('No completed deliveries match this order reference.'),
      findsOneWidget,
    );
    repository.error = const ApiException.network(
      'timeout',
      networkFailure: ApiNetworkFailure.timeout,
    );
    await controller.retry();
    await tester.pumpAndSettle();
    expect(find.textContaining('request timed out'), findsOneWidget);
    expect(
      find.text('No completed deliveries match this order reference.'),
      findsNothing,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'KNOWN-REFERENCE',
    );
    await unmount(tester, [controller, auth]);
  });

  testWidgets('policy navigation recovers the active reference and draft', (
    tester,
  ) async {
    final repository = HistorySearchRepository();
    final controller = HistoryController(historyRepository: repository);
    final auth = historyAuth();
    final policy = PolicyController(policyApi: _AcceptedPolicyApi());
    await tester.pumpWidget(
      MaterialApp(
        home: HistoryScreen(
          authController: auth,
          historyController: controller,
          policyController: policy,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ORDER-A');
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'DRAFT-B');
    repository.error = const ApiException(
      statusCode: 403,
      code: 'POLICY_CONSENT_REQUIRED',
      message: 'accept policies',
    );
    await controller.load();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review policies'));
    await tester.pumpAndSettle();
    expect(find.text('Platform policies'), findsOneWidget);
    repository.error = null;
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(repository.references, [null, 'ORDER-A', 'ORDER-A', 'ORDER-A']);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'DRAFT-B',
    );
    await unmount(tester, [controller, auth, policy]);
  });

  testWidgets('logout erases draft and ignores an in-flight search', (
    tester,
  ) async {
    final repository = HistorySearchRepository();
    final controller = HistoryController(historyRepository: repository);
    final auth = historyAuth(onSessionEnded: controller.clear);
    await tester.pumpWidget(
      MaterialApp(
        home: HistoryScreen(
          authController: auth,
          historyController: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final pending = Completer<DeliveryHistoryPage>();
    repository.handler = (_) => pending.future;
    await tester.enterText(find.byType(TextField), 'PRIVATE-REFERENCE');
    await tester.tap(find.text('Search'));
    await tester.pump();
    await auth.signOut();
    await tester.pump();
    pending.complete(historyPage('PRIVATE-REFERENCE'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.activeReference, isNull);
    expect(controller.items, isEmpty);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(find.textContaining('PRIVATE-REFERENCE'), findsNothing);
    await unmount(tester, [controller, auth]);
  });

  testWidgets(
    'forbidden list response erases both submitted and draft references',
    (tester) async {
      final repository = HistorySearchRepository();
      final controller = HistoryController(historyRepository: repository);
      final auth = historyAuth();
      await tester.pumpWidget(
        MaterialApp(
          home: HistoryScreen(
            authController: auth,
            historyController: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'ORDER-A');
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'DRAFT-B');
      repository.error = const ApiException(
        statusCode: 403,
        code: 'COURIER_ACCESS_DENIED',
        message: 'denied',
      );
      await controller.load();
      await tester.pumpAndSettle();
      expect(controller.activeReference, isNull);
      expect(controller.items, isEmpty);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(find.textContaining('ORDER-A'), findsNothing);
      await unmount(tester, [controller, auth]);
    },
  );

  testWidgets(
    'cooldown disables Search and Retry, including keyboard submission',
    (tester) async {
      final repository = HistorySearchRepository();
      final controller = HistoryController(historyRepository: repository);
      final auth = historyAuth();
      await tester.pumpWidget(
        MaterialApp(
          home: HistoryScreen(
            authController: auth,
            historyController: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();
      repository.error = const ApiException(
        statusCode: 429,
        code: 'TOO_MANY_REQUESTS',
        message: 'wait',
        retryAfter: Duration(seconds: 5),
      );
      await tester.enterText(find.byType(TextField), 'ORDER-A');
      await tester.tap(find.text('Search'));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Search'))
            .onPressed,
        isNull,
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.tap(find.text('Clear'));
      await tester.pump();
      expect(repository.references, [null, 'ORDER-A']);
      expect(controller.activeReference, isNull);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Retry'),
            )
            .onPressed,
        isNull,
      );
      repository.error = null;
      await tester.pump(const Duration(seconds: 5));
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(repository.references.last, isNull);
      await unmount(tester, [controller, auth]);
    },
  );
}

class _AcceptedPolicyApi implements PolicyApi {
  @override
  Future<PolicyConsentStatus> fetchConsentStatus() async =>
      const PolicyConsentStatus(policies: [], allRequiredAccepted: true);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
