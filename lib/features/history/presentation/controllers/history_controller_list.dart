part of 'history_controller.dart';

extension HistoryControllerList on HistoryController {
  Future<void> search(String reference) async {
    if (!canSearch) return;
    final trimmed = reference.trim();
    final selected = trimmed.isEmpty ? null : trimmed;
    if (_activeReference != selected) {
      _listEpoch++;
      _activeReference = selected;
      _resetList();
      status = HistoryLoadStatus.idle;
    }
    await load();
  }

  Future<void> clearSearch() async {
    if (_disposed) return;
    _listEpoch++;
    _activeReference = null;
    _resetList();
    // Local clearing must preserve access gates even during a cooldown.
    if (_isAccessBlocked || status == HistoryLoadStatus.consentRequired) {
      _notifyHistoryListeners();
      return;
    }
    if (!canRetryRateLimit) {
      status = HistoryLoadStatus.rateLimited;
      errorMessage = 'Too many requests. Wait before trying again.';
      _notifyHistoryListeners();
      return;
    }
    status = HistoryLoadStatus.idle;
    await load();
  }

  Future<void> load() async {
    if (_disposed ||
        !canRetryRateLimit ||
        status == HistoryLoadStatus.loading ||
        _isAccessBlocked) {
      return;
    }
    final epoch = ++_listEpoch;
    _authFailureNotified = false;
    status = HistoryLoadStatus.loading;
    errorMessage = null;
    retryAfter = null;
    _notifyHistoryListeners();
    try {
      final page = await historyRepository.fetchHistory(
        reference: _activeReference,
        limit: 20,
      );
      if (epoch != _listEpoch) return;
      items = List<DeliveryHistoryItem>.unmodifiable(page.items);
      hasMore = page.hasMore;
      nextCursor = page.nextCursor;
      status = page.items.isEmpty
          ? HistoryLoadStatus.empty
          : HistoryLoadStatus.loaded;
      _notifyHistoryListeners();
    } on ApiException catch (error) {
      if (epoch != _listEpoch) return;
      await _setListError(error);
    } on TokenStorageException {
      if (epoch != _listEpoch) return;
      _clearAccountHistory();
      status = HistoryLoadStatus.secureStorageFailure;
      errorMessage = 'Secure session storage is unavailable. Delivery history cannot be loaded.';
      _notifyHistoryListeners();
    } on ApiContractException {
      if (epoch != _listEpoch) return;
      status = HistoryLoadStatus.failed;
      errorMessage =
          'The delivery history response was not understood. Please retry.';
      _notifyHistoryListeners();
    }
  }
}
