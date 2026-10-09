import 'dart:async';

import 'package:aisley_app/app/courier_theme.dart';
import 'package:aisley_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aisley_app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:aisley_app/features/delivery/data/delivery_repository.dart';
import 'package:aisley_app/features/delivery/domain/delivery_models.dart';
import 'package:aisley_app/features/delivery/presentation/controllers/delivery_controller.dart';
import 'package:aisley_app/features/notification/data/notification_repository.dart';
import 'package:aisley_app/features/notification/domain/notification_models.dart';
import 'package:aisley_app/features/notification/presentation/controllers/notification_controller.dart';
import 'package:aisley_app/features/pickup/data/pickup_repository.dart';
import 'package:aisley_app/features/pickup/domain/pickup_models.dart';
import 'package:aisley_app/features/pickup/presentation/controllers/pickup_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../delivery/fixtures/delivery_screen_fixture.dart';

CourierNotification workNotification({
  String resourceType = 'delivery_task',
  String? id = 'task-1',
  String? destination = '/delivery-tasks/task-1',
}) => CourierNotification(
  id: 'alert-1',
  type: resourceType == 'pickup_schedule'
      ? 'pickup-schedule.assigned'
      : 'courier-task.final-mile-offered',
  title: 'Work updated',
  summary: 'An earlier work event was recorded.',
  resourceType: resourceType,
  resourceId: id,
  destination: destination,
  createdAt: DateTime.utc(2026, 10, 9),
);

const currentOffer = PickupTask(
  id: 'task-1',
  leg: PickupTaskLeg.finalMile,
  rawStatus: 'delivery_assigned',
  revision: 2,
  order: PickupOrderReference(reference: 'CURRENT-ORDER'),
);

const currentPickup = PickupTask(
  id: 'first-1',
  leg: PickupTaskLeg.firstMile,
  rawStatus: 'assigned',
  pickupScheduleId: 'schedule-new',
  schedule: PickupSchedule(id: 'schedule-new', reference: 'CURRENT-SCHEDULE'),
  order: PickupOrderReference(reference: 'CURRENT-PICKUP'),
);

class NavigationPickupRepository implements PickupRepository {
  final scheduleQueries = <String?>[];
  final taskReads = <String>[];
  int listReads = 0;
  int mutations = 0;
  PickupTask task = currentOffer;
  FirstMileTaskPage page = const FirstMileTaskPage(tasks: [currentPickup]);
  Object? error;
  Completer<PickupTask>? pendingTask;
  Completer<FirstMileTaskPage>? pendingPage;

  @override
  Future<FirstMileTaskPage> fetchFirstMileTasks({
    String? pickupScheduleId,
    int perPage = 50,
  }) async {
    scheduleQueries.add(pickupScheduleId);
    if (error case final failure?) throw failure;
    return pendingPage?.future ?? page;
  }

  @override
  Future<PickupTask> fetchFinalMileTask(String taskId) async {
    taskReads.add(taskId);
    if (error case final failure?) throw failure;
    return pendingTask?.future ?? task;
  }

  @override
  Future<List<PickupTask>> fetchFinalMileTasks() async {
    listReads++;
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    mutations++;
    throw StateError('Unexpected mutation: ${invocation.memberName}');
  }
}

class NavigationDeliveryRepository implements DeliveryRepository {
  final contextReads = <String>[];
  int mutations = 0;
  Object? error;
  Completer<DeliveryContext>? pendingContext;

  @override
  Future<DeliveryContext> fetchDeliveryContext(String taskId) async {
    contextReads.add(taskId);
    if (error case final failure?) throw failure;
    return pendingContext?.future ??
        DeliveryContext(
          taskId: taskId,
          status: 'in_transit',
          revision: 3,
          hub: const PickupLocation(name: 'Current hub'),
          destination: const PickupLocation(cityMunicipality: 'Current area'),
        );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    mutations++;
    throw StateError('Unexpected call: ${invocation.memberName}');
  }
}

class NavigationNotificationRepository implements NotificationRepository {
  CourierNotification notification = workNotification();
  int readWrites = 0;
  Completer<CourierNotification>? pendingDetail;

  @override
  Future<CourierNotificationPage> fetchNotifications({
    NotificationFilter filter = NotificationFilter.all,
    int limit = 20,
    String? cursor,
  }) async => CourierNotificationPage(items: [notification]);

  @override
  Future<int> fetchUnreadCount() async => notification.isRead ? 0 : 1;

  @override
  Future<CourierNotification> fetchDetail(String notificationId) async =>
      pendingDetail?.future ?? notification;

  @override
  Future<CourierNotification> markRead(String notificationId) async {
    readWrites++;
    return notification = notification.copyWith(
      readAt: DateTime.utc(2026, 10, 9),
    );
  }
}

class NavigationFixture {
  bool handleAuthFailures = false;
  final AuthController auth = deliveryAuthController();
  final pickupRepository = NavigationPickupRepository();
  final deliveryRepository = NavigationDeliveryRepository();
  final notificationRepository = NavigationNotificationRepository();
  late final pickup = PickupController(
    pickupRepository: pickupRepository,
    onAuthFailure: handleAuthFailures ? auth.handlePickupAuthFailure : null,
  );
  late final delivery = DeliveryController(
    deliveryRepository: deliveryRepository,
    onAuthFailure: handleAuthFailures ? auth.handleDeliveryAuthFailure : null,
  );
  late final notifications = NotificationController(
    notificationRepository: notificationRepository,
  );

  Future<void> openAlert(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCourierTheme(brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: DashboardScreen(
          authController: auth,
          pickupController: pickup,
          deliveryController: delivery,
          notificationController: notifications,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Work updated'),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(find.text('Work updated'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Work updated'));
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    notifications.dispose();
    pickup.dispose();
    delivery.dispose();
    auth.dispose();
  }

  void expectNoMutations() {
    expect(pickupRepository.mutations, 0);
    expect(deliveryRepository.mutations, 0);
    expect(notificationRepository.readWrites, 0);
  }
}
