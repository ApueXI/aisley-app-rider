import 'package:aisley_app/shared/presentation/courier_viewport.dart';
import 'package:aisley_app/app/courier_theme.dart';
import 'package:aisley_app/app/courier_app.dart';
import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/features/auth/domain/auth_models.dart';
import 'package:aisley_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aisley_app/features/chat/data/chat_repository.dart';
import 'package:aisley_app/features/chat/domain/chat_models.dart';
import 'package:aisley_app/features/chat/presentation/controllers/chat_controller.dart';
import 'package:aisley_app/features/dashboard/data/dashboard_repository.dart';
import 'package:aisley_app/features/dashboard/domain/dashboard_models.dart';
import 'package:aisley_app/features/delivery/presentation/controllers/delivery_controller.dart';
import 'package:aisley_app/features/notification/presentation/controllers/notification_controller.dart';
import 'package:aisley_app/features/pickup/domain/pickup_models.dart';
import 'package:aisley_app/features/pickup/presentation/controllers/pickup_controller.dart';
import 'package:aisley_app/shared/presentation/destination_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/accessibility.dart';
import '../auth/fixtures/registration_screen_fixture.dart';
import '../notification/fixtures/navigation_fixture.dart';

void main() {
  for (final scenario in [
    ...AccessibilityScenario.matrix,
    const AccessibilityScenario(Size(1100, 800), 2, Brightness.light),
  ]) {
    accessibilityTest('shell navigation ${scenario.name}', scenario, (
      tester,
    ) async {
      final fixture = _ShellFixture();
      await fixture.open(tester, scenario: scenario);
      await checkAccessibility(tester);
      final activeWork = find.text('Active work');
      final availableWork = find.text('Available work');
      if (scenario.scale <= 1.25) {
        expect(
          tester.getTopLeft(activeWork).dy,
          lessThan(tester.getTopLeft(availableWork).dy),
        );
      } else {
        await tester.scrollUntilVisible(
          activeWork,
          100,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.scrollUntilVisible(
          availableWork,
          100,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Available work'), findsOneWidget);
      }
      await tester.tap(find.byType(NavigationDestination).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pickup orders'));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      await _openFirstTask(tester);
      await tester.pumpAndSettle();
      expect(find.text('Pickup order'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Pickup orders'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('AISLEY Rider'), findsOneWidget);
      fixture.expectNoWrites();
      await fixture.close(tester);
    });
  }

  testWidgets('Home, Work and Account follow the AISLEY Rider shell', (
    tester,
  ) async {
    final fixture = _ShellFixture();
    await fixture.open(tester);

    expect(find.text('AISLEY Rider'), findsOneWidget);
    expect(find.text('Maya Santos'), findsOneWidget);
    expect(find.text('AISLEY Express · Makati Hub'), findsOneWidget);
    expect(find.text('Pickup orders'), findsOneWidget);
    expect(find.text('Delivery work'), findsOneWidget);

    await tester.tap(find.byType(NavigationDestination).at(1));
    await tester.pumpAndSettle();
    for (final title in [
      'Pickup orders',
      'Delivery work',
      'Final-mile batches',
      'Linehaul jobs',
      'Delivery history',
    ]) {
      expect(find.text(title), findsOneWidget);
    }
    expect(find.textContaining('Dispatch queue access'), findsNothing);
    expect(find.textContaining('Network node'), findsNothing);
    expect(find.text('Protocol'), findsNothing);

    await tester.tap(find.byType(NavigationDestination).at(3));
    await tester.pumpAndSettle();
    expect(find.text('Maya Santos'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Affiliation approved'), findsOneWidget);
    for (final title in [
      'Profile',
      'Security',
      'Vehicle and documents',
      'Policies',
      'Support tickets',
    ]) {
      expect(find.text(title), findsOneWidget);
    }
    expect(find.textContaining('Courier ID'), findsNothing);
    expect(find.textContaining('Biometrics'), findsNothing);
    expect(find.textContaining('License number'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Sign out'),
      100,
      scrollable: find
          .descendant(
            of: find.byKey(const PageStorageKey('account-menu')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    final signOut = find.widgetWithText(OutlinedButton, 'Sign out');
    expect(signOut, findsOneWidget);
    await tester.ensureVisible(signOut);
    await tester.pumpAndSettle();
    await tester.tap(signOut);
    await tester.pumpAndSettle();
    expect(find.text('Sign out?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(fixture.auth.status, AuthStatus.authenticated);
    fixture.expectNoWrites();
    await fixture.close(tester);
  });

  testWidgets('tab switching retains pickup filter and scroll', (tester) async {
    final fixture = _ShellFixture();
    await fixture.open(tester);
    await tester.tap(find.byType(NavigationDestination).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pickup orders'));
    await tester.pumpAndSettle();
    await fixture.pickup.selectFirstMileSchedule('schedule-1');
    await tester.pumpAndSettle();
    final scroll = tester
        .state<ScrollableState>(find.byType(Scrollable).last)
        .position;
    scroll.jumpTo(300);
    await tester.pump();
    await tester.tap(find.byType(NavigationDestination).at(3));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(NavigationDestination).at(1));
    await tester.pumpAndSettle();
    expect(scroll.pixels, 300);
    expect(fixture.pickup.firstMileScheduleId, 'schedule-1');
    fixture.expectNoWrites();
    await fixture.close(tester);
  });

  testWidgets('hidden roots suspend timers and resume visible reads', (
    tester,
  ) async {
    final fixture = _ShellFixture();
    await fixture.open(tester);
    final countBefore = fixture.alerts.countReads;
    await tester.tap(find.byType(NavigationDestination).at(1));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 31));
    expect(fixture.alerts.countReads, countBefore);
    await tester.tap(find.byType(NavigationDestination).at(2));
    await tester.pumpAndSettle();
    final inboxBefore = fixture.messages.reads;
    await tester.pump(const Duration(seconds: 31));
    expect(fixture.messages.reads, greaterThan(inboxBefore));
    await tester.tap(find.byType(NavigationDestination).at(3));
    await tester.pumpAndSettle();
    final hiddenReads = fixture.messages.reads;
    await tester.pump(const Duration(seconds: 31));
    expect(fixture.messages.reads, hiddenReads);
    await fixture.close(tester);
  });

  testWidgets('a shell mounted while paused waits for foreground polling', (
    tester,
  ) async {
    final fixture = _ShellFixture();
    await fixture.open(tester, lifecycle: AppLifecycleState.paused);
    expect(fixture.alerts.countReads, 0);
    await tester.pump(const Duration(seconds: 31));
    expect(fixture.alerts.countReads, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(fixture.alerts.countReads, greaterThan(0));
    fixture.expectNoWrites();
    await fixture.close(tester);
  });

  testWidgets(
    'session invalidation removes private routes and navigation state',
    (tester) async {
      final fixture = _ShellFixture();
      await fixture.open(tester);
      await tester.tap(find.byType(NavigationDestination).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pickup orders'));
      await tester.pumpAndSettle();
      await _openFirstTask(tester);
      await tester.pumpAndSettle();
      await fixture.auth.handlePickupAuthFailure(
        const ApiException(
          statusCode: 401,
          code: 'UNAUTHENTICATED',
          message: 'Unauthenticated',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sign in'), findsWidgets);
      expect(find.text('ORD-00', skipOffstage: false), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
      expect(fixture.pickup.firstMileTasks, isEmpty);
      final reads = fixture.alerts.countReads;
      await tester.pump(const Duration(seconds: 31));
      expect(fixture.alerts.countReads, reads);
      await fixture.close(tester);
    },
  );
}

Future<void> _openFirstTask(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('ORD-00'),
    200,
    scrollable: find
        .descendant(
          of: find.byKey(const PageStorageKey('pickup-work')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.ensureVisible(find.text('ORD-00'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('ORD-00'));
}

class _ShellFixture {
  final tasks = NavigationPickupRepository()
    ..page = FirstMileTaskPage(
      tasks: [
        for (var i = 0; i < 25; i++)
          PickupTask(
            id: 'task-$i',
            leg: PickupTaskLeg.firstMile,
            rawStatus: 'assigned',
            pickupScheduleId: 'schedule-1',
            schedule: const PickupSchedule(
              id: 'schedule-1',
              reference: 'Schedule 1',
            ),
            order: PickupOrderReference(
              reference: 'ORD-${i.toString().padLeft(2, '0')}',
            ),
          ),
      ],
    );
  final alerts = _Alerts();
  final messages = _Messages();
  final deliveryRepository = NavigationDeliveryRepository();
  late final delivery = DeliveryController(
    deliveryRepository: deliveryRepository,
  );
  late final pickup = PickupController(pickupRepository: tasks);
  late final notifications = NotificationController(
    notificationRepository: alerts,
  );
  late final chat = ChatController(repository: messages);
  late final auth =
      AuthController(
          authRepository: RegistrationTestRepository(),
          dashboardRepository: _Dashboard(),
          onSessionEnded: () {
            pickup.clear();
            notifications.clear();
            chat.clear();
          },
        )
        ..status = AuthStatus.authenticated
        ..courier = const CourierIdentity(
          id: 'courier',
          email: 'courier@example.com',
          role: 'courier',
          status: CourierAccountStatus.active,
          profile: CourierProfile(firstName: 'Maya', lastName: 'Santos'),
          logistics: LogisticsAffiliation(
            status: CourierAffiliationStatus.approved,
            organizationName: 'AISLEY Express',
            hubName: 'Makati Hub',
          ),
        );

  Future<void> open(
    WidgetTester tester, {
    AccessibilityScenario? scenario,
    AppLifecycleState lifecycle = AppLifecycleState.resumed,
  }) async {
    tester.binding.handleAppLifecycleStateChanged(lifecycle);
    final gate = AuthGate(
      authController: auth,
      pickupController: pickup,
      deliveryController: delivery,
      notificationController: notifications,
      chatController: chat,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCourierTheme(Brightness.light),
        darkTheme: buildCourierTheme(Brightness.dark),
        themeMode: scenario?.brightness == Brightness.dark
            ? ThemeMode.dark
            : ThemeMode.light,
        builder: (context, child) => CourierViewport(
          child: scenario == null ? child! : scenario.builder(context, child),
        ),
        navigatorObservers: [courierRouteObserver],
        home: gate,
      ),
    );
    await tester.pumpAndSettle();
  }

  void expectNoWrites() {
    expect(tasks.mutations, 0);
    expect(deliveryRepository.mutations, 0);
    expect(alerts.readWrites, 0);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    pickup.dispose();
    delivery.dispose();
    notifications.dispose();
    chat.dispose();
    auth.dispose();
  }
}

class _Alerts extends NavigationNotificationRepository {
  int countReads = 0;
  @override
  Future<int> fetchUnreadCount() {
    countReads++;
    return super.fetchUnreadCount();
  }
}

class _Messages implements ChatRepository {
  int reads = 0;
  @override
  Future<ChatPage<ChatThread>> list({
    String? leg,
    String? cursor,
    int limit = 20,
  }) async {
    reads++;
    return const ChatPage(items: [], nextCursor: null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Dashboard implements DashboardRepository {
  @override
  Future<DashboardSnapshot> fetchDashboard() async => const DashboardSnapshot(
    freshness: DashboardFreshness(state: DashboardFreshnessState.fresh),
    sections: {
      'active_tasks': DashboardSection(state: DashboardSectionState.empty),
      'available_tasks': DashboardSection(state: DashboardSectionState.empty),
      'notifications': DashboardSection(state: DashboardSectionState.empty),
    },
  );
}
