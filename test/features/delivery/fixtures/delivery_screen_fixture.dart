import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aisley_app/core/networking/api_client.dart';
import 'package:aisley_app/features/auth/data/auth_repository.dart';
import 'package:aisley_app/features/auth/domain/auth_models.dart';
import 'package:aisley_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aisley_app/features/dashboard/data/dashboard_repository.dart';
import 'package:aisley_app/features/dashboard/domain/dashboard_models.dart';
import 'package:aisley_app/features/delivery/data/delivery_repository.dart';
import 'package:aisley_app/features/delivery/domain/delivery_models.dart';
import 'package:aisley_app/features/delivery/domain/delivery_proof_photo.dart';
import 'package:aisley_app/features/delivery/presentation/photo_capture/delivery_photo_capture.dart';
import 'package:aisley_app/features/delivery/presentation/photo_capture/delivery_photo_capture_result.dart';
import 'package:aisley_app/features/pickup/domain/pickup_models.dart';

AuthController deliveryAuthController() {
  final controller = AuthController(
    authRepository: _WidgetAuthRepository(),
    dashboardRepository: _WidgetDashboardRepository(),
  );
  controller.status = AuthStatus.authenticated;
  controller.courier = CourierIdentity.fromJson(const <String, dynamic>{
    'id': 'courier-1',
    'email': 'courier@example.com',
    'role': 'courier',
    'status': 'active',
    'profile': <String, dynamic>{'first_name': 'Ana', 'last_name': 'Santos'},
    'logistics': <String, dynamic>{
      'status': 'approved',
      'organization': 'Aisley Express',
      'hub': 'Makati Hub',
    },
  });
  return controller;
}

class WidgetDeliveryRepository implements DeliveryRepository {
  int deliveryReads = 0;
  String? completionEvidenceId;
  bool? codCollected;
  DeliveryPhotoSelection? uploadedPhoto;
  ApiException? proofError;
  DeliveryContext deliveryContext = const DeliveryContext(
    taskId: 'delivery-task-1',
    status: 'out_for_delivery',
    revision: 7,
    hub: PickupLocation(name: 'Makati Hub'),
    destination: PickupLocation(
      cityMunicipality: 'Pasig',
      province: 'Metro Manila',
    ),
    paymentMethod: 'cod',
    paymentStatus: 'pending',
    payableTotal: '115.00',
    currency: 'PHP',
  );

  @override
  Future<List<PickupTask>> fetchFinalMileTasks() async {
    return <PickupTask>[outForDeliveryTask];
  }

  @override
  Future<PickupTask> fetchFinalMileTask(String taskId) async {
    return outForDeliveryTask;
  }

  @override
  Future<DeliveryContext> fetchDeliveryContext(String taskId) async {
    deliveryReads++;
    return deliveryContext;
  }

  @override
  Future<DeliveryStatusUpdate> advanceStatus({
    required String taskId,
    required String status,
    required int expectedRevision,
    required String idempotencyKey,
  }) async {
    return DeliveryStatusUpdate(
      taskId: taskId,
      status: status,
      revision: expectedRevision + 1,
    );
  }

  @override
  Future<ProofSubmission> submitProof({
    required String taskId,
    required DeliveryPhotoSelection photo,
    required int expectedRevision,
    required String idempotencyKey,
    void Function(void Function() cancel)? onCancel,
  }) async {
    if (proofError != null) throw proofError!;
    uploadedPhoto = photo;
    return const ProofSubmission(
      taskId: 'delivery-task-1',
      proofId: 'proof-1',
      evidenceStatus: 'awaiting_validation',
      custodyState: 'out_for_delivery',
      completionEligible: false,
    );
  }

  @override
  Future<CompletionProjection> fetchCompletion(String taskId) async {
    final hasEvidence = uploadedPhoto != null;
    return CompletionProjection(
      taskId: 'delivery-task-1',
      taskStatus: 'out_for_delivery',
      completionStatus: completionEvidenceId == null
          ? null
          : 'awaiting_validation',
      evidenceStatus: hasEvidence ? 'awaiting_validation' : null,
      evidenceId: hasEvidence ? 'proof-1' : null,
      revision: 7,
    );
  }

  @override
  Future<DeliveryProofPhoto> fetchProofPhoto(String proofId) async {
    return DeliveryProofPhoto(
      bytes: base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9AAAAAElFTkSuQmCC',
      ),
      contentType: 'image/png',
    );
  }

  @override
  Future<CompletionProjection> submitCompletion({
    required String taskId,
    required int expectedRevision,
    required String evidenceId,
    required String idempotencyKey,
    required bool codCollected,
  }) async {
    completionEvidenceId = evidenceId;
    this.codCollected = codCollected;
    return const CompletionProjection(
      taskId: 'delivery-task-1',
      intentId: 'intent-1',
      taskStatus: 'out_for_delivery',
      completionStatus: 'awaiting_validation',
      evidenceStatus: 'awaiting_validation',
      evidenceId: 'proof-1',
      revision: 7,
    );
  }
}

class WidgetPhotoCaptureLauncher implements DeliveryPhotoCaptureLauncher {
  WidgetPhotoCaptureLauncher({required this.result, this.supported = true});

  final DeliveryPhotoCaptureResult result;
  final bool supported;
  int captureCalls = 0;

  @override
  bool get isSupported => supported;

  @override
  Future<DeliveryPhotoCaptureResult> capture(BuildContext context) async {
    captureCalls++;
    return result;
  }
}

class _WidgetAuthRepository implements AuthRepository {
  @override
  Future<bool> hasStoredToken() async => false;

  @override
  Future<List<LogisticsOption>> fetchLogisticsOptions({String? search}) async {
    return const <LogisticsOption>[];
  }

  @override
  Future<RegistrationResult> register(
    CourierRegistrationRequest request, {
    void Function(void Function() cancel)? onCancel,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<CourierIdentity> login({
    required String email,
    required String password,
    required String deviceName,
  }) async {
    throw UnimplementedError();
  }

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

const outForDeliveryTask = PickupTask(
  id: 'delivery-task-1',
  leg: PickupTaskLeg.finalMile,
  rawStatus: 'out_for_delivery',
  revision: 7,
  order: PickupOrderReference(reference: 'ORD-100'),
  waybill: PickupWaybillReference(reference: 'WB-100'),
  destinationArea: PickupLocation(
    cityMunicipality: 'Pasig',
    province: 'Metro Manila',
  ),
);
