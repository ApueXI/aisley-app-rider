import 'dart:async';

import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/core/networking/api_contract_exception.dart';
import 'package:aisley_app/core/security/token_storage.dart';
import 'package:aisley_app/features/delivery/presentation/controllers/delivery_controller.dart';
import 'package:aisley_app/features/notification/domain/notification_target.dart';
import 'package:aisley_app/features/notification/domain/notification_models.dart';
import 'package:aisley_app/features/pickup/domain/pickup_models.dart';
import 'package:aisley_app/features/pickup/presentation/controllers/pickup_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/navigation_fixture.dart';

void main() {
  test('a failed delivery context does not start a completion read', () async {
    for (final code in [401, 403, 404]) {
      final repository = NavigationDeliveryRepository()
        ..error = ApiException(statusCode: code, code: 'DENIED', message: '');
      final controller = DeliveryController(deliveryRepository: repository);
      await controller.loadDetails(
        currentOffer.copyWith(rawStatus: 'out_for_delivery'),
      );
      expect(repository.contextReads, ['task-1']);
      expect(repository.mutations, 0); // Unexpected reads or writes also fail.
      expect(controller.completions, isEmpty);
      controller.dispose();
    }
  });
  test('resolves supported matching targets only', () {
    expect(
      NotificationTarget.resolve(workNotification())?.resourceId,
      'task-1',
    );
    expect(
      NotificationTarget.resolve(
        workNotification(resourceType: 'final_mile_task'),
      )?.kind,
      NotificationTargetKind.finalMileTask,
    );
    expect(
      NotificationTarget.resolve(
        workNotification(
          resourceType: 'pickup_schedule',
          id: 'schedule-new',
          destination: '/pickup-schedules/schedule-new',
        ),
      )?.kind,
      NotificationTargetKind.pickupSchedule,
    );
    for (final notification in [
      workNotification(id: null),
      workNotification(id: ''),
      workNotification(destination: null),
      workNotification(destination: ''),
      workNotification(
        destination: 'https://example.com/delivery-tasks/task-1',
      ),
      workNotification(destination: '//example.com/delivery-tasks/task-1'),
      workNotification(destination: '/delivery-tasks/foreign-task'),
      workNotification(destination: '/delivery-tasks/task-1?other=1'),
      workNotification(destination: '/delivery-tasks/task-1#details'),
      workNotification(
        id: '../task-1',
        destination: '/delivery-tasks/../task-1',
      ),
      workNotification(id: 'a/b', destination: '/delivery-tasks/a/b'),
      workNotification(
        resourceType: 'linehaul_trip',
        destination: '/linehaul-trips/task-1',
      ),
      workNotification(resourceType: 'unknown'),
    ]) {
      expect(NotificationTarget.resolve(notification), isNull);
    }
  });

  test('redacted ticket alert stays readable without a work target', () {
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

    expect(notification.title, 'Support reply received');
    expect(notification.summary, 'SUP-1234 has a new reply.');
    expect(NotificationTarget.resolve(notification), isNull);
  });

  test('resolves safe support ticket notifications only', () {
    const ticketId = '11111111-1111-4111-8111-111111111111';
    final notification = CourierNotification(
      id: 'alert-ticket',
      type: 'support-ticket.admin-replied',
      title: 'Admin replied to your support ticket',
      summary: 'SUP-1001 has a new reply.',
      resourceType: 'support_ticket',
      resourceId: ticketId,
      destination: '/support-tickets/$ticketId',
      createdAt: DateTime.utc(2026, 10, 29),
      category: 'support',
      categoryLabel: 'Support',
    );
    final target = NotificationTarget.resolve(notification);
    expect(target?.kind, NotificationTargetKind.supportTicket);
    expect(target?.resourceId, ticketId);

    for (final invalid in [
      CourierNotification(
        id: notification.id,
        type: 'unknown',
        title: notification.title,
        summary: notification.summary,
        resourceType: notification.resourceType,
        resourceId: ticketId,
        destination: '/support-tickets/$ticketId',
        createdAt: notification.createdAt,
      ),
      CourierNotification(
        id: notification.id,
        type: notification.type,
        title: notification.title,
        summary: notification.summary,
        resourceType: notification.resourceType,
        resourceId: 'not-a-uuid',
        destination: '/support-tickets/not-a-uuid',
        createdAt: notification.createdAt,
      ),
      CourierNotification(
        id: notification.id,
        type: notification.type,
        title: notification.title,
        summary: notification.summary,
        resourceType: notification.resourceType,
        resourceId: ticketId,
        destination: 'https://example.invalid/support-tickets/$ticketId',
        createdAt: notification.createdAt,
      ),
    ]) {
      expect(NotificationTarget.resolve(invalid), isNull);
    }
  });

  test('schedule entry outside options fetches only its tasks and keeps normal selection isolated', () async {
    final repository = NavigationPickupRepository();
    final ordinary = PickupController(pickupRepository: repository);
    final scoped = PickupController(
      pickupRepository: repository,
      targetScheduleId: 'schedule-new',
    );
    addTearDown(ordinary.dispose);
    addTearDown(scoped.dispose);
    await scoped.load();
    await scoped.selectFirstMileSchedule(null);
    await scoped.load();
    expect(repository.scheduleQueries, ['schedule-new', 'schedule-new']);
    expect(repository.listReads, 0);
    expect(scoped.firstMileTasks.single.id, 'first-1');
    expect(ordinary.firstMileScheduleId, isNull);
    expect(ordinary.firstMileTasks, isEmpty);
    repository.page = const FirstMileTaskPage(tasks: []);
    await scoped.load();
    expect(scoped.firstMileStatus, PickupSectionStatus.empty);
    expect(scoped.firstMileTasks, isEmpty);
    expect(repository.mutations, 0);
  });

  test('target detail fetch includes offers without a list read', () async {
    final repository = NavigationPickupRepository();
    final scoped = PickupController(
      pickupRepository: repository,
      targetFinalMileTaskId: 'task-1',
    );
    addTearDown(scoped.dispose);
    await scoped.load();
    expect(
      scoped.finalMileTasks.single.status,
      PickupTaskStatus.deliveryAssigned,
    );
    repository.task = currentOffer.copyWith(rawStatus: 'delivery_accepted');
    await scoped.load();
    expect(
      scoped.finalMileTasks.single.status,
      PickupTaskStatus.deliveryAccepted,
    );
    expect(repository.taskReads, ['task-1', 'task-1']);
    expect(repository.scheduleQueries, isEmpty);
    expect(repository.listReads, 0);
    expect(repository.mutations, 0);
  });

  final failures = <Object, PickupSectionStatus>{
    const ApiException(statusCode: 401, code: 'UNAUTHENTICATED', message: ''):
        PickupSectionStatus.unauthorized,
    const ApiException(statusCode: 403, code: 'FORBIDDEN', message: ''):
        PickupSectionStatus.forbidden,
    const ApiException(
      statusCode: 403,
      code: 'POLICY_CONSENT_REQUIRED',
      message: '',
    ): PickupSectionStatus.consentRequired,
    const ApiException(statusCode: 404, code: 'NOT_FOUND', message: ''):
        PickupSectionStatus.failed,
    const ApiException(statusCode: 409, code: 'CONFLICT', message: ''):
        PickupSectionStatus.failed,
    const ApiException(statusCode: 422, code: 'VALIDATION', message: ''):
        PickupSectionStatus.failed,
    const ApiException(statusCode: 500, code: 'SERVER_ERROR', message: ''):
        PickupSectionStatus.failed,
    const ApiException.network('offline'): PickupSectionStatus.offline,
    const ApiException.network(
      'timeout',
      networkFailure: ApiNetworkFailure.timeout,
    ): PickupSectionStatus.timeout,
    const ApiContractException('invalid'): PickupSectionStatus.failed,
    TokenStorageException('read', StateError('storage')):
        PickupSectionStatus.secureStorageFailure,
  };
  for (final isSchedule in [true, false]) {
    for (final failure in failures.entries) {
      test(
        '${isSchedule ? 'schedule' : 'task'} ${failure.value} clears old work and retries same target',
        () async {
          final repository = NavigationPickupRepository();
          final authErrors = <ApiException>[];
          final scoped = PickupController(
            pickupRepository: repository,
            targetScheduleId: isSchedule ? 'schedule-new' : null,
            targetFinalMileTaskId: isSchedule ? null : 'task-1',
            onAuthFailure: (error) async => authErrors.add(error),
          );
          addTearDown(scoped.dispose);
          await scoped.load();
          repository.error = failure.key;
          await scoped.load();
          expect(
            isSchedule ? scoped.firstMileStatus : scoped.finalMileStatus,
            failure.value,
          );
          expect(
            isSchedule ? scoped.firstMileTasks : scoped.finalMileTasks,
            isEmpty,
          );
          final code = failure.key is ApiException
              ? (failure.key as ApiException).statusCode
              : null;
          expect(
            authErrors.length,
            code == 401 ||
                    (code == 403 &&
                        failure.value != PickupSectionStatus.consentRequired)
                ? 1
                : 0,
          );
          repository.error = null;
          await scoped.load();
          expect(
            isSchedule ? scoped.firstMileStatus : scoped.finalMileStatus,
            PickupSectionStatus.loaded,
          );
          expect(
            isSchedule ? repository.scheduleQueries : repository.taskReads,
            List.filled(3, isSchedule ? 'schedule-new' : 'task-1'),
          );
          expect(repository.mutations, 0);
        },
      );
    }
  }

  test('throttled target retry observes Retry-After', () async {
    final repository = NavigationPickupRepository()
      ..error = const ApiException(
        statusCode: 429,
        code: 'THROTTLED',
        message: '',
        retryAfter: Duration(milliseconds: 10),
      );
    final scoped = PickupController(
      pickupRepository: repository,
      targetFinalMileTaskId: 'task-1',
    );
    addTearDown(scoped.dispose);
    await scoped.load();
    await scoped.load();
    expect(repository.taskReads, ['task-1']);
    expect(scoped.canRetryRateLimit, isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    repository.error = null;
    await scoped.load();
    expect(scoped.finalMileStatus, PickupSectionStatus.loaded);
  });

  test('foreign task identity or first-mile leg fails closed', () async {
    for (final wrongTask in [
      currentPickup,
      const PickupTask(
        id: 'foreign',
        leg: PickupTaskLeg.finalMile,
        rawStatus: 'delivery_assigned',
      ),
    ]) {
      final repository = NavigationPickupRepository()..task = wrongTask;
      final scoped = PickupController(
        pickupRepository: repository,
        targetFinalMileTaskId: 'task-1',
      );
      await scoped.load();
      expect(scoped.finalMileStatus, PickupSectionStatus.failed);
      expect(scoped.finalMileTasks, isEmpty);
      scoped.dispose();
    }
  });

  test('obsolete target reads cannot restore work after refresh, clear, or dispose', () async {
    for (final end in ['refresh', 'clear', 'dispose']) {
      final pending = Completer<PickupTask>();
      final repository = NavigationPickupRepository()..pendingTask = pending;
      final scoped = PickupController(
        pickupRepository: repository,
        targetFinalMileTaskId: 'task-1',
      );
      final loading = scoped.load();
      repository.pendingTask = null;
      if (end == 'refresh') {
        repository.task = currentOffer.copyWith(rawStatus: 'delivery_accepted');
        await scoped.load();
      } else if (end == 'clear') {
        scoped.clear();
      } else {
        scoped.dispose();
      }
      pending.complete(currentOffer);
      await loading;
      expect(
        scoped.finalMileTasks,
        end == 'refresh' ? [repository.task] : isEmpty,
      );
      if (end != 'dispose') scoped.dispose();
    }
  });
}
