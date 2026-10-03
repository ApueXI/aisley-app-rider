import 'package:aisley_app/core/networking/api_contract_exception.dart';
import 'package:aisley_app/features/batch/data/final_mile_batch_repository.dart';
import 'package:aisley_app/features/batch/presentation/controllers/final_mile_batch_controller.dart';
import 'package:aisley_app/features/chat/data/chat_repository.dart';
import 'package:aisley_app/features/chat/presentation/controllers/chat_controller.dart';
import 'package:aisley_app/features/dashboard/presentation/controllers/dashboard_preview_controller.dart';
import 'package:aisley_app/features/notification/data/notification_repository.dart';
import 'package:aisley_app/features/notification/presentation/controllers/notification_controller.dart';
import 'package:aisley_app/features/pickup/data/pickup_repository.dart';
import 'package:aisley_app/features/support/data/support_ticket_repository.dart';
import 'package:aisley_app/features/support/presentation/controllers/support_ticket_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'notification response failure suggests refresh without technical fields',
    () async {
      final controller = NotificationController(
        notificationRepository: _NotificationFailure(),
      );
      addTearDown(controller.dispose);
      await controller.refresh();
      expect(controller.listStatus, NotificationLoadStatus.failed);
      expect(controller.unreadCount, isNull);
      _expectRecovery(controller.listErrorMessage, 'Refresh Notifications');
      _expectRecovery(controller.countErrorMessage, 'Refresh Notifications');
    },
  );

  test('chat response failure suggests refreshing task messages', () async {
    final controller = ChatController(repository: _ChatFailure());
    addTearDown(controller.dispose);
    await controller.loadInbox();
    expect(controller.inboxStatus, ChatLoadStatus.failed);
    _expectRecovery(controller.inboxError, 'Refresh the list');
  });

  test(
    'support response failure suggests checking the latest ticket status',
    () async {
      final controller = SupportTicketController(repository: _SupportFailure());
      addTearDown(controller.dispose);
      await controller.refreshList();
      expect(controller.listStatus, SupportTicketLoadStatus.failed);
      _expectRecovery(controller.listError, 'Refresh your tickets');
    },
  );

  test('batch detail failure suggests refreshing the batch', () async {
    final controller = FinalMileBatchController(repository: _BatchFailure());
    addTearDown(controller.dispose);
    await controller.loadDetail('batch-1');
    expect(controller.detailStatus('batch-1'), FinalMileBatchLoadStatus.failed);
    _expectRecovery(controller.detailError('batch-1'), 'Refresh the batch');
  });

  test(
    'preview response failure stays failed and gives recovery guidance',
    () async {
      final controller = DashboardPreviewController(
        repository: _PreviewFailure(),
      );
      addTearDown(controller.dispose);
      await controller.refreshAll();
      expect(controller.firstMile.status, DashboardPreviewStatus.failed);
      expect(controller.finalMile.status, DashboardPreviewStatus.failed);
      _expectRecovery(controller.firstMile.error, 'Please retry');
      _expectRecovery(controller.finalMile.error, 'Please retry');
    },
  );
}

void _expectRecovery(String? message, String action) {
  expect(message, contains(action));
  expect(message, isNot(contains('API')));
  expect(message, isNot(contains('contract')));
  expect(message, isNot(contains('private_internal_field')));
}

class _NotificationFailure extends _FailureRepository
    implements NotificationRepository {}

class _ChatFailure extends _FailureRepository implements ChatRepository {}

class _SupportFailure extends _FailureRepository
    implements SupportTicketRepository {}

class _BatchFailure extends _FailureRepository
    implements FinalMileBatchRepository {}

class _PreviewFailure extends _FailureRepository implements PickupRepository {}

class _FailureRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Future<Never>.error(const ApiContractException('private_internal_field'));
}
