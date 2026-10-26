import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/features/batch/presentation/controllers/final_mile_batch_controller.dart';
import 'package:aisley_app/features/pickup/domain/pickup_models.dart';

import 'fixtures/final_mile_batch_screen_fixture.dart';

void main() {
  test(
    'accept/reject preserve siblings and refresh committed membership',
    () async {
      final batches = WidgetBatchRepository(),
          parcels = WidgetParcelRepository(WidgetBatchRepository());
      final api = WidgetParcelRepository(batches);
      var refreshed = 0;
      final c = FinalMileBatchController(
        repository: batches,
        parcelRepository: api,
        onBatchAccepted: () async {
          refreshed++;
        },
      );
      addTearDown(c.dispose);
      await c.load();
      expect(await c.decideParcel('schedule-1', 'task-1'), true);
      expect(c.batches.single.tasks.last.status, 'delivery_assigned');
      expect(
        await c.decideParcel('schedule-1', 'task-2', reason: 'Cannot carry'),
        true,
      );
      expect(c.batches.single.tasks.single.id, 'task-1');
      expect(refreshed, 2);
      expect(batches.acceptCalls, 0);
      expect(parcels.accepted, isEmpty);
    },
  );
  test(
    'uncertain rejection freezes reason/key and blocks sibling decisions',
    () async {
      final batches = WidgetBatchRepository();
      final api = WidgetParcelRepository(batches)
        ..error = const ApiException.network('offline');
      final c = FinalMileBatchController(
        repository: batches,
        parcelRepository: api,
      );
      addTearDown(c.dispose);
      await c.load();
      expect(
        await c.decideParcel('schedule-1', 'task-1', reason: 'Cannot carry'),
        false,
      );
      expect(await c.decideParcel('schedule-1', 'task-2'), false);
      expect(
        await c.decideParcel('schedule-1', 'task-1', reason: 'Changed reason'),
        false,
      );
      api.error = null;
      expect(await c.retryParcelDecision('schedule-1', 'task-1'), true);
      expect(api.keys.toSet(), hasLength(1));
      expect(api.reasons, ['Cannot carry', 'Cannot carry']);
      expect(c.batches.single.tasks.single.id, 'task-2');
    },
  );
  test('late reply after logout cannot restore private state', () async {
    final batches = WidgetBatchRepository();
    final api = WidgetParcelRepository(batches)
      ..pending = Completer<PickupTask>();
    final c = FinalMileBatchController(
      repository: batches,
      parcelRepository: api,
    );
    addTearDown(c.dispose);
    await c.load();
    final request = c.decideParcel('schedule-1', 'task-1');
    c.clear();
    api.pending!.complete(
      const PickupTask(
        id: 'task-1',
        leg: PickupTaskLeg.finalMile,
        rawStatus: 'delivery_accepted',
      ),
    );
    expect(await request, false);
    expect(c.batches, isEmpty);
    expect(c.decidingTask, isNull);
  });
}
