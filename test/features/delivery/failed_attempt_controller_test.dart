import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/core/networking/api_contract_exception.dart';
import 'package:aisley_app/core/security/token_storage.dart';
import 'package:aisley_app/features/delivery/domain/delivery_models.dart';
import 'package:aisley_app/features/delivery/domain/failed_delivery_attempt.dart';
import 'package:aisley_app/features/delivery/presentation/controllers/delivery_controller.dart';
import 'package:aisley_app/features/pickup/domain/pickup_models.dart';

import 'fixtures/delivery_screen_fixture.dart';
import 'fixtures/failed_attempt_fixture.dart';

void main() {
  test('confirmed report preserves custody and refreshes history', () async {
    final repo = FailedAttemptRepository();
    final c = await readyFailedAttemptController(repo);
    addTearDown(c.dispose);
    expect(
      await c.reportFailedAttempt(
        outForDeliveryTask,
        reason: FailedDeliveryReason.other,
        note: '  Closed building  ',
      ),
      isTrue,
    );
    expect(repo.requests.single.note, 'Closed building');
    expect(repo.requests.single.expectedRevision, 7);
    expect(
      repo.requests.single.idempotencyKey,
      matches(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      ),
    );
    expect(c.taskById(outForDeliveryTask.id)?.rawStatus, 'out_for_delivery');
    expect(c.taskById(outForDeliveryTask.id)?.revision, 7);
    expect(c.contexts[outForDeliveryTask.id]?.failedAttemptCount, 1);
    expect(
      c.contexts[outForDeliveryTask.id]?.failedAttempts.single.note,
      'Closed building',
    );
    expect(c.hasPendingFailedAttempt(outForDeliveryTask), isFalse);
    expect(repo.completionWrites, 0);
  });

  for (final error in <Object>[
    const ApiException.network('offline'),
    const ApiException.network(
      'timeout',
      networkFailure: ApiNetworkFailure.timeout,
    ),
    const ApiException(
      statusCode: 503,
      code: 'UNAVAILABLE',
      message: 'internal',
    ),
    const ApiContractException('bad receipt'),
    TokenStorageException('read', StateError('unavailable')),
  ]) {
    test('uncertain report freezes payload and exact retry: $error', () async {
      final repo = FailedAttemptRepository()..reportError = error;
      final c = await readyFailedAttemptController(repo);
      addTearDown(c.dispose);
      expect(
        await c.reportFailedAttempt(
          outForDeliveryTask,
          reason: FailedDeliveryReason.recipientUnavailable,
        ),
        isFalse,
      );
      final pending = c.pendingFailedAttempt(outForDeliveryTask)!;
      repo.revision = 9;
      await c.loadDetails(outForDeliveryTask);
      expect(
        await c.reportFailedAttempt(
          outForDeliveryTask,
          reason: FailedDeliveryReason.other,
          note: 'changed',
        ),
        isFalse,
      );
      expect(
        await c.submitProof(outForDeliveryTask, photo: failedAttemptPhoto()),
        isFalse,
      );
      expect(c.canStartAction(outForDeliveryTask), isFalse);
      repo.reportError = null;
      expect(await c.retryFailedAttempt(outForDeliveryTask), isTrue);
      expect(repo.requests, hasLength(2));
      expect(repo.requests.last.idempotencyKey, pending.idempotencyKey);
      expect(repo.requests.last.expectedRevision, 7);
      expect(repo.requests.last.reason, pending.reason);
      expect(repo.requests.last.note, pending.note);
    });
  }

  test(
    'malformed success stays uncertain and does not claim recorded',
    () async {
      final repo = FailedAttemptRepository()..malformedReceipt = true;
      final c = await readyFailedAttemptController(repo);
      addTearDown(c.dispose);
      expect(
        await c.reportFailedAttempt(
          outForDeliveryTask,
          reason: FailedDeliveryReason.addressUnreachable,
        ),
        isFalse,
      );
      expect(c.failedAttemptReceipts, isEmpty);
      expect(c.hasPendingFailedAttempt(outForDeliveryTask), isTrue);
      repo.malformedReceipt = false;
      expect(await c.retryFailedAttempt(outForDeliveryTask), isTrue);
      expect(repo.attempts, hasLength(1));
    },
  );

  test(
    'duplicate taps and competing actions cannot race an in-flight report',
    () async {
      final repo = FailedAttemptRepository()..delayedReport = Completer();
      final c = await readyFailedAttemptController(repo);
      addTearDown(c.dispose);
      final first = c.reportFailedAttempt(
        outForDeliveryTask,
        reason: FailedDeliveryReason.recipientRefused,
      );
      await Future<void>.delayed(Duration.zero);
      expect(c.isActionBusy(outForDeliveryTask), isTrue);
      expect(await c.retryFailedAttempt(outForDeliveryTask), isFalse);
      expect(
        await c.reportFailedAttempt(
          outForDeliveryTask,
          reason: FailedDeliveryReason.other,
          note: 'second',
        ),
        isFalse,
      );
      expect(
        await c.submitProof(outForDeliveryTask, photo: failedAttemptPhoto()),
        isFalse,
      );
      expect(await c.prepareCodCompletion(outForDeliveryTask), isNull);
      await c.load(); // list refresh cannot invalidate an in-flight mutation
      repo.delayedReport!.complete(
        receiptFor(
          outForDeliveryTask.id,
          FailedDeliveryReason.recipientRefused,
          null,
        ),
      );
      expect(await first, isTrue);
      expect(repo.requests, hasLength(1));
    },
  );

  for (final code in [
    'TASK_STATE_CONFLICT',
    'COMPLETION_PENDING',
    'IDEMPOTENCY_KEY_REUSED',
  ]) {
    test('handles $code without silently creating another report', () async {
      final repo = FailedAttemptRepository()
        ..reportError = ApiException(
          statusCode: 409,
          code: code,
          message: 'private',
        );
      final c = await readyFailedAttemptController(repo);
      addTearDown(c.dispose);
      await c.reportFailedAttempt(
        outForDeliveryTask,
        reason: FailedDeliveryReason.recipientUnavailable,
      );
      expect(
        c.failedAttemptErrors[outForDeliveryTask.id],
        isNot(contains('private')),
      );
      expect(c.canReportFailedAttempt(outForDeliveryTask), isFalse);
      expect(await c.retryFailedAttempt(outForDeliveryTask), isFalse);
      await c.loadDetails(outForDeliveryTask);
      expect(
        c.hasPendingFailedAttempt(outForDeliveryTask),
        code == 'IDEMPOTENCY_KEY_REUSED',
      );
      expect(
        c.canReportFailedAttempt(outForDeliveryTask),
        code != 'IDEMPOTENCY_KEY_REUSED',
      );
      expect(repo.requests, hasLength(1));
    });
  }

  test('validation permits correcting the note without preserving a rejected request', () async {
    final repo = FailedAttemptRepository()
      ..reportError = const ApiException(
        statusCode: 422,
        code: 'VALIDATION_FAILED',
        message: 'private',
        fieldErrors: {
          'note': ['private validation detail'],
        },
      );
    final c = await readyFailedAttemptController(repo);
    addTearDown(c.dispose);
    expect(
      await c.reportFailedAttempt(
        outForDeliveryTask,
        reason: FailedDeliveryReason.other,
        note: '   ',
      ),
      isFalse,
    );
    expect(repo.requests, isEmpty);
    await c.reportFailedAttempt(
      outForDeliveryTask,
      reason: FailedDeliveryReason.other,
      note: 'valid',
    );
    expect(c.hasPendingFailedAttempt(outForDeliveryTask), isFalse);
    expect(
      c.failedAttemptFieldErrors[outForDeliveryTask.id]?['note'],
      isNotEmpty,
    );
    repo.reportError = null;
    expect(
      await c.reportFailedAttempt(
        outForDeliveryTask,
        reason: FailedDeliveryReason.other,
        note: 'corrected',
      ),
      isTrue,
    );
    expect(
      repo.requests.first.idempotencyKey,
      isNot(repo.requests.last.idempotencyKey),
    );
  });

  test('500 characters accepted; 501 rejected locally', () async {
    final repo = FailedAttemptRepository();
    final c = await readyFailedAttemptController(repo);
    addTearDown(c.dispose);
    expect(
      await c.reportFailedAttempt(
        outForDeliveryTask,
        reason: FailedDeliveryReason.other,
        note: 'a' * 501,
      ),
      isFalse,
    );
    expect(repo.requests, isEmpty);
    expect(
      await c.reportFailedAttempt(
        outForDeliveryTask,
        reason: FailedDeliveryReason.other,
        note: 'a' * 500,
      ),
      isTrue,
    );
  });

  test(
    'server review beginning after the screen loaded prevents any POST',
    () async {
      final repo = FailedAttemptRepository();
      final c = await readyFailedAttemptController(repo);
      addTearDown(c.dispose);
      repo.pendingCompletion = true;
      expect(
        await c.reportFailedAttempt(
          outForDeliveryTask,
          reason: FailedDeliveryReason.recipientUnavailable,
        ),
        isFalse,
      );
      expect(repo.requests, isEmpty);
      expect(c.canReportFailedAttempt(outForDeliveryTask), isFalse);
    },
  );

  test('wrong leg, terminal state and missing authoritative reads prevent reporting', () async {
    final repo = FailedAttemptRepository();
    final c = DeliveryController(deliveryRepository: repo);
    addTearDown(c.dispose);
    expect(
      await c.reportFailedAttempt(
        outForDeliveryTask,
        reason: FailedDeliveryReason.recipientUnavailable,
      ),
      isFalse,
    );
    await c.loadDetails(outForDeliveryTask);
    for (final task in [
      const PickupTask(
        id: 'delivery-task-1',
        leg: PickupTaskLeg.firstMile,
        rawStatus: 'out_for_delivery',
        revision: 7,
      ),
      outForDeliveryTask.copyWith(rawStatus: 'delivered'),
      outForDeliveryTask.copyWith(rawStatus: 'in_transit'),
    ]) {
      expect(
        await c.reportFailedAttempt(
          task,
          reason: FailedDeliveryReason.other,
          note: 'note',
        ),
        isFalse,
      );
    }
    expect(repo.requests, isEmpty);
  });

  test(
    'throttling blocks all retries until the original cooldown ends',
    () async {
      final repo = FailedAttemptRepository()
        ..reportError = const ApiException(
          statusCode: 429,
          code: 'TOO_MANY_REQUESTS',
          message: 'throttled',
          retryAfter: Duration(milliseconds: 30),
        );
      final c = await readyFailedAttemptController(repo);
      addTearDown(c.dispose);
      await c.reportFailedAttempt(
        outForDeliveryTask,
        reason: FailedDeliveryReason.recipientUnavailable,
      );
      expect(await c.retryFailedAttempt(outForDeliveryTask), isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 45));
      repo.reportError = null;
      expect(await c.retryFailedAttempt(outForDeliveryTask), isTrue);
      expect(
        repo.requests.first.idempotencyKey,
        repo.requests.last.idempotencyKey,
      );
    },
  );

  for (final status in [401, 403, 404]) {
    test(
      'denial $status blocks reporting and removes uncertain payload',
      () async {
        final repo = FailedAttemptRepository()
          ..proofCount = 0
          ..reportError = ApiException(
            statusCode: status,
            code: 'DENIED',
            message: 'private',
          );
        ApiException? notified;
        final c = DeliveryController(
          deliveryRepository: repo,
          onAuthFailure: (error) async => notified = error,
        )..tasks = [outForDeliveryTask];
        addTearDown(c.dispose);
        await c.loadDetails(outForDeliveryTask);
        await c.reportFailedAttempt(
          outForDeliveryTask,
          reason: FailedDeliveryReason.recipientUnavailable,
        );
        expect(c.proofPhotos, isEmpty);
        expect(c.contexts, isEmpty);
        expect(c.completions, isEmpty);
        expect(c.hasPendingFailedAttempt(outForDeliveryTask), isFalse);
        expect(c.canReportFailedAttempt(outForDeliveryTask), isFalse);
        expect(notified?.statusCode, status == 404 ? null : status);
      },
    );
  }

  for (final invalidate in ['clear', 'dispose', 'invalidateDetails']) {
    test('$invalidate rejects obsolete successful replies', () async {
      final repo = FailedAttemptRepository()..delayedReport = Completer();
      final c = await readyFailedAttemptController(repo);
      final first = c.reportFailedAttempt(
        outForDeliveryTask,
        reason: FailedDeliveryReason.other,
        note: 'note',
      );
      await Future<void>.delayed(Duration.zero);
      switch (invalidate) {
        case 'clear':
          c.clear();
        case 'dispose':
          c.dispose();
        case 'invalidateDetails':
          c.invalidateDetails();
      }
      repo.delayedReport!.complete(
        receiptFor(outForDeliveryTask.id, FailedDeliveryReason.other, 'note'),
      );
      expect(await first, isFalse);
      expect(c.failedAttemptReceipts, isEmpty);
      if (invalidate != 'dispose') c.dispose();
    });
  }

  test(
    'clear during preflight prevents POST and cannot restore private state',
    () async {
      final repo = FailedAttemptRepository();
      final c = await readyFailedAttemptController(repo);
      addTearDown(c.dispose);
      repo.delayedContext = Completer();
      final first = c.reportFailedAttempt(
        outForDeliveryTask,
        reason: FailedDeliveryReason.other,
        note: 'note',
      );
      c.clear();
      repo.delayedContext!.complete(
        const DeliveryContext(
          taskId: 'delivery-task-1',
          status: 'out_for_delivery',
          revision: 7,
          failedAttemptCount: 0,
        ),
      );
      expect(await first, isFalse);
      expect(repo.requests, isEmpty);
      expect(c.contexts, isEmpty);
    },
  );

  test('failed visit invalidates photo across reload; fresh photo restores completion', () async {
    final repo = FailedAttemptRepository();
    var c = await readyFailedAttemptController(repo);
    await c.submitProof(outForDeliveryTask, photo: failedAttemptPhoto());
    expect(c.hasFreshProof(outForDeliveryTask), isTrue);
    await c.reportFailedAttempt(
      outForDeliveryTask,
      reason: FailedDeliveryReason.recipientUnavailable,
    );
    expect(c.hasFreshProof(outForDeliveryTask), isFalse);
    expect(await c.prepareCodCompletion(outForDeliveryTask), isNull);
    expect(
      await c.submitCompletion(
        outForDeliveryTask,
        evidenceId: 'proof-1',
        confirmedCollection: const DeliveryCodCollection(
          amount: '115.00',
          currency: 'PHP',
        ),
      ),
      isFalse,
    );
    c.dispose();
    c = await readyFailedAttemptController(repo);
    addTearDown(c.dispose);
    expect(c.hasFreshProof(outForDeliveryTask), isFalse);
    expect(
      await c.submitProof(outForDeliveryTask, photo: failedAttemptPhoto()),
      isTrue,
    );
    expect(c.hasFreshProof(outForDeliveryTask), isTrue);
    expect(await c.prepareCodCompletion(outForDeliveryTask), isNotNull);
    expect(repo.completionWrites, 0);
  });

  test(
    'unknown proof count blocks completion without inventing freshness',
    () async {
      final repo = FailedAttemptRepository()
        ..proofCount = 0
        ..countsAvailable = false;
      final c = await readyFailedAttemptController(repo);
      addTearDown(c.dispose);
      expect(c.hasFreshProof(outForDeliveryTask), isFalse);
      expect(await c.prepareCodCompletion(outForDeliveryTask), isNull);
    },
  );
  test(
    'confirmed write with failed refresh stays recorded and cannot resend',
    () async {
      final repo = FailedAttemptRepository()..failReadsAfterReport = true;
      final c = await readyFailedAttemptController(repo);
      addTearDown(c.dispose);
      expect(
        await c.reportFailedAttempt(
          outForDeliveryTask,
          reason: FailedDeliveryReason.recipientUnavailable,
        ),
        isTrue,
      );
      expect(c.failedAttemptReceipts[outForDeliveryTask.id], isNotNull);
      expect(c.hasPendingFailedAttempt(outForDeliveryTask), isFalse);
      expect(c.canReportFailedAttempt(outForDeliveryTask), isFalse);
      expect(await c.retryFailedAttempt(outForDeliveryTask), isFalse);
      expect(repo.requests, hasLength(1));
      expect(
        c.contextStatuses[outForDeliveryTask.id],
        DeliveryLoadStatus.offline,
      );
    },
  );

  test('policy recovery preserves the same report and unlocks only after fresh reads', () async {
    final repo = FailedAttemptRepository()
      ..reportError = const ApiException(
        statusCode: 403,
        code: 'POLICY_CONSENT_REQUIRED',
        message: 'policy',
      );
    final c = await readyFailedAttemptController(repo);
    addTearDown(c.dispose);
    await c.reportFailedAttempt(
      outForDeliveryTask,
      reason: FailedDeliveryReason.other,
      note: 'note',
    );
    expect(c.hasPendingFailedAttempt(outForDeliveryTask), isTrue);
    expect(c.canRetryFailedAttempt(outForDeliveryTask), isFalse);
    repo.reportError = null;
    await c.loadDetails(outForDeliveryTask);
    expect(await c.retryFailedAttempt(outForDeliveryTask), isTrue);
    expect(
      repo.requests.first.idempotencyKey,
      repo.requests.last.idempotencyKey,
    );
  });

  test(
    'denied task refresh removes private pending notes and blocks retry',
    () async {
      final repo = FailedAttemptRepository()
        ..reportError = const ApiException.network('offline');
      final c = await readyFailedAttemptController(repo);
      addTearDown(c.dispose);
      await c.reportFailedAttempt(
        outForDeliveryTask,
        reason: FailedDeliveryReason.other,
        note: 'private draft',
      );
      repo.readError = const ApiException(
        statusCode: 404,
        code: 'TASK_NOT_FOUND',
        message: 'unavailable',
      );
      await c.loadDetails(outForDeliveryTask);
      expect(c.pendingFailedAttempt(outForDeliveryTask), isNull);
      expect(c.failedAttemptReceipts, isEmpty);
      expect(c.canRetryFailedAttempt(outForDeliveryTask), isFalse);
    },
  );

  for (final failure in [
    const ApiException.network('offline preflight'),
    const ApiContractException('bad preflight'),
    TokenStorageException('read', StateError('storage unavailable')),
  ]) {
    test('recoverable preflight failure sends no POST: $failure', () async {
      final repo = FailedAttemptRepository();
      final c = await readyFailedAttemptController(repo);
      addTearDown(c.dispose);
      repo.readError = failure;
      expect(
        await c.reportFailedAttempt(
          outForDeliveryTask,
          reason: FailedDeliveryReason.recipientUnavailable,
        ),
        isFalse,
      );
      expect(c.hasPendingFailedAttempt(outForDeliveryTask), isFalse);
      expect(repo.requests, isEmpty);
      expect(c.isActionBusy(outForDeliveryTask), isFalse);
    });
  }
}
