import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_contract_exception.dart';
import '../../../core/security/token_storage.dart';
import '../data/delivery_route_repository.dart';
import '../domain/delivery_route_models.dart';

enum DeliveryRouteLoadStatus {
  idle,
  loading,
  loaded,
  unavailable,
  offline,
  timeout,
  unauthorized,
  forbidden,
  consentRequired,
  conflict,
  invalid,
  rateLimited,
  storageFailure,
  failed,
}

class DeliveryRouteController extends ChangeNotifier {
  DeliveryRouteController({required this.repository, this.onAuthFailure});
  final DeliveryRouteRepository repository;
  final Future<void> Function(ApiException)? onAuthFailure;
  DeliveryRouteLoadStatus status = DeliveryRouteLoadStatus.idle;
  DeliveryRoute? route;
  DateTime? lastRefreshed;
  String? message;
  String? scheduleId;
  bool mapFailed = false;
  int mapVersion = 0;
  int _request = 0;
  bool _disposed = false;
  Timer? _retryTimer;
  DateTime? _retryUntil;
  bool get canRetry =>
      !_disposed &&
      _retryTimer == null &&
      status != DeliveryRouteLoadStatus.loading;

  Future<void> load(String id, {bool refresh = false}) async {
    if (_disposed ||
        _retryTimer != null ||
        (!refresh &&
            status == DeliveryRouteLoadStatus.loading &&
            id == scheduleId)) {
      return;
    }
    final request = ++_request;
    if (id != scheduleId) {
      route = null;
      lastRefreshed = null;
    }
    scheduleId = id;
    status = DeliveryRouteLoadStatus.loading;
    message = null;
    _notify();
    try {
      final result = await repository.fetchRoute(id);
      if (!_current(request)) return;
      route = result;
      lastRefreshed = DateTime.now().toUtc();
      status = DeliveryRouteLoadStatus.loaded;
    } on ApiException catch (error) {
      if (!_current(request)) return;
      status = switch (error.statusCode) {
        401 => DeliveryRouteLoadStatus.unauthorized,
        403 =>
          error.code == 'POLICY_CONSENT_REQUIRED'
              ? DeliveryRouteLoadStatus.consentRequired
              : DeliveryRouteLoadStatus.forbidden,
        404 => DeliveryRouteLoadStatus.unavailable,
        409 => DeliveryRouteLoadStatus.conflict,
        422 => DeliveryRouteLoadStatus.invalid,
        429 => DeliveryRouteLoadStatus.rateLimited,
        null =>
          error.networkFailure == ApiNetworkFailure.timeout
              ? DeliveryRouteLoadStatus.timeout
              : DeliveryRouteLoadStatus.offline,
        _ => DeliveryRouteLoadStatus.failed,
      };
      message = switch (status) {
        DeliveryRouteLoadStatus.unauthorized =>
          'Your Courier session is no longer valid.',
        DeliveryRouteLoadStatus.consentRequired =>
          'Accept the current policies to view this route.',
        DeliveryRouteLoadStatus.forbidden =>
          'This route is not available to your Courier account.',
        DeliveryRouteLoadStatus.unavailable =>
          'This delivery route is no longer available.',
        DeliveryRouteLoadStatus.conflict =>
          'This batch changed. Refresh its details before viewing the route.',
        DeliveryRouteLoadStatus.invalid =>
          'The route request could not be accepted. Refresh batch details.',
        DeliveryRouteLoadStatus.rateLimited =>
          'Too many requests. Wait before retrying.',
        DeliveryRouteLoadStatus.timeout =>
          'The route request timed out. Retry when ready.',
        DeliveryRouteLoadStatus.offline =>
          'You are offline. Reconnect and retry.',
        _ => 'The delivery route could not be loaded. Please retry.',
      };
      if ({401, 403, 404, 409, 422}.contains(error.statusCode)) {
        route = null;
        lastRefreshed = null;
      }
      if (error.statusCode == 429) {
        _holdRetry(error.retryAfter);
      }
      if (error.statusCode == 401 || error.statusCode == 403) {
        await onAuthFailure?.call(error);
      }
    } on TokenStorageException {
      if (!_current(request)) return;
      route = null;
      lastRefreshed = null;
      status = DeliveryRouteLoadStatus.storageFailure;
      message =
          'Secure session storage is unavailable. The route cannot be loaded.';
    } on ApiContractException {
      if (!_current(request)) return;
      status = DeliveryRouteLoadStatus.failed;
      message =
          'The route service returned an unexpected response. Please retry.';
    }
    if (_current(request)) _notify();
  }

  /// Stop tile work, then re-read through the ordinary authenticated API.
  /// Tile/provider failure alone is never interpreted as account revocation.
  Future<void> mapFailure(String id, {ApiException? error}) async {
    if (_disposed || scheduleId != id) return;
    mapFailed = true;
    _notify();
    await load(id, refresh: true);
    if (!_disposed && scheduleId == id && error?.statusCode == 429) {
      _holdRetry(error!.retryAfter);
      message = 'Map requests are temporarily limited. Wait before refreshing.';
      _notify();
    }
  }

  Future<void> retry(String id) async {
    if (!canRetry) return;
    mapFailed = false;
    mapVersion++;
    await load(id, refresh: true);
  }

  void clear() {
    _request++;
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryUntil = null;
    route = null;
    scheduleId = null;
    lastRefreshed = null;
    message = null;
    status = DeliveryRouteLoadStatus.idle;
    mapFailed = false;
    mapVersion++;
    _notify();
  }

  bool _current(int id) => !_disposed && id == _request;
  void _holdRetry(Duration? delay) {
    final requested = delay ?? const Duration(seconds: 30);
    final bounded = requested.isNegative ? Duration.zero : requested;
    final until = DateTime.now().add(bounded);
    if (_retryUntil != null && !until.isAfter(_retryUntil!)) return;
    _retryUntil = until;
    _retryTimer?.cancel();
    _retryTimer = Timer(bounded, () {
      _retryTimer = null;
      _retryUntil = null;
      _notify();
    });
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    clear();
    _disposed = true;
    super.dispose();
  }
}
