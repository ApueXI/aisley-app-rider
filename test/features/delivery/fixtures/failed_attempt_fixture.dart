import 'dart:async';
import 'dart:typed_data';

import 'package:aisley_app/core/networking/api_client.dart';

import 'package:aisley_app/features/delivery/domain/delivery_models.dart';
import 'package:aisley_app/features/delivery/domain/failed_delivery_attempt.dart';
import 'package:aisley_app/features/delivery/presentation/controllers/delivery_controller.dart';

import 'delivery_screen_fixture.dart';

class FailedAttemptRepository extends WidgetDeliveryRepository {
  final requests = <PendingFailedDeliveryAttempt>[];
  final attempts = <FailedDeliveryAttempt>[];
  Object? reportError;
  Object? readError;
  Completer<FailedDeliveryAttemptReceipt>? delayedReport;
  Completer<DeliveryContext>? delayedContext;
  bool malformedReceipt = false;
  bool pendingCompletion = false;
  bool failReadsAfterReport = false;
  int revision = 7;
  String status = 'out_for_delivery';
  int? proofCount;
  bool countsAvailable = true;
  int completionWrites = 0;

  @override
  Future<DeliveryContext> fetchDeliveryContext(String taskId) async {
    if (readError case final error?) throw error;
    if (delayedContext != null) return delayedContext!.future;
    return DeliveryContext(
      taskId: taskId,
      status: status,
      revision: revision,
      failedAttemptCount: countsAvailable ? attempts.length : null,
      failedAttempts: List.unmodifiable(attempts.reversed),
      paymentMethod: 'cod',
      paymentStatus: 'pending',
      payableTotal: '115.00',
      currency: 'PHP',
    );
  }

  @override
  Future<CompletionProjection> fetchCompletion(String taskId) async {
    if (readError case final error?) throw error;
    return CompletionProjection(
      taskId: taskId,
      taskStatus: status,
      revision: revision,
      completionStatus: pendingCompletion ? 'awaiting_validation' : null,
      intentId: pendingCompletion ? 'intent-1' : null,
      evidenceId: proofCount == null ? null : 'proof-1',
      evidenceStatus: proofCount == null
          ? 'unavailable'
          : 'awaiting_validation',
      proofFailedAttemptCount: countsAvailable ? proofCount : null,
    );
  }

  @override
  Future<FailedDeliveryAttemptReceipt> reportFailedAttempt({
    required String taskId,
    required FailedDeliveryReason reason,
    required String? note,
    required int expectedRevision,
    required String idempotencyKey,
  }) async {
    requests.add(
      PendingFailedDeliveryAttempt(
        reason: reason,
        note: note,
        expectedRevision: expectedRevision,
        idempotencyKey: idempotencyKey,
      ),
    );
    if (delayedReport != null) return delayedReport!.future;
    if (reportError case final error?) throw error;
    final receipt = receiptFor(taskId, reason, note);
    if (!attempts.any((item) => item.id == receipt.attempt.id)) {
      attempts.add(receipt.attempt);
    }
    if (failReadsAfterReport) {
      readError = const ApiException.network('offline refresh');
    }
    return malformedReceipt
        ? FailedDeliveryAttemptReceipt(
            taskId: 'foreign-task',
            attempt: receipt.attempt,
            retryAllowed: true,
          )
        : receipt;
  }

  @override
  Future<ProofSubmission> submitProof({
    required String taskId,
    required DeliveryPhotoSelection photo,
    required int expectedRevision,
    required String idempotencyKey,
    void Function(void Function() cancel)? onCancel,
  }) async {
    final result = await super.submitProof(
      taskId: taskId,
      photo: photo,
      expectedRevision: expectedRevision,
      idempotencyKey: idempotencyKey,
      onCancel: onCancel,
    );
    proofCount = attempts.length;
    return result;
  }

  @override
  Future<CompletionProjection> submitCompletion({
    required String taskId,
    required int expectedRevision,
    required String evidenceId,
    required String idempotencyKey,
    required bool codCollected,
  }) async {
    completionWrites++;
    return super.submitCompletion(
      taskId: taskId,
      expectedRevision: expectedRevision,
      evidenceId: evidenceId,
      idempotencyKey: idempotencyKey,
      codCollected: codCollected,
    );
  }
}

FailedDeliveryAttemptReceipt receiptFor(
  String taskId,
  FailedDeliveryReason reason,
  String? note,
) => FailedDeliveryAttemptReceipt(
  taskId: taskId,
  retryAllowed: true,
  attempt: FailedDeliveryAttempt(
    id: 'attempt-1',
    reason: reason.value,
    note: note,
    attemptedAt: DateTime.utc(2026, 10, 11, 9),
  ),
);

Future<DeliveryController> readyFailedAttemptController(
  FailedAttemptRepository repository,
) async {
  final controller = DeliveryController(deliveryRepository: repository)
    ..tasks = [outForDeliveryTask];
  await controller.loadDetails(outForDeliveryTask);
  return controller;
}

DeliveryPhotoSelection failedAttemptPhoto() => DeliveryPhotoSelection(
  path: null,
  fileName: 'proof.jpg',
  bytes: Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]),
);
