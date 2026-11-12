part of '../pickup_screen.dart';

extension _PickupTaskInteractions on _PickupTaskDetailScreenState {
  Future<void> _openScanner() async {
    final candidate = await Navigator.of(_pickupContext)
        .push<BarcodeScanCandidate>(
          MaterialPageRoute<BarcodeScanCandidate>(
            builder: (_) => const BarcodeScannerScreen(),
          ),
        );
    if (candidate == null || !_pickupMounted) {
      return;
    }
    _pickupSetState(() {
      _scanCandidate = candidate;
    });
  }

  Future<void> _confirmAcceptTask(PickupTask task) async {
    final shouldAccept = await showDialog<bool>(
      context: _pickupContext,
      builder: (context) {
        return AlertDialog(
          title: const Text('Accept this task?'),
          content: Text(
            'Accepting confirms responsibility for this ${task.isFirstMile ? 'Seller pickup' : 'hub delivery'}. It does not record physical pickup.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Accept task'),
            ),
          ],
        );
      },
    );
    if (shouldAccept != true || !_pickupMounted) {
      return;
    }
    await _pickupController.acceptTask(task);
    await _closeIfSessionEnded();
  }

  Future<void> _confirmRejectTask(PickupTask task) async {
    final reasonController = TextEditingController();
    try {
      final reason = await showDialog<String>(
        context: _pickupContext,
        builder: (context) {
          return AlertDialog(
            title: const Text('Reject this offer?'),
            content: TextField(
              controller: reasonController,
              autofocus: true,
              minLines: 2,
              maxLines: 5,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'Why can’t you take this task?',
                helperText: 'Enter at least 3 characters.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final value = reasonController.text.trim();
                  if (value.length < 3 || value.length > 1000) {
                    return;
                  }
                  Navigator.of(context).pop(value);
                },
                child: const Text('Reject offer'),
              ),
            ],
          );
        },
      );
      if (reason == null || !_pickupMounted) {
        return;
      }
      await _pickupController.rejectFinalMileTask(task, reason: reason);
      await _closeIfSessionEnded();
    } finally {
      reasonController.dispose();
    }
  }

  Future<void> _submitPickup(PickupTask task) async {
    if (!task.isFirstMile) {
      return;
    }
    final identifier = _scanCandidate?.value.trim() ?? '';
    if (identifier.isEmpty || identifier.length > 128) {
      return;
    }

    await _pickupController.confirmFirstMilePickup(
      task,
      identifierType: _scanCandidate!.identifierType,
      identifier: identifier,
    );
    await _closeIfSessionEnded();
  }

  Future<void> _retryPickup(PickupTask task) async {
    if (task.isFirstMile) {
      await _pickupController.retryFirstMilePickup(task);
    } else {
      await _pickupController.retryFinalMilePickup(task);
    }
    await _closeIfSessionEnded();
  }

  Future<void> _retryRejection(PickupTask task) async {
    await _pickupController.retryFinalMileRejection(task);
    await _closeIfSessionEnded();
  }

  Future<void> _openPolicies() async {
    final policyController = _policyController;
    if (policyController == null || !_pickupMounted) {
      return;
    }
    await Navigator.of(_pickupContext).push(
      MaterialPageRoute<void>(
        builder: (_) => PolicyScreen(
          authController: _authController,
          policyController: policyController,
        ),
      ),
    );
    if (_pickupMounted) {
      await _pickupController.load();
    }
  }

  Future<void> _closeIfSessionEnded() async {
    if (!_pickupMounted || _authController.status == AuthStatus.authenticated) {
      return;
    }
    if (Navigator.of(_pickupContext).canPop()) {
      Navigator.of(_pickupContext).pop();
    }
  }
}
