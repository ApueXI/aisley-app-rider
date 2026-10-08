import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/core/networking/api_contract_exception.dart';
import 'package:aisley_app/features/delivery/data/delivery_repository.dart';
import 'package:aisley_app/features/delivery/domain/delivery_models.dart';
import 'package:aisley_app/features/delivery/presentation/controllers/delivery_controller.dart';
import 'package:aisley_app/features/pickup/domain/pickup_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final (field, guidance) in const [
    ('photo', 'Choose a JPEG, PNG or WebP'),
    ('evidence_id', 'Upload a delivery photo'),
    ('expected_revision', 'Refresh the task'),
    ('status', 'Refresh the task'),
    ('cod_collected', 'collected the full cash amount'),
    ('confirmed', 'collected the full cash amount'),
    ('unknown_internal_field', 'Check the delivery information'),
  ]) {
    test('validation of $field explains the visible correction', () async {
      final repository = _ErrorRepository()
        ..movementError = ApiException(
          statusCode: 422,
          code: 'VALIDATION_FAILED',
          message: 'Private server detail: $field',
          fieldErrors: {
            field: ['The $field field is invalid.'],
          },
        );
      final controller = DeliveryController(deliveryRepository: repository);
      addTearDown(controller.dispose);

      expect(await controller.advanceStatus(_task), isFalse);
      expect(
        controller.actionStatus(_task),
        DeliveryActionStatus.validationError,
      );
      expect(controller.actionError(_task), contains(guidance));
      expect(controller.actionError(_task), isNot(contains('Private server')));
      expect(
        controller.actionError(_task),
        isNot(contains('field is invalid')),
      );
      expect(controller.hasPendingMovement(_task), isFalse);
    });
  }

  for (final (code, guidance) in const [
    ('TASK_STATE_CONFLICT', 'review its current status'),
    ('COMPLETION_STATE_CONFLICT', 'delivery review status changed'),
    ('COD_COLLECTION_REQUIRED', 'collected the full cash amount'),
  ]) {
    test('$code has a useful explanation', () async {
      final repository = _ErrorRepository()
        ..movementError = ApiException(
          statusCode: code == 'COD_COLLECTION_REQUIRED' ? 422 : 409,
          code: code,
          message: 'expected_revision data.completion_status',
        );
      final controller = DeliveryController(deliveryRepository: repository);
      addTearDown(controller.dispose);
      await controller.advanceStatus(_task);
      expect(controller.actionError(_task), contains(guidance));
      expect(
        controller.actionError(_task),
        isNot(contains('expected_revision')),
      );
    });
  }

  test('forbidden delivery never exposes a raw server explanation', () async {
    final repository = _ErrorRepository()
      ..readError = const ApiException(
        statusCode: 403,
        code: 'FORBIDDEN',
        message: 'Private reviewer notes and internal_field',
      );
    final controller = DeliveryController(deliveryRepository: repository);
    addTearDown(controller.dispose);
    await controller.load();
    expect(controller.loadStatus, DeliveryLoadStatus.forbidden);
    expect(
      controller.errorMessage,
      contains('Contact your Logistics organization'),
    );
    expect(controller.errorMessage, isNot(contains('Private reviewer')));
  });

  for (final failure in const [
    ApiException.network(
      'internal detail',
      networkFailure: ApiNetworkFailure.timeout,
    ),
    ApiException.network('internal detail'),
    ApiException(
      statusCode: 503,
      code: 'UNAVAILABLE',
      message: 'internal detail',
    ),
    ApiContractException('delivery.status.task_projection'),
  ]) {
    test('${failure.runtimeType} retains the same movement attempt', () async {
      final repository = _ErrorRepository()..movementError = failure;
      final controller = DeliveryController(deliveryRepository: repository)
        ..tasks = [_task];
      addTearDown(controller.dispose);
      await controller.advanceStatus(_task);

      expect(
        controller.actionError(_task)?.toLowerCase(),
        contains('refresh the task before retrying the same action'),
      );
      expect(controller.actionError(_task), isNot(contains('internal detail')));
      expect(controller.actionError(_task), isNot(contains('delivery.status')));
      expect(controller.hasPendingMovement(_task), isTrue);
      repository.movementError = null;
      expect(await controller.retryMovement(_task), isTrue);
      expect(repository.keys, hasLength(2));
      expect(repository.keys[0], repository.keys[1]);
    });
  }

  test(
    'failed read suggests retry without implying a pending submission',
    () async {
      final repository = _ErrorRepository()
        ..readError = const ApiException.network(
          'internal detail',
          networkFailure: ApiNetworkFailure.timeout,
        );
      final controller = DeliveryController(deliveryRepository: repository);
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.loadStatus, DeliveryLoadStatus.timeout);
      expect(
        controller.errorMessage,
        contains('Check your connection and retry'),
      );
      expect(
        controller.errorMessage,
        isNot(contains('update is not confirmed')),
      );
    },
  );

  test(
    'invalid completion read explains review recovery without field names',
    () async {
      final repository = _ErrorRepository();
      final controller = DeliveryController(deliveryRepository: repository);
      addTearDown(controller.dispose);
      await controller.loadCompletion(_task);
      expect(
        controller.completionStatuses[_task.id],
        DeliveryLoadStatus.failed,
      );
      expect(
        controller.completionErrors[_task.id],
        contains('whether Logistics has confirmed delivery'),
      );
      expect(
        controller.completionErrors[_task.id],
        isNot(contains('completion_status')),
      );
      expect(controller.completions, isEmpty);
    },
  );
}

const _task = PickupTask(
  id: 'delivery-1',
  leg: PickupTaskLeg.finalMile,
  rawStatus: 'picked_up_from_hub',
  revision: 4,
);

class _ErrorRepository implements DeliveryRepository {
  Object? readError;
  Object? movementError;
  final keys = <String>[];

  @override
  Future<List<PickupTask>> fetchFinalMileTasks() async {
    if (readError case final error?) throw error;
    return [_task];
  }

  @override
  Future<DeliveryStatusUpdate> advanceStatus({
    required String taskId,
    required String status,
    required int expectedRevision,
    required String idempotencyKey,
  }) async {
    keys.add(idempotencyKey);
    if (movementError case final error?) throw error;
    return DeliveryStatusUpdate(taskId: taskId, status: status, revision: 5);
  }

  @override
  Future<CompletionProjection> fetchCompletion(String taskId) async {
    throw const ApiContractException('delivery.completion.completion_status');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
