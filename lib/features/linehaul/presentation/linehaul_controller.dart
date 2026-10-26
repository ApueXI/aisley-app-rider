import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_contract_exception.dart';
import '../../../core/security/token_storage.dart';
import '../data/linehaul_repository.dart';
import '../domain/linehaul_trip.dart';
import '../domain/linehaul_route.dart';

class LinehaulController extends ChangeNotifier {
  LinehaulController(this.repository, {this.onAuthFailure});
  final LinehaulRepository repository;
  final Future<void> Function(ApiException)? onAuthFailure;
  List<LinehaulTrip> trips = const [];
  String? selectedId, error, routeError;
  LinehaulRoute? route;
  bool loading = false, routeLoading = false, saving = false;
  bool _disposed = false;
  int _epoch = 0, _routeEpoch = 0;
  Timer? _cooldown, _routeCooldown;
  bool get routeCoolingDown => _routeCooldown != null;
  int get routeVersion => _routeEpoch;
  ({String id, String action, int revision})? _pending;
  bool get coolingDown => _cooldown != null;
  bool get uncertain => _pending != null;
  bool get locked => saving || uncertain;
  LinehaulTrip? get selected {
    for (final trip in trips) {
      if (trip.id == selectedId) return trip;
    }
    return null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  bool _current(int epoch) => !_disposed && epoch == _epoch;

  Future<void> load() async {
    if (saving || loading || coolingDown || _disposed) return;
    final epoch = _epoch;
    loading = true;
    error = null;
    _notify();
    try {
      final result = await repository.trips();
      if (!_current(epoch)) return;
      trips = result;
      selectedId = result.any((t) => t.id == selectedId)
          ? selectedId
          : result.firstOrNull?.id;
      final attempt = _pending;
      if (attempt != null) {
        final matches = result.where((t) => t.id == attempt.id);
        if (matches.isEmpty) {
          _pending = null;
        } else if (attempt.action == 'depart'
            ? matches.single.departedAt != null
            : matches.single.courierArrivedAt != null) {
          _pending = null;
        }
      }
    } catch (e) {
      if (!_current(epoch)) return;
      trips = const [];
      route = null;
      await _error(e, epoch);
    } finally {
      if (_current(epoch)) {
        loading = false;
        _notify();
      }
    }
    if (_current(epoch) && selected != null) await loadRoute();
  }

  Future<void> select(String id) async {
    if (locked || loading || !trips.any((t) => t.id == id)) return;
    selectedId = id;
    route = null;
    routeError = null;
    _notify();
    await loadRoute();
  }

  Future<void> loadRoute() async {
    if (selected == null ||
        coolingDown ||
        routeCoolingDown ||
        saving ||
        _disposed) {
      return;
    }
    final id = selectedId!;
    final epoch = _epoch, routeEpoch = ++_routeEpoch;
    routeLoading = true;
    routeError = null;
    route = null;
    _notify();
    try {
      final result = await repository.route(id);
      if (_current(epoch) && routeEpoch == _routeEpoch && selectedId == id) {
        route = result;
      }
    } catch (e) {
      if (_current(epoch) && routeEpoch == _routeEpoch) {
        await _error(e, epoch, mapOnly: true);
      }
    } finally {
      if (_current(epoch) && routeEpoch == _routeEpoch) {
        routeLoading = false;
        _notify();
      }
    }
  }

  Future<bool> confirm(String action) async {
    final trip = selected;
    if (saving || loading || coolingDown || trip == null || _disposed) {
      return false;
    }
    if (_pending == null &&
        !(action == 'depart'
            ? trip.canDepart
            : action == 'arrival' && trip.canReportArrival)) {
      return false;
    }
    final attempt =
        _pending ?? (id: trip.id, action: action, revision: trip.revision);
    if (attempt.id != trip.id || attempt.action != action) return false;
    return _perform(attempt);
  }

  Future<bool> retry() async {
    final attempt = _pending;
    if (attempt == null || saving || loading || coolingDown || _disposed) {
      return false;
    }
    return _perform(attempt);
  }

  Future<bool> _perform(
    ({String id, String action, int revision}) attempt,
  ) async {
    final epoch = _epoch;
    saving = true;
    _pending = attempt;
    error = null;
    _notify();
    try {
      final result = await repository.confirm(
        attempt.id,
        attempt.action,
        attempt.revision,
      );
      if (!_current(epoch)) return false;
      if (result.id != attempt.id ||
          (attempt.action == 'depart'
              ? result.departedAt == null
              : result.courierArrivedAt == null)) {
        fail();
      }
      trips = List.unmodifiable(
        trips.map((t) => t.id == result.id ? result : t),
      );
      _pending = null;
      return true;
    } catch (e) {
      if (!_current(epoch)) return false;
      if (e is ApiException && const [404, 409, 422].contains(e.statusCode)) {
        _pending = null;
      }
      await _error(e, epoch);
      if (e is ApiException && e.statusCode == 409 && _current(epoch)) {
        saving = false;
        final message = error;
        await load();
        if (_current(epoch)) error = message;
      }
      return false;
    } finally {
      if (_current(epoch)) {
        saving = false;
        _notify();
      }
    }
  }

  Future<void> _error(Object e, int epoch, {bool mapOnly = false}) async {
    var message = mapOnly
        ? 'Route unavailable. Known trip details and driver actions remain available.'
        : uncertain
        ? 'Result unconfirmed. Retry the same action or refresh to check server state.'
        : 'Trips could not be loaded. Check your connection and retry.';
    if (e is ApiException) {
      message = switch (e.statusCode) {
        401 => 'Your session expired. Sign in again.',
        403 when e.code == 'POLICY_CONSENT_REQUIRED' =>
          'Review the current policies before continuing.',
        403 => 'Linehaul is unavailable to this account.',
        404 => 'This assigned trip is no longer available. Refresh your jobs.',
        409 when e.code == 'LINEHAUL_RELEASE_REQUIRED' =>
          'Origin Logistics must release this load before departure.',
        409 when e.code == 'LINEHAUL_RELEASE_INVALID' =>
          'Origin Logistics must renew the load release.',
        409 => 'This trip changed. Review the refreshed details before confirming again.',
        422 => 'The confirmation could not be accepted. Refresh and review the trip.',
        429 => 'Too many requests. Wait before retrying.',
        _ => message,
      };
      if (e.statusCode == 429 && mapOnly) {
        _routeCooldown?.cancel();
        _routeCooldown = Timer(e.retryAfter ?? const Duration(seconds: 30), () {
          _routeCooldown = null;
          _notify();
        });
      }
      if (e.statusCode == 429 && !mapOnly) {
        _cooldown?.cancel();
        _cooldown = Timer(e.retryAfter ?? const Duration(seconds: 30), () {
          _cooldown = null;
          _notify();
        });
      }
      if (const [401, 403, 404].contains(e.statusCode)) {
        route = null;
        trips = const [];
        if (e.code != 'POLICY_CONSENT_REQUIRED') _pending = null;
        if (e.statusCode != 404) await onAuthFailure?.call(e);
      }
    } else if (e is TokenStorageException) {
      message = 'Secure sign-in is unavailable. Reopen the app and retry.';
    } else if (e is ApiContractException && !uncertain) {
      message = 'The service returned unexpected details. Refresh and retry.';
    }
    if (_current(epoch)) {
      if (mapOnly) {
        routeError = message;
      } else {
        error = message;
      }
    }
  }

  void clear() {
    _epoch++;
    _routeEpoch++;
    trips = const [];
    selectedId = null;
    route = null;
    _pending = null;
    error = null;
    routeError = null;
    loading = false;
    routeLoading = false;
    saving = false;
    _cooldown?.cancel();
    _cooldown = null;
    _routeCooldown?.cancel();
    _routeCooldown = null;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    _routeEpoch++;
    _cooldown?.cancel();
    _routeCooldown?.cancel();
    super.dispose();
  }
}
