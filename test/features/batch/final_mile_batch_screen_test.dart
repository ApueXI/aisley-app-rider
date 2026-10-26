import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aisley_app/features/batch/presentation/controllers/final_mile_batch_controller.dart';
import 'package:aisley_app/features/batch/presentation/final_mile_batch_screen.dart';

import 'fixtures/final_mile_batch_screen_fixture.dart';

void main() {
  testWidgets('reviews parcel context and accepts only the chosen parcel', (
    tester,
  ) async {
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
    expect(find.text('2 parcels'), findsOneWidget);
    expect(find.text('Parcel price: PHP 1250.00'), findsOneWidget);
    expect(find.text('3 items'), findsOneWidget);
    expect(find.textContaining('not cash due on delivery'), findsWidgets);
    expect(find.text('Accept hub delivery'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Accept parcel').first,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Accept parcel').first);
    await tester.pumpAndSettle();
    expect(find.text('Accept parcel?'), findsOneWidget);
    expect(
      find.textContaining('Other parcels keep their current decisions'),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Accept parcel'),
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
}
