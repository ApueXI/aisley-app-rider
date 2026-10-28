import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/features/delivery/domain/delivery_models.dart';
import 'package:aisley_app/features/delivery/presentation/controllers/delivery_controller.dart';

import 'fixtures/delivery_screen_fixture.dart';

class DirectRepository extends WidgetDeliveryRepository {
  final proofKeys = <String>[];
  final _completionKeys = <String>[];
  Object? intentError;
  Completer<DeliveryContext>? pendingPayment;
  int movementWrites = 0;

  @override
  List<String> get completionKeys => _completionKeys;

  @override
  Future<DeliveryContext> fetchDeliveryContext(String id) =>
      pendingPayment?.future ?? super.fetchDeliveryContext(id);
  @override
  Future<DeliveryStatusUpdate> advanceStatus({
    required String taskId,
    required String status,
    required int expectedRevision,
    required String idempotencyKey,
  }) async {
    movementWrites++;
    return super.advanceStatus(
      taskId: taskId,
      status: status,
      expectedRevision: expectedRevision,
      idempotencyKey: idempotencyKey,
    );
  }

  @override
  Future<ProofSubmission> submitProof({
    required String taskId,
    required DeliveryPhotoSelection photo,
    required int expectedRevision,
    required String idempotencyKey,
    void Function(void Function())? onCancel,
  }) {
    proofKeys.add(idempotencyKey);
    return super.submitProof(
      taskId: taskId,
      photo: photo,
      expectedRevision: expectedRevision,
      idempotencyKey: idempotencyKey,
      onCancel: onCancel,
    );
  }

  @override
  Future<CompletionProjection> submitCompletion({
    required String taskId,
    required int expectedRevision,
    required String evidenceId,
    required String idempotencyKey,
    required bool codCollected,
  }) {
    _completionKeys.add(idempotencyKey);
    if (intentError != null) return Future.error(intentError!);
    return super.submitCompletion(
      taskId: taskId,
      expectedRevision: expectedRevision,
      evidenceId: evidenceId,
      idempotencyKey: idempotencyKey,
      codCollected: codCollected,
    );
  }
}

