import 'dart:async';

import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/core/networking/api_contract_exception.dart';
import 'package:aisley_app/features/auth/data/auth_repository.dart';
import 'package:aisley_app/features/auth/domain/auth_models.dart';
import 'package:aisley_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aisley_app/features/dashboard/data/dashboard_repository.dart';
import 'package:aisley_app/features/dashboard/domain/dashboard_models.dart';
import 'package:aisley_app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('unavailable summaries share one readable notice', (
    tester,
  ) async {
    final repository = _SummaryRepository();
    final auth = _auth(repository);
    addTearDown(auth.dispose);
    await _show(tester, auth);

    expect(
      find.textContaining('Work summaries are unavailable'),
      findsOneWidget,
    );
    expect(find.textContaining('Open a work list'), findsOneWidget);
    expect(find.text('Unavailable'), findsNothing);
    expect(find.text('No items available'), findsNothing);
    expect(find.textContaining('aggregate'), findsNothing);
    expect(find.text('Accept'), findsNothing);
    expect(repository.reads, 1);
  });

  testWidgets('first load does not claim summaries are unavailable', (
    tester,
  ) async {
    final pending = Completer<DashboardSnapshot>();
    final repository = _SummaryRepository()..pending = pending;
    final auth = _auth(repository);
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      MaterialApp(home: DashboardScreen(authController: auth)),
    );
    await tester.pump();

    expect(find.text('Checking work…'), findsOneWidget);
    expect(find.textContaining('Work summaries are unavailable'), findsNothing);
    pending.complete(_scaffold);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Work summaries are unavailable'),
      findsOneWidget,
    );
  });

  testWidgets('failed first read shows recovery without a false empty state', (
    tester,
  ) async {
    final repository = _SummaryRepository()
      ..error = const ApiException.network('private connection detail');
    final auth = _auth(repository);
    addTearDown(auth.dispose);
    await _show(tester, auth);

    expect(
      find.textContaining('Check your connection and retry'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('Work summaries are unavailable'), findsNothing);
    expect(find.text('Nothing to show'), findsNothing);
    expect(find.textContaining('private connection detail'), findsNothing);
    repository.error = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Work summaries are unavailable'),
      findsOneWidget,
    );
  });

  testWidgets('failed refresh retains last known availability and a retry', (
    tester,
  ) async {
    final repository = _SummaryRepository();
    final auth = _auth(repository);
    addTearDown(auth.dispose);
    await _show(tester, auth);
    repository.error = const ApiException.network('offline');
    await auth.loadDashboard();
    await tester.pumpAndSettle();

    expect(find.textContaining('earlier work information'), findsOneWidget);
    expect(
      find.textContaining('Work summaries are unavailable'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Check your connection and retry'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(auth.dashboard, same(_scaffold));
  });

  testWidgets('refresh preserves availability while showing loading', (
    tester,
  ) async {
    final repository = _SummaryRepository();
    final auth = _auth(repository);
    addTearDown(auth.dispose);
    await _show(tester, auth);
    final pending = Completer<DashboardSnapshot>();
    repository.pending = pending;
    final refresh = auth.loadDashboard();
    await tester.pump();

    expect(find.textContaining('Refreshing work'), findsOneWidget);
    expect(
      find.textContaining('Work summaries are unavailable'),
      findsOneWidget,
    );
    pending.complete(_scaffold);
    await refresh;
    await tester.pumpAndSettle();
  });

  testWidgets(
    'invalid response never becomes an unavailable or empty summary',
    (tester) async {
      final repository = _SummaryRepository()
        ..error = const ApiContractException('dashboard.sections.active_tasks');
      final auth = _auth(repository);
      addTearDown(auth.dispose);
      await _show(tester, auth);

      expect(
        find.textContaining('summaries could not be loaded'),
        findsOneWidget,
      );
      expect(find.textContaining('dashboard.sections'), findsNothing);
      expect(
        find.textContaining('Work summaries are unavailable'),
        findsNothing,
      );
      expect(find.text('Nothing to show'), findsNothing);
    },
  );

  testWidgets('different section states are not consolidated', (tester) async {
    final repository = _SummaryRepository()
      ..snapshot = const DashboardSnapshot(
        sections: {
          'notifications': DashboardSection(
            state: DashboardSectionState.unavailable,
          ),
          'available_tasks': DashboardSection(
            state: DashboardSectionState.failed,
          ),
          'active_tasks': DashboardSection(state: DashboardSectionState.stale),
        },
        freshness: DashboardFreshness(state: DashboardFreshnessState.stale),
      );
    final auth = _auth(repository);
    addTearDown(auth.dispose);
    await _show(tester, auth);

    expect(find.text('Unavailable'), findsOneWidget);
    expect(find.text('Could not load'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Needs refresh'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Needs refresh'), findsOneWidget);
    expect(find.textContaining('Work summaries are unavailable'), findsNothing);
  });

  testWidgets('stale work is labeled and recoverable by its own section', (
    tester,
  ) async {
    final repository = _SummaryRepository()
      ..snapshot = const DashboardSnapshot(
        sections: {
          'active_tasks': DashboardSection(
            state: DashboardSectionState.stale,
            generatedAt: '2026-10-28T01:45:00Z',
            items: [
              {
                'id': 'synthetic-task',
                'leg': 'first_mile',
                'status': 'accepted',
                'order_reference': 'ORD-SYNTHETIC',
              },
            ],
          ),
          'available_tasks': DashboardSection(
            state: DashboardSectionState.empty,
          ),
          'notifications': DashboardSection(state: DashboardSectionState.empty),
        },
        freshness: DashboardFreshness(state: DashboardFreshnessState.partial),
      );
    final auth = _auth(repository);
    addTearDown(auth.dispose);
    await _show(tester, auth);

    expect(find.text('Needs refresh'), findsOneWidget);
    expect(
      find.text(
        'Showing earlier data for this section. Refresh before acting.',
      ),
      findsOneWidget,
    );
    expect(find.text('ORD-SYNTHETIC'), findsOneWidget);
    expect(find.text('No available work.'), findsOneWidget);
    expect(find.text('No recent notifications.'), findsOneWidget);
    expect(find.text('Task ID'), findsNothing);
  });

  testWidgets('notice and retry remain accessible at large text sizes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    final repository = _SummaryRepository();
    final auth = _auth(repository);
    addTearDown(auth.dispose);
    await _show(tester, auth, scale: 2);

    final notice = find.textContaining('Work summaries are unavailable');
    await tester.scrollUntilVisible(
      notice,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    final liveRegions = find.ancestor(
      of: notice,
      matching: find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.liveRegion == true,
      ),
    );
    expect(liveRegions, findsOneWidget);
    expect(
      tester.getSemantics(liveRegions).label,
      contains('Work summaries are unavailable'),
    );
    expect(tester.takeException(), isNull);
    repository.error = const ApiException.network('offline');
    await auth.loadDashboard();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Retry'),
      -100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}

Future<void> _show(
  WidgetTester tester,
  AuthController auth, {
  double scale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: DashboardScreen(authController: auth),
    ),
  );
  await tester.pumpAndSettle();
}

AuthController _auth(DashboardRepository repository) =>
    AuthController(
        authRepository: _UnusedAuthRepository(),
        dashboardRepository: repository,
      )
      ..status = AuthStatus.authenticated
      ..courier = CourierIdentity.fromJson(const {
        'id': 'courier-1',
        'email': 'courier@example.com',
        'role': 'courier',
        'status': 'active',
        'profile': {'first_name': 'Maya', 'last_name': 'Santos'},
      });

class _UnusedAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _SummaryRepository implements DashboardRepository {
  Object? error;
  Completer<DashboardSnapshot>? pending;
  DashboardSnapshot snapshot = _scaffold;
  int reads = 0;

  @override
  Future<DashboardSnapshot> fetchDashboard() async {
    reads++;
    if (error case final failure?) throw failure;
    if (pending case final response?) return response.future;
    return snapshot;
  }
}

const _scaffold = DashboardSnapshot(
  sections: {
    'notifications': DashboardSection(state: DashboardSectionState.unavailable),
    'available_tasks': DashboardSection(
      state: DashboardSectionState.unavailable,
    ),
    'active_tasks': DashboardSection(state: DashboardSectionState.unavailable),
  },
  freshness: DashboardFreshness(state: DashboardFreshnessState.scaffold),
);
