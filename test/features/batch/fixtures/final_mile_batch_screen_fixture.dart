import 'dart:async';

import 'package:aisley_app/core/networking/api_client.dart';

import 'package:aisley_app/features/auth/data/auth_repository.dart';
import 'package:aisley_app/features/auth/domain/auth_models.dart';
import 'package:aisley_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aisley_app/features/batch/data/final_mile_batch_repository.dart';
import 'package:aisley_app/features/batch/domain/final_mile_batch_models.dart';
import 'package:aisley_app/features/dashboard/data/dashboard_repository.dart';
import 'package:aisley_app/features/dashboard/domain/dashboard_models.dart';

import 'package:aisley_app/features/pickup/domain/pickup_models.dart';

import '../../pickup/fixtures/schedule_filter_repository.dart';

class WidgetBatchRepository implements FinalMileBatchRepository {
  var accepted = false;
  ApiException? readError;
  Completer<FinalMileBatch>? pendingRead;
  var acceptCalls = 0;
  final acceptedIds = <String>{}, rejectedIds = <String>{};
  @override
  Future<List<FinalMileBatch>> fetchBatches() async =>
      rejectedIds.length == 2 ? [] : [batch()];
  @override
  Future<FinalMileBatch> fetchBatch(String scheduleId) async {
    if (pendingRead case final pending?) return pending.future;
    if (readError case final error?) throw error;
    return batch();
  }

  @override
  Future<FinalMileBatch> acceptBatch(String scheduleId) async {
    acceptCalls++;
    accepted = true;
    return batch();
  }

  FinalMileBatch batch() => FinalMileBatch(
    id: 'schedule-1',
    reference: 'DSP-100',
    scheduledFor: DateTime.utc(2026, 9, 27, 1, 30),
    parcelCount: 2 - rejectedIds.length,
    status: accepted || acceptedIds.length + rejectedIds.length == 2
        ? FinalMileBatchStatus.accepted
        : FinalMileBatchStatus.offered,
    tasks: [
      for (var i = 1; i <= 2; i++)
        if (!rejectedIds.contains('task-$i'))
          FinalMileBatchTask(
            id: 'task-$i',
            status: accepted || acceptedIds.contains('task-$i')
                ? 'delivery_accepted'
                : 'delivery_assigned',
            orderReference: i == 1 ? 'ORD-100' : 'ORD-101',
            parcel: FinalMileBatchParcel(
              itemCount: i == 1 ? 3 : 1,
              price: i == 1 ? '1250.00' : '499.50',
              currency: 'PHP',
            ),
            destination: FinalMileBatchDestination(
              cityMunicipality: i == 1 ? 'Makati City' : 'Pasig City',
              province: 'Metro Manila',
            ),
          ),
    ],
  );
}

class WidgetParcelRepository extends ScheduleFilterRepository {
  WidgetParcelRepository(this.batch);
  final WidgetBatchRepository batch;
  Object? error;
  Completer<PickupTask>? pending;
  final accepted = <String>[],
      rejected = <String>[],
      keys = <String>[],
      reasons = <String>[];
  @override
  Future<PickupTask> acceptFinalMileTask(String taskId) async {
    accepted.add(taskId);
    if (error != null) throw error!;
    if (pending != null) return pending!.future;
    batch.acceptedIds.add(taskId);
    return PickupTask(
      id: taskId,
      leg: PickupTaskLeg.finalMile,
      rawStatus: 'delivery_accepted',
      revision: 2,
    );
  }

  @override
  Future<FinalMileRejectionResult> rejectFinalMileTask({
    required String taskId,
    required String reason,
    required String idempotencyKey,
  }) async {
    rejected.add(taskId);
    keys.add(idempotencyKey);
    reasons.add(reason);
    if (error != null) throw error!;
    batch.rejectedIds.add(taskId);
    return FinalMileRejectionResult(
      taskId: taskId,
      status: 'rejected',
      rejectionReason: reason,
    );
  }
}

AuthController batchAuthController() {
  return AuthController(
    authRepository: _WidgetAuthRepository(),
    dashboardRepository: _WidgetDashboardRepository(),
  );
}

class _WidgetAuthRepository implements AuthRepository {
  @override
  Future<bool> hasStoredToken() async => false;

  @override
  Future<List<LogisticsOption>> fetchLogisticsOptions({String? search}) async =>
      const <LogisticsOption>[];

  @override
  Future<RegistrationResult> register(
    CourierRegistrationRequest request, {
    void Function(void Function() cancel)? onCancel,
  }) async => throw UnimplementedError();

  @override
  Future<CourierIdentity> login({
    required String email,
    required String password,
    required String deviceName,
  }) async => throw UnimplementedError();

  @override
  Future<CourierIdentity> currentCourier() async => throw UnimplementedError();

  @override
  Future<void> logout() async {}

  @override
  Future<void> clearStoredToken() async {}
}

class _WidgetDashboardRepository implements DashboardRepository {
  @override
  Future<DashboardSnapshot> fetchDashboard() async {
    return const DashboardSnapshot(
      sections: <String, DashboardSection>{},
      freshness: DashboardFreshness(state: DashboardFreshnessState.scaffold),
    );
  }
}