final photo = DeliveryPhotoSelection(
  path: null,
  fileName: 'proof.jpg',
  bytes: Uint8List.fromList([255, 216, 255, 217]),
);
const payment = DeliveryCodCollection(amount: '115.00', currency: 'PHP');
void main() {
  test('list refresh cannot invalidate an active Delivered response or leave its lock stuck', () async {
    final repo = DirectRepository()
      ..pendingPayment = Completer<DeliveryContext>();
    final c = DeliveryController(deliveryRepository: repo)
      ..tasks = [outForDeliveryTask];
    addTearDown(c.dispose);
    final submission = c.submitDelivered(
      outForDeliveryTask,
      photo: photo,
      confirmedCollection: payment,
    );
    await c.load();
    repo.pendingPayment!.complete(repo.deliveryContext);
    expect(await submission, true);
    expect(c.isSubmittingDelivered(outForDeliveryTask), false);
    expect(c.isCompletionPending(outForDeliveryTask), true);
  });

  test(
    'lost committed intent is reconciled by GET without another upload or POST',
    () async {
      final repo = DirectRepository()
        ..intentError = const ApiException.network('lost receipt');
      final c = DeliveryController(deliveryRepository: repo)
        ..tasks = [outForDeliveryTask];
      addTearDown(c.dispose);
      expect(
        await c.submitDelivered(
          outForDeliveryTask,
          photo: photo,
          confirmedCollection: payment,
        ),
        false,
      );
      repo.completionEvidenceId = 'proof-1';
      expect(
        await c.submitDelivered(
          outForDeliveryTask,
          confirmedCollection: payment,
        ),
        true,
      );
      expect(repo.proofKeys, hasLength(1));
      expect(repo.completionKeys, hasLength(1));
      expect(c.isCompletionPending(outForDeliveryTask), true);
      expect(c.hasPendingCompletion(outForDeliveryTask), false);
    },
  );

  for (final state in [
    'delivery_accepted',
    'picked_up_from_hub',
    'in_transit',
    'out_for_delivery',
  ]) {
    test(
      'direct photo and intent from $state preserve physical state',
      () async {
        final repo = DirectRepository()..taskStatus = state;
        repo.deliveryContext = repo.deliveryContext.copyWith(status: state);
        final task = outForDeliveryTask.copyWith(rawStatus: state);
        final c = DeliveryController(deliveryRepository: repo)..tasks = [task];
        addTearDown(c.dispose);
        expect(
          await c.submitDelivered(
            task,
            photo: photo,
            confirmedCollection: payment,
          ),
          true,
        );
        expect(repo.proofKeys, hasLength(1));
        expect(repo.completionKeys, hasLength(1));
        expect(repo.movementWrites, 0);
        expect(c.taskById(task.id)!.rawStatus, state);
        expect(c.completions[task.id]!.isDelivered, false);
        expect(c.isCompletionPending(task), true);
      },
    );
  }
  test(
    'partial failure retains photo and retries the same intent key',
    () async {
      final repo = DirectRepository()
        ..intentError = const ApiException.network('lost response');
      final c = DeliveryController(deliveryRepository: repo)
        ..tasks = [outForDeliveryTask];
      addTearDown(c.dispose);
      expect(
        await c.submitDelivered(
          outForDeliveryTask,
          photo: photo,
          confirmedCollection: payment,
        ),
        false,
      );
      repo.intentError = null;
      expect(
        await c.submitDelivered(
          outForDeliveryTask,
          confirmedCollection: payment,
        ),
        true,
      );
      expect(repo.proofKeys, hasLength(1));
      expect(repo.completionKeys, hasLength(2));
      expect(repo.completionKeys.toSet(), hasLength(1));
    },
  );
  test('uncertain photo preserves the upload key', () async {
    final repo = DirectRepository()
      ..proofError = const ApiException.network('lost photo');
    final c = DeliveryController(deliveryRepository: repo)
      ..tasks = [outForDeliveryTask];
    addTearDown(c.dispose);
    expect(
      await c.submitDelivered(
        outForDeliveryTask,
        photo: photo,
        confirmedCollection: payment,
      ),
      false,
    );
    repo.proofError = null;
    expect(
      await c.submitDelivered(outForDeliveryTask, confirmedCollection: payment),
      true,
    );
    expect(repo.proofKeys.toSet(), hasLength(1));
    expect(repo.completionKeys, hasLength(1));
  });
  test('payment changes block photo and intent writes', () async {
    final repo = DirectRepository();
    final c = DeliveryController(deliveryRepository: repo);
    addTearDown(c.dispose);
    expect(
      await c.submitDelivered(
        outForDeliveryTask,
        photo: photo,
        confirmedCollection: const DeliveryCodCollection(
          amount: '100.00',
          currency: 'PHP',
        ),
      ),
      false,
    );
    expect(repo.proofKeys, isEmpty);
    expect(repo.completionKeys, isEmpty);
  });
  test('paid prepaid intent omits COD declaration', () async {
    final repo = DirectRepository();
    repo.deliveryContext = const DeliveryContext(
      taskId: 'delivery-task-1',
      status: 'delivery_accepted',
      revision: 7,
      failedAttemptCount: 0,
      paymentMethod: 'prepaid',
      paymentStatus: 'paid',
    );
    repo.taskStatus = 'delivery_accepted';
    final task = outForDeliveryTask.copyWith(rawStatus: 'delivery_accepted');
    final c = DeliveryController(deliveryRepository: repo)..tasks = [task];
    addTearDown(c.dispose);
    final p = await c.prepareDeliveryPayment(task);
    expect(p!.isCod, false);
    expect(
      await c.submitDelivered(task, photo: photo, confirmedCollection: p),
      true,
    );
    expect(repo.codCollected, false);
  });
  test(
    'duplicate submission and late payment reply after logout are ignored',
    () async {
      final repo = DirectRepository()
        ..pendingPayment = Completer<DeliveryContext>();
      final c = DeliveryController(deliveryRepository: repo);
      addTearDown(c.dispose);
      final first = c.submitDelivered(
        outForDeliveryTask,
        photo: photo,
        confirmedCollection: payment,
      );
      expect(
        await c.submitDelivered(
          outForDeliveryTask,
          photo: photo,
          confirmedCollection: payment,
        ),
        false,
      );
      c.clear();
      repo.pendingPayment!.complete(repo.deliveryContext);
      expect(await first, false);
      expect(repo.proofKeys, isEmpty);
      expect(c.contexts, isEmpty);
    },
  );
}
