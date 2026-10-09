import 'dart:async';

import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aisley_app/features/notification/domain/notification_models.dart';
import 'package:aisley_app/features/notification/presentation/controllers/notification_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/navigation_fixture.dart';

void main() {
  testWidgets(
    'old notification target stays disabled until detail is revalidated',
    (tester) async {
      final fixture = NavigationFixture();
      await fixture.notifications.loadDetail('alert-1');
      final pending = Completer<CourierNotification>();
      fixture.notificationRepository.pendingDetail = pending;
      await fixture.openAlert(tester);
      expect(find.text('Open related work'), findsNothing);
      expect(fixture.pickupRepository.taskReads, isEmpty);
      pending.complete(workNotification(destination: null));
      await tester.pumpAndSettle();
      expect(find.text('Open related work'), findsNothing);
      expect(find.text('Mark as read'), findsOneWidget);
      fixture.expectNoMutations();
      await fixture.close(tester);
    },
  );

  for (final code in [401, 403]) {
    testWidgets(
      'target $code invokes existing session handling and closes protected routes',
      (tester) async {
        final fixture = NavigationFixture()..handleAuthFailures = true;
        fixture.pickupRepository.error = ApiException(
          statusCode: code,
          code: code == 401
              ? 'UNAUTHENTICATED'
              : 'LOGISTICS_ASSOCIATION_INVALID',
          message: '',
        );
        await fixture.openAlert(tester);
        await tester.tap(find.text('Open related work'));
        await tester.pumpAndSettle();
        expect(
          fixture.auth.status,
          code == 401 ? AuthStatus.signedOut : AuthStatus.invalidAffiliation,
        );
        expect(find.text('Notification details'), findsNothing);
        expect(find.textContaining('CURRENT-ORDER'), findsNothing);
        fixture.expectNoMutations();
        await fixture.close(tester);
      },
    );
  }

  for (final state in ['delivered', 'rejected', 'cancelled', 'future_state']) {
    testWidgets('current $state task remains read-only', (tester) async {
      final fixture = NavigationFixture();
      fixture.pickupRepository.task = currentOffer.copyWith(rawStatus: state);
      await fixture.openAlert(tester);
      await tester.tap(find.text('Open related work'));
      await tester.pumpAndSettle();
      expect(find.text('Dispatch batch offer'), findsNothing);
      expect(fixture.deliveryRepository.contextReads, isEmpty);
      expect(find.text('Retry'), findsOneWidget);
      fixture.expectNoMutations();
      await fixture.close(tester);
    });
  }

  for (final brightness in Brightness.values) {
    for (final schedule in [true, false]) {
      testWidgets(
        '${schedule ? 'schedule' : 'offer'} entry 320px 2x $brightness keeps current context accessible',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final fixture = NavigationFixture();
          if (schedule) {
            fixture.notificationRepository.notification = workNotification(
              resourceType: 'pickup_schedule',
              id: 'schedule-new',
              destination: '/pickup-schedules/schedule-new',
            );
          }
          await fixture.openAlert(tester, brightness: brightness, textScale: 2);
          await tester.ensureVisible(find.text('Open related work'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Open related work'));
          await tester.pumpAndSettle();
          final context = find.textContaining(
            schedule ? 'CURRENT-SCHEDULE' : 'Dispatch batch offer',
          );
          await tester.scrollUntilVisible(
            context,
            150,
            scrollable: find.byType(Scrollable).last,
          );
          expect(context, findsOneWidget);
          expect(tester.takeException(), isNull);
          fixture.expectNoMutations();
          await fixture.close(tester);
        },
      );
    }
  }

  testWidgets('policy boundary hides already displayed targeted task', (
    tester,
  ) async {
    final fixture = NavigationFixture();
    await fixture.openAlert(tester);
    await tester.tap(find.text('Open related work'));
    await tester.pumpAndSettle();
    expect(find.text('Dispatch batch offer'), findsOneWidget);
    await fixture.auth.handlePickupAuthFailure(
      const ApiException(
        statusCode: 403,
        code: 'POLICY_CONSENT_REQUIRED',
        message: '',
      ),
    );
    await tester.pumpAndSettle();
    expect(fixture.auth.status, AuthStatus.policyConsentRequired);
    expect(find.text('Dispatch batch offer'), findsNothing);
    expect(find.textContaining('CURRENT-ORDER'), findsNothing);
    expect(find.textContaining('Review the current policies'), findsOneWidget);
    fixture.expectNoMutations();
    await fixture.close(tester);
  });
}
