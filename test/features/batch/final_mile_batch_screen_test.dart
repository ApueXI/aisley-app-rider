import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aisley_app/features/batch/presentation/controllers/final_mile_batch_controller.dart';
import 'package:aisley_app/features/batch/presentation/final_mile_batch_screen.dart';
import 'package:aisley_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aisley_app/features/chat/data/chat_repository.dart';
import 'package:aisley_app/features/chat/domain/chat_models.dart';
import 'package:aisley_app/features/chat/presentation/controllers/chat_controller.dart';

import 'fixtures/final_mile_batch_screen_fixture.dart';

void main() {
  testWidgets('reviews and accepts only the chosen parcel', (tester) async {
    final repository = WidgetBatchRepository();
    final parcels = WidgetParcelRepository(repository);
    final controller = FinalMileBatchController(
      repository: repository,
      parcelRepository: parcels,
    );
    await controller.load();
    final auth = batchAuthController();

    await tester.pumpWidget(
      MaterialApp(
        home: FinalMileBatchDetailScreen(
          authController: auth,
          batchController: controller,
          scheduleId: 'schedule-1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('DSP-100'), findsOneWidget);
    expect(find.text('3 parcels assigned'), findsOneWidget);
    expect(find.text('0 accepted · 3 offered'), findsOneWidget);
    expect(find.text('Review parcel'), findsNWidgets(2));
    expect(find.text('Accept parcel'), findsNothing);
    expect(find.text('Reject parcel'), findsNothing);
    expect(find.text('Accept hub delivery'), findsNothing);

    await tester.ensureVisible(find.text('Review parcel').first);
    await tester.tap(find.text('Review parcel').first);
    await tester.pumpAndSettle();
    expect(find.byType(FinalMileOfferedTaskScreen), findsOneWidget);
    expect(find.text('ORD-100'), findsOneWidget);
    expect(find.text('Final-mile delivery'), findsOneWidget);
    expect(
      find.text('Makati City, Metro Manila · General area only'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Buyer contact details and exact street address'),
      findsOneWidget,
    );
    expect(find.textContaining('Parcel price'), findsNothing);
    expect(find.text('View delivery route'), findsNothing);

    await tester.tap(find.text('Accept delivery'));
    await tester.pumpAndSettle();
    expect(find.text('Accept delivery?'), findsOneWidget);
    expect(
      find.textContaining('Other parcels keep their current decisions'),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Accept delivery'),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.acceptCalls, 0);
    expect(parcels.accepted, ['task-1']);
    expect(
      controller.batchById('schedule-1')!.tasks.first.status,
      'delivery_accepted',
    );
    expect(
      controller.batchById('schedule-1')!.tasks.last.status,
      'delivery_assigned',
    );
  });

  testWidgets('rejects one offer with a reason and preserves its siblings', (
    tester,
  ) async {
    final repository = WidgetBatchRepository();
    final parcels = WidgetParcelRepository(repository);
    final controller = FinalMileBatchController(
      repository: repository,
      parcelRepository: parcels,
    );
    await controller.load();
    await controller.loadDetail('schedule-1');
    final auth = batchAuthController();
    await tester.pumpWidget(
      MaterialApp(
        home: FinalMileOfferedTaskScreen(
          authController: auth,
          batchController: controller,
          scheduleId: 'schedule-1',
          taskId: 'task-2',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      controller.detailStatus('schedule-1'),
      FinalMileBatchLoadStatus.loaded,
    );
    expect(
      controller
          .batchById('schedule-1')!
          .tasks
          .singleWhere((task) => task.id == 'task-2')
          .status,
      'delivery_assigned',
    );
    await tester.tap(find.text('Reject offer'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Cannot take this task');
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Cannot take this task',
    );
    final rejectConfirmation = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Reject offer'),
    );
    expect(
      tester
          .widget<FilledButton>(
            find.ancestor(
              of: rejectConfirmation,
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed,
      isNotNull,
    );
    await tester.ensureVisible(rejectConfirmation);
    await tester.tap(rejectConfirmation);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);

    expect(parcels.rejected, ['task-2']);
    expect(parcels.reasons, ['Cannot take this task']);
    expect(
      controller.batchById('schedule-1')!.tasks.map((task) => task.id),
      containsAll(['task-1', 'task-3']),
    );
    expect(
      controller.batchById('schedule-1')!.tasks.first.status,
      'delivery_assigned',
    );
  });

  testWidgets('Message Logistics opens the current final-mile task thread', (
    tester,
  ) async {
    final repository = WidgetBatchRepository();
    final controller = FinalMileBatchController(
      repository: repository,
      parcelRepository: WidgetParcelRepository(repository),
    );
    await controller.load();
    await controller.loadDetail('schedule-1');
    final auth = batchAuthController();
    auth.status = AuthStatus.authenticated;
    final chat = ChatController(repository: _BatchChatRepository());
    await tester.pumpWidget(
      MaterialApp(
        home: FinalMileOfferedTaskScreen(
          authController: auth,
          batchController: controller,
          scheduleId: 'schedule-1',
          taskId: 'task-1',
          chatController: chat,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Message Logistics'));
    await tester.pumpAndSettle();

    expect(chat.activeTask?.taskId, 'task-1');
    expect(chat.activeTask?.leg, 'final_mile');
    expect(chat.activeTask?.counterpartyRole, 'logistics');
    expect(find.byType(TextField), findsOneWidget);
  });
}

class _BatchChatRepository implements ChatRepository {
  @override
  Future<ChatPage<ChatThread>> list({
    String? leg,
    String? cursor,
    int limit = 20,
  }) async => const ChatPage(items: [], nextCursor: null, unreadCount: 0);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
