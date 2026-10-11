import 'dart:async';

import 'package:aisley_app/features/auth/data/auth_repository.dart';
import 'package:aisley_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aisley_app/features/dashboard/data/dashboard_repository.dart';
import 'package:aisley_app/features/delivery/domain/delivery_proof_photo.dart';
import 'package:aisley_app/features/history/data/history_repository.dart';
import 'package:aisley_app/features/history/domain/history_models.dart';

class HistorySearchRepository implements HistoryRepository {
  final references = <String?>[];
  final limits = <int>[];
  Object? error;
  Object? detailError;
  Future<DeliveryHistoryPage> Function(String?)? handler;
  DeliveryHistoryPage page = historyPage();

  @override
  Future<DeliveryHistoryPage> fetchHistory({
    String? reference,
    int limit = 20,
  }) async {
    references.add(reference);
    limits.add(limit);
    if (handler != null) return handler!(reference);
    if (error != null) throw error!;
    return page;
  }

  @override
  Future<DeliveryHistoryItem> fetchDetail(String taskId) async {
    if (detailError != null) throw detailError!;
    return historyItem(
      taskId.startsWith('task-') ? taskId.substring(5) : 'ORDER-EXAMPLE',
    );
  }

  @override
  Future<DeliveryProofPhoto> fetchProofPhoto(String proofId) =>
      throw UnimplementedError();
}

DeliveryHistoryItem historyItem([String reference = 'ORDER-EXAMPLE']) =>
    DeliveryHistoryItem.fromJson({
      'task_id': 'task-$reference',
      'leg': 'final_mile',
      'status': 'delivered',
      'delivered_at': '2026-09-11T08:00:00Z',
      'order': {'id': 'order-1', 'reference': reference, 'status': 'delivered'},
    });

DeliveryHistoryPage historyPage([String reference = 'ORDER-EXAMPLE']) =>
    DeliveryHistoryPage(items: [historyItem(reference)]);

AuthController historyAuth({void Function()? onSessionEnded}) => AuthController(
  authRepository: HistoryAuthRepository(),
  dashboardRepository: _UnusedDashboardRepository(),
  onSessionEnded: onSessionEnded,
)..status = AuthStatus.authenticated;

class HistoryAuthRepository implements AuthRepository {
  int tokenClears = 0;

  @override
  Future<void> logout() async {}

  @override
  Future<void> clearStoredToken() async {
    tokenClears++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _UnusedDashboardRepository implements DashboardRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
