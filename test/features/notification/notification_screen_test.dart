import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/features/notification/data/notification_repository.dart';
import 'package:aisley_app/features/notification/domain/notification_models.dart';
import 'package:aisley_app/features/notification/presentation/controllers/notification_controller.dart';
import 'package:aisley_app/features/notification/presentation/notification_screen.dart';

void main() {
  testWidgets('starts only one initial refresh when it owns polling', (
    tester,
  ) async {
    final repository = _FakeNotificationRepository();
    final controller = NotificationController(
      notificationRepository: repository,
    );

    await tester.pumpWidget(
      MaterialApp(home: NotificationScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(repository.listCalls, 1);
    expect(repository.unreadCountCalls, 1);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('shows unread notifications and explicit mark-read action', (
    tester,
  ) async {
    final controller = NotificationController(
      notificationRepository: _FakeNotificationRepository(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NotificationScreen(
          controller: controller,
          managePolling: false,
          onOpenTarget: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Courier inbox'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNWidgets(3));
    expect(
      find.byKey(const ValueKey('notification-category-support')),
      findsOneWidget,
    );
    expect(find.text('Delivery offered'), findsOneWidget);
    expect(find.text('Deliveries'), findsNWidgets(2));
    expect(find.text('1 unread notification'), findsOneWidget);
    expect(find.text('Mark all as read'), findsNothing);

    await tester.tap(find.text('Delivery offered'));
    await tester.pumpAndSettle();

    expect(find.text('Notification details'), findsOneWidget);
    expect(find.text('Mark as read'), findsOneWidget);
    expect(find.text('Open related work'), findsOneWidget);
    await tester.tap(find.text('Mark as read'));
    await tester.pumpAndSettle();

    expect(find.text('Already read'), findsOneWidget);
    expect(controller.notificationById('notification-1')?.isRead, isTrue);
  });

  testWidgets('keeps redacted ticket alerts readable and non-navigable', (
    tester,
  ) async {
    final notification = CourierNotification.fromJson({
      'id': 'notification-redacted',
      'type': 'support-ticket.admin-replied',
      'title': 'Support reply received',
      'summary': 'SUP-1234 has a new reply.',
      'read_at': null,
      'created_at': '2026-10-29T02:00:00Z',
      'resource_type': null,
      'resource_id': null,
      'destination': null,
    });
    final repository = _FakeNotificationRepository()
      ..notification = notification;
    final controller = NotificationController(
      notificationRepository: repository,
    );
    var openedTarget = false;

    await tester.pumpWidget(
      MaterialApp(
        home: NotificationScreen(
          controller: controller,
          managePolling: false,
          onOpenTarget: (_) async => openedTarget = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Support reply received'), findsOneWidget);
    expect(find.text('SUP-1234 has a new reply.'), findsOneWidget);
    await tester.tap(find.text('Support reply received'));
    await tester.pumpAndSettle();

    expect(find.text('Notification details'), findsOneWidget);
    expect(
      find.text('The related work is not currently available to this Courier.'),
      findsOneWidget,
    );
    expect(find.text('Open related work'), findsNothing);
    await tester.tap(find.text('Mark as read'));
    await tester.pumpAndSettle();

    expect(find.text('Already read'), findsOneWidget);
    expect(
      controller.notificationById('notification-redacted')?.isRead,
      isTrue,
    );
    expect(openedTarget, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'shows stale data instead of converting a failed refresh to empty',
    (tester) async {
      final repository = _FakeNotificationRepository();
      final controller = NotificationController(
        notificationRepository: repository,
      );
      await controller.refresh();
      repository.failList = true;

      await tester.pumpWidget(
        MaterialApp(
          home: NotificationScreen(
            controller: controller,
            managePolling: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Delivery offered'), findsOneWidget);
      expect(
        find.textContaining('Showing stale notifications.'),
        findsOneWidget,
      );
      expect(find.text('No notifications yet'), findsNothing);
    },
  );

  testWidgets('distinguishes a successful empty inbox from an error', (
    tester,
  ) async {
    final repository = _FakeNotificationRepository()..empty = true;
    final controller = NotificationController(
      notificationRepository: repository,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NotificationScreen(controller: controller, managePolling: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No notifications yet'), findsOneWidget);
    expect(find.text('Notifications are unavailable.'), findsNothing);
  });

  testWidgets('shows forbidden notification access without an empty state', (
    tester,
  ) async {
    final repository = _FakeNotificationRepository()
      ..listError = const ApiException(
        statusCode: 403,
        code: 'FORBIDDEN',
        message: 'forbidden',
      );
    final controller = NotificationController(
      notificationRepository: repository,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NotificationScreen(controller: controller, managePolling: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Your Courier account is not currently allowed to view notifications.',
      ),
      findsOneWidget,
    );
    expect(find.text('No notifications yet'), findsNothing);
  });

  testWidgets('category filter is responsive and independent of read status', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeNotificationRepository();
    final controller = NotificationController(
      notificationRepository: repository,
    );
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: NotificationScreen(controller: controller, managePolling: false),
      ),
    );
    await tester.pumpAndSettle();
    final support = find.byKey(const ValueKey('notification-category-support'));
    await tester.drag(find.byType(ListView).first, const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(support);
    await tester.pumpAndSettle();

    expect(controller.category, 'support');
    expect(controller.filter, NotificationFilter.all);
    expect(repository.queries.last, (NotificationFilter.all, 'support', null));
    expect(controller.unreadCount, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _FakeNotificationRepository implements NotificationRepository {
  bool failList = false;
  bool empty = false;
  ApiException? listError;
  int listCalls = 0;
  int unreadCountCalls = 0;
  final queries = <(NotificationFilter, String, String?)>[];
  late CourierNotification notification = _notification;

  @override
  Future<CourierNotificationPage> fetchNotifications({
    NotificationFilter filter = NotificationFilter.all,
    String category = 'all',
    int limit = 20,
    String? cursor,
  }) async {
    listCalls++;
    queries.add((filter, category, cursor));
    if (listError != null) {
      throw listError!;
    }
    if (failList) {
      throw const ApiException.network('offline');
    }
    if (empty) {
      return const CourierNotificationPage(items: <CourierNotification>[]);
    }
    return CourierNotificationPage(
      items: <CourierNotification>[notification],
      generatedAt: null,
    );
  }

  @override
  Future<int> fetchUnreadCount() async {
    unreadCountCalls++;
    return 1;
  }

  @override
  Future<CourierNotification> fetchDetail(String notificationId) async =>
      notification;

  @override
  Future<CourierNotification> markRead(String notificationId) async {
    notification = notification.copyWith(
      readAt: DateTime.utc(2026, 9, 20, 2, 1),
    );
    return notification;
  }
}

final _notification = CourierNotification(
  id: 'notification-1',
  type: 'courier-task.final-mile-offered',
  title: 'Delivery offered',
  summary: 'A delivery request is available.',
  createdAt: DateTime.utc(2026, 9, 20, 2),
  resourceType: 'delivery_task',
  resourceId: 'task-1',
  destination: '/delivery-tasks/task-1',
  category: 'deliveries',
  categoryLabel: 'Deliveries',
);
