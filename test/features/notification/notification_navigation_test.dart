import 'dart:async';

import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aisley_app/features/delivery/domain/delivery_models.dart';
import 'package:aisley_app/features/delivery/presentation/final_mile_task_entry_screen.dart';
import 'package:aisley_app/features/pickup/domain/pickup_models.dart';
import 'package:aisley_app/features/pickup/presentation/pickup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/navigation_fixture.dart';

void main() {
  testWidgets(
    'alert opens a specific current offer and Back preserves unread history',
    (tester) async {
      final fixture = NavigationFixture();
      await fixture.openAlert(tester);
      await tester.tap(find.text('Open related work'));
      await tester.pumpAndSettle();
      expect(find.text('Dispatch batch offer'), findsOneWidget);
      expect(find.textContaining('CURRENT-ORDER'), findsWidgets);
      expect(fixture.pickupRepository.taskReads, ['task-1']);
      expect(fixture.pickupRepository.listReads, 0);
      expect(fixture.deliveryRepository.contextReads, isEmpty);
      fixture.expectNoMutations();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Notification details'), findsOneWidget);
      expect(find.text('Mark as read'), findsOneWidget);
      expect(fixture.notifications.detailFor('alert-1')?.isRead, isFalse);
      await tester.tap(find.text('Mark as read'));
      await tester.pumpAndSettle();
      expect(fixture.notificationRepository.readWrites, 1);
      expect(find.text('Already read'), findsOneWidget);
      await fixture.close(tester);
    },
  );

  testWidgets(
    'schedule target fetch is isolated and cancellation hides old task actions',
    (tester) async {
      final fixture = NavigationFixture();
      fixture.notificationRepository.notification = workNotification(
        resourceType: 'pickup_schedule',
        id: 'schedule-new',
        destination: '/pickup-schedules/schedule-new',
      );
      await fixture.openAlert(tester);
      await tester.tap(find.text('Open related work'));
      await tester.pumpAndSettle();
      expect(find.textContaining('CURRENT-SCHEDULE'), findsOneWidget);
      expect(find.text('Hub pickups'), findsNothing);
      expect(fixture.pickupRepository.scheduleQueries, ['schedule-new']);
      expect(fixture.pickup.firstMileScheduleId, isNull);
      await tester.tap(find.text('CURRENT-PICKUP'));
      await tester.pumpAndSettle();
      expect(find.text('Accept Seller pickup'), findsOneWidget);
      fixture.pickupRepository.page = const FirstMileTaskPage(tasks: []);
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator).last)
          .onRefresh();
      await tester.pumpAndSettle();
      expect(find.text('Accept Seller pickup'), findsNothing);
      expect(find.textContaining('no longer available'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.textContaining('No current pickup work'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Notification details'), findsOneWidget);
      expect(fixture.pickupRepository.listReads, 0);
      fixture.expectNoMutations();
      await fixture.close(tester);
    },
  );

  testWidgets('target refresh observes accepted and then reassigned state', (
    tester,
  ) async {
    final fixture = NavigationFixture();
    fixture.pickupRepository.task = currentOffer.copyWith(
      rawStatus: 'delivery_accepted',
    );
    await fixture.openAlert(tester);
    await tester.tap(find.text('Open related work'));
    await tester.pumpAndSettle();
    expect(find.text('Dispatch batch offer'), findsNothing);
    expect(find.textContaining('hub'), findsWidgets);
    fixture.pickupRepository.error = const ApiException(
      statusCode: 404,
      code: 'NOT_FOUND',
      message: '',
    );
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator).last)
        .onRefresh();
    await tester.pumpAndSettle();
    expect(find.byType(PickupTaskDetailScreen), findsNothing);
    expect(find.textContaining('no longer available'), findsOneWidget);
    expect(find.textContaining('CURRENT-ORDER'), findsNothing);
    fixture.expectNoMutations();
    await fixture.close(tester);
  });

  testWidgets(
    'current transit state enters delivery with an exact context read',
    (tester) async {
      final fixture = NavigationFixture();
      fixture.pickupRepository.task = currentOffer.copyWith(
        rawStatus: 'in_transit',
      );
      await fixture.openAlert(tester);
      await tester.tap(find.text('Open related work'));
      await tester.pumpAndSettle();
      expect(find.text('Deliver order'), findsOneWidget);
      expect(find.textContaining('Current hub'), findsWidgets);
      expect(fixture.deliveryRepository.contextReads, ['task-1']);
      fixture.expectNoMutations();
      await fixture.close(tester);
    },
  );

  for (final code in [401, 403, 404]) {
    testWidgets('target $code displays access failure without work actions', (
      tester,
    ) async {
      final fixture = NavigationFixture();
      fixture.pickupRepository.error = ApiException(
        statusCode: code,
        code: 'DENIED',
        message: '',
      );
      await fixture.openAlert(tester);
      await tester.tap(find.text('Open related work'));
      await tester.pumpAndSettle();
      expect(find.byType(PickupTaskDetailScreen), findsNothing);
      expect(find.text('Dispatch batch offer'), findsNothing);
      expect(find.textContaining('CURRENT-ORDER'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Notification details'), findsOneWidget);
      fixture.expectNoMutations();
      await fixture.close(tester);
    });
  }

  for (final notification in [
    workNotification(id: null),
    workNotification(destination: null),
    workNotification(destination: '/delivery-tasks/foreign'),
    workNotification(destination: 'https://example.com/'),
    workNotification(
      resourceType: 'linehaul_trip',
      destination: '/linehaul-trips/task-1',
    ),
  ]) {
    testWidgets(
      'unsupported target ${notification.resourceType} ${notification.destination} remains readable',
      (tester) async {
        final fixture = NavigationFixture();
        fixture.notificationRepository.notification = notification;
        await fixture.openAlert(tester);
        expect(find.text('Open related work'), findsNothing);
        expect(find.textContaining('not currently available'), findsOneWidget);
        expect(find.text('Mark as read'), findsOneWidget);
        expect(fixture.pickupRepository.taskReads, isEmpty);
        expect(fixture.pickupRepository.scheduleQueries, isEmpty);
        fixture.expectNoMutations();
        await fixture.close(tester);
      },
    );
  }

  testWidgets(
    'double open and Back during fetch cannot create late navigation',
    (tester) async {
      final fixture = NavigationFixture();
      final pending = Completer<PickupTask>();
      fixture.pickupRepository.pendingTask = pending;
      await fixture.openAlert(tester);
      final open = tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Open related work'),
          )
          .onPressed!;
      open();
      open();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(fixture.pickupRepository.taskReads, ['task-1']);
      Navigator.of(tester.element(find.byType(FinalMileTaskEntryScreen))).pop();
      await tester.pumpAndSettle();
      pending.complete(currentOffer);
      await tester.pumpAndSettle();
      expect(find.text('Notification details'), findsOneWidget);
      expect(find.text('Dispatch batch offer'), findsNothing);
      fixture.expectNoMutations();
      await fixture.close(tester);
    },
  );

  testWidgets('logout during target read discards late private work', (
    tester,
  ) async {
    final fixture = NavigationFixture();
    final pending = Completer<PickupTask>();
    fixture.pickupRepository.pendingTask = pending;
    await fixture.openAlert(tester);
    await tester.tap(find.text('Open related work'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await fixture.auth.handlePickupAuthFailure(
      const ApiException(statusCode: 401, code: 'UNAUTHENTICATED', message: ''),
    );
    await tester.pumpAndSettle();
    expect(fixture.auth.status, AuthStatus.signedOut);
    pending.complete(currentOffer);
    await tester.pumpAndSettle();
    expect(find.text('Dispatch batch offer'), findsNothing);
    expect(find.textContaining('CURRENT-ORDER'), findsNothing);
    fixture.expectNoMutations();
    await fixture.close(tester);
  });

  testWidgets('Back during delivery context fetch discards late response', (
    tester,
  ) async {
    final fixture = NavigationFixture();
    fixture.pickupRepository.task = currentOffer.copyWith(
      rawStatus: 'in_transit',
    );
    final pending = Completer<DeliveryContext>();
    fixture.deliveryRepository.pendingContext = pending;
    await fixture.openAlert(tester);
    await tester.tap(find.text('Open related work'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    Navigator.of(tester.element(find.byType(FinalMileTaskEntryScreen))).pop();
    await tester.pumpAndSettle();
    pending.complete(
      const DeliveryContext(
        taskId: 'task-1',
        status: 'in_transit',
        revision: 3,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Notification details'), findsOneWidget);
    expect(tester.takeException(), isNull);
    fixture.expectNoMutations();
    await fixture.close(tester);
  });

  for (final brightness in Brightness.values) {
    testWidgets('safe unavailable layout at 320px, 2x text, $brightness', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      final fixture = NavigationFixture();
      fixture.notificationRepository.notification = workNotification(
        destination: null,
      );
      await fixture.openAlert(tester, brightness: brightness, textScale: 2);
      expect(find.textContaining('not currently available'), findsOneWidget);
      await tester.ensureVisible(find.text('Mark as read'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      semantics.dispose();
      await fixture.close(tester);
    });
  }
}
