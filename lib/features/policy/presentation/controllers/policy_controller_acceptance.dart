part of 'policy_controller.dart';

extension PolicyControllerAcceptance on PolicyController {
  Future<bool> acceptTogether(Map<PolicyType, int> confirmedVersions) async {
    if (_batchInFlight ||
        isBusy ||
        (state == PolicyViewState.rateLimited && !canRetryRateLimit)) {
      return false;
    }
    final selected = <PolicyType, int>{};
    for (final item in consentStatus?.policies ?? <PolicyConsentItem>[]) {
      if (!item.required) continue;
      final type = item.type;
      if (type == null ||
          item.currentVersion == null ||
          confirmedVersions[type] != item.currentVersion ||
          documentFor(type)?.version.version != item.currentVersion ||
          isDocumentStale(type)) {
        return false;
      }
      selected[type] = item.currentVersion!;
    }
    if (selected.isEmpty) return false;
    _batchInFlight = true;
    try {
      if (!await load(forceRefresh: true)) return false;
      if (consentStatus?.allRequiredAccepted == true) return true;
      for (final item in consentStatus!.policies.where(
        (item) => item.required,
      )) {
        if (item.type == null ||
            selected[item.type] != item.currentVersion ||
            documentFor(item.type!)?.version.version != item.currentVersion ||
            isDocumentStale(item.type!)) {
          return await _setStaleState();
        }
      }
      final operation = _operationEpoch;
      state = PolicyViewState.accepting;
      _notifyPolicyListeners();
      try {
        final result = await policyApi.acceptTogether(selected);
        if (operation != _operationEpoch) return false;
        consentStatus = result.status;
        _statusLoadedAt = DateTime.now();
        lastAcceptance = result.acceptances.last;
        state = PolicyViewState.accepted;
        successMessage = 'Your policy acceptance has been saved.';
        errorMessage = null;
        _notifyPolicyListeners();
        return true;
      } on Object catch (error) {
        if (operation != _operationEpoch) return false;
        if (error is ApiException && error.statusCode == 409) {
          return await _refreshAsStale();
        }
        if (error is ApiException &&
            (error.isNetworkError || (error.statusCode ?? 0) >= 500)) {
          final refreshed = await load(forceRefresh: true);
          if (refreshed &&
              selected.entries.every(
                (entry) =>
                    consentFor(entry.key)?.accepted == true &&
                    consentFor(entry.key)?.acceptedVersion == entry.value,
              )) {
            state = PolicyViewState.accepted;
            successMessage = 'Your policy acceptance has been saved.';
            errorMessage = null;
            _notifyPolicyListeners();
            return true;
          }
          if (state == PolicyViewState.signedOut ||
              state == PolicyViewState.unauthorized ||
              state == PolicyViewState.forbidden) {
            return false;
          }
        }
        await _setFailure(error);
        return false;
      }
    } finally {
      _batchInFlight = false;
    }
  }

  Future<bool> accept(PolicyType type) async {
    if (state == PolicyViewState.accepting) {
      return false;
    }
    final item = consentFor(type);
    final document = documentFor(type);
    final expectedVersion = item?.currentVersion;
    if (item == null || !item.required || expectedVersion == null) {
      state = PolicyViewState.validationError;
      errorMessage = 'This policy is not currently available for acceptance.';
      successMessage = null;
      _notifyPolicyListeners();
      return false;
    }
    if (document == null || document.version.version != expectedVersion) {
      return await _refreshAsStale();
    }

    final originalVersion = expectedVersion;
    final loaded = await load(forceRefresh: true);
    if (!loaded) {
      return false;
    }

    final refreshedItem = consentFor(type);
    final refreshedDocument = documentFor(type);
    if (refreshedItem?.currentVersion != originalVersion ||
        refreshedDocument?.version.version != originalVersion) {
      return await _setStaleState();
    }

    state = PolicyViewState.accepting;
    errorMessage = null;
    successMessage = null;
    retryAfter = null;
    _notifyPolicyListeners();

    try {
      final acceptance = await policyApi.accept(
        type: type,
        version: originalVersion,
      );
      if (acceptance.type != type ||
          acceptance.version.version != originalVersion) {
        throw const ApiContractException('policy.acceptance.version');
      }
      lastAcceptance = acceptance;
      final refreshed = await load(forceRefresh: true);
      final message =
          '${acceptance.label} version ${acceptance.version.version} was accepted.';
      if (refreshed) {
        state = PolicyViewState.accepted;
        successMessage = message;
        errorMessage = null;
        _notifyPolicyListeners();
      } else if (state != PolicyViewState.unauthorized &&
          state != PolicyViewState.forbidden) {
        state = PolicyViewState.accepted;
        successMessage = message;
        errorMessage =
            'Acceptance was committed, but status refresh is unavailable.';
        _notifyPolicyListeners();
      }
      return true;
    } on ApiException catch (error) {
      if (error.statusCode == 409 && error.code == 'POLICY_VERSION_STALE') {
        return await _refreshAsStale();
      }
      if (error.isNetworkError) {
        return _reconcileUnknownAcceptance(type, originalVersion, error);
      }
      await _setFailure(error);
    } on Object catch (error) {
      await _setFailure(error);
    }
    return false;
  }
}
