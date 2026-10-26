part of 'final_mile_batch_controller.dart';

extension ParcelDecisionController on FinalMileBatchController {
  bool hasPendingDecision(String id) => _pendingDecisions.containsKey(id);

  Future<bool> decideParcel(
    String scheduleId,
    String taskId, {
    String? reason,
  }) async {
    if (_disposed ||
        decidingTask != null ||
        parcelRepository == null ||
        !canRetryRateLimit) {
      return false;
    }
    final pending = _pendingDecisions[taskId];
    if (pending == null &&
        !(batchById(scheduleId)?.tasks.any(
              (t) => t.id == taskId && t.status == 'delivery_assigned',
            ) ??
            false)) {
      return false;
    }
    if (hasUncertainDecision && pending == null) return false;
    final normalized = reason?.trim();
    if (pending != null && pending.reason != normalized) return false;
    if (normalized != null &&
        (normalized.runes.length < 3 || normalized.runes.length > 1000)) {
      parcelErrors[taskId] = 'Enter a reason between 3 and 1,000 characters.';
      _notify();
      return false;
    }
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    final attempt =
        pending ??
        (
          reason: normalized,
          key:
              '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}',
        );
    _pendingDecisions[taskId] = attempt;
    return _performParcelDecision(scheduleId, taskId, attempt);
  }

  Future<bool> retryParcelDecision(String scheduleId, String taskId) =>
      decideParcel(
        scheduleId,
        taskId,
        reason: _pendingDecisions[taskId]?.reason,
      );

  Future<bool> _performParcelDecision(
    String scheduleId,
    String taskId,
    ({String? reason, String key}) attempt,
  ) async {
    final epoch = _epoch;
    decidingTask = taskId;
    parcelErrors.remove(taskId);
    _notify();
    try {
      if (attempt.reason == null) {
        final task = await parcelRepository!.acceptFinalMileTask(taskId);
        if (task.id != taskId ||
            !task.isFinalMile ||
            task.rawStatus != 'delivery_accepted') {
          throw const ApiContractException('parcel.accept.identity');
        }
      } else {
        final result = await parcelRepository!.rejectFinalMileTask(
          taskId: taskId,
          reason: attempt.reason!,
          idempotencyKey: attempt.key,
        );
        if (result.taskId != taskId || result.status != 'rejected') {
          throw const ApiContractException('parcel.reject.identity');
        }
      }
      if (_disposed || epoch != _epoch) return false;
      _pendingDecisions.remove(taskId);
      routeController?.clear();
      // Remove stale detail before refreshing membership (last rejection may remove the batch).
      _details.remove(scheduleId);
      batches = List.unmodifiable(batches.where((b) => b.id != scheduleId));
      try {
        await onBatchAccepted?.call();
      } catch (_) {
        /* The write remains committed. */
      }
      decidingTask = null;
      await load();
      return true;
    } on ApiException catch (error) {
      if (_disposed || epoch != _epoch) return false;
      if (const [404, 409, 422].contains(error.statusCode)) {
        _pendingDecisions.remove(taskId);
      }
      parcelErrors[taskId] = _isUncertain(error)
          ? 'Decision unconfirmed. Retry the same parcel decision when connected.'
          : _messageFor(error, noun: 'parcel');
      _handleRateLimit(error);
      if (error.statusCode == 401 ||
          error.statusCode == 403 ||
          error.statusCode == 404) {
        if (error.code != 'POLICY_CONSENT_REQUIRED') {
          _details.clear();
          batches = const [];
          _pendingDecisions.clear();
        }
        await onAuthFailure?.call(error);
      }
      if (error.statusCode == 409) {
        _details.remove(scheduleId);
        batches = List.unmodifiable(batches.where((b) => b.id != scheduleId));
      }
    } on TokenStorageException {
      if (!_disposed && epoch == _epoch) {
        parcelErrors[taskId] =
            'Secure sign-in is unavailable. Retry when restored.';
      }
    } on ApiContractException {
      if (!_disposed && epoch == _epoch) {
        parcelErrors[taskId] =
            'Decision unconfirmed. Retry the same parcel decision.';
      }
    } finally {
      if (!_disposed && epoch == _epoch) {
        decidingTask = null;
        _notify();
      }
    }
    return false;
  }
}
