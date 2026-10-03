import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aisley_app/features/batch/presentation/controllers/final_mile_batch_controller.dart';
import 'package:aisley_app/features/batch/presentation/final_mile_batch_screen.dart';

import 'fixtures/final_mile_batch_screen_fixture.dart';

void main() {
  testWidgets('reviews parcel context and accepts the batch with one action', (
    tester,
  ) async {
    final repository = WidgetBatchRepository();
    final controller = FinalMileBatchController(repository: repository);
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
      find.text('Accept entire batch'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Accept entire batch'));
    await tester.pumpAndSettle();
    expect(find.text('Accept this entire batch?'), findsOneWidget);
    expect(
      find.textContaining('accept responsibility for all 2 parcels'),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Accept entire batch'),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.acceptCalls, 1);
    expect(find.text('Entire batch accepted'), findsOneWidget);
    expect(find.textContaining('does not record hub pickup'), findsOneWidget);
  });
}
