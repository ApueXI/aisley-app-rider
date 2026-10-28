part of '../delivery_screen.dart';

mixin _DeliveryPhotoSelection on State<DeliveryTaskScreen> {
  DeliveryPhotoSelection? _selectedPhoto;
  String? _photoSelectionError;
  bool _isPickingPhoto = false;
  void Function()? _cancelPhotoUpload;
  DeliveryCodCollection? _acknowledgedCollection;
  String? _acknowledgedTaskId;
  (String, String?, String?, String?, String?, String?, int?)?
  _paymentProjectionSignature;

  void initializeCashAcknowledgment() {
    widget.deliveryController.addListener(_handlePaymentProjectionChange);
  }

  void disposeCashAcknowledgment() {
    widget.deliveryController.removeListener(_handlePaymentProjectionChange);
  }

  void replaceCashAcknowledgmentController(
    DeliveryController previousController,
  ) {
    previousController.removeListener(_handlePaymentProjectionChange);
    widget.deliveryController.addListener(_handlePaymentProjectionChange);
    _paymentProjectionSignature = null;
    _clearCashAcknowledgment();
  }

  void updateCashAcknowledgmentTask(String previousId, String currentId) {
    if (previousId == currentId) return;
    _paymentProjectionSignature = null;
    _clearCashAcknowledgment();
  }

  void clearCashAcknowledgment() => _clearCashAcknowledgment();

  void _handlePaymentProjectionChange() {
    final contextData = widget.deliveryController.contexts[widget.task.id];
    final next = (
      widget.task.id,
      contextData?.paymentMethod,
      contextData?.paymentStatus,
      contextData?.payableTotal,
      contextData?.currency,
      contextData?.status,
      contextData?.revision,
    );
    final previous = _paymentProjectionSignature;
    _paymentProjectionSignature = next;
    if (previous != null &&
        previous != next &&
        _acknowledgedCollection != null) {
      setState(_clearCashAcknowledgment);
    }
  }

  void _clearCashAcknowledgment() {
    _acknowledgedCollection = null;
    _acknowledgedTaskId = null;
  }

  bool cashAcknowledgmentMatches(
    PickupTask task,
    DeliveryContext? contextData,
  ) {
    final current = contextData?.codCollection;
    return current != null &&
        _acknowledgedTaskId == task.id &&
        _acknowledgedCollection?.matches(current) == true;
  }

  bool paymentIsKnown(DeliveryContext? contextData) {
    if (contextData == null) return false;
    if (contextData.paymentMethod == 'cod') {
      return contextData.codCollection != null;
    }
    return contextData.paymentMethod == 'prepaid' &&
        contextData.paymentStatus == 'paid';
  }

  void setCashAcknowledgement(
    PickupTask task,
    DeliveryCodCollection collection,
    bool acknowledged,
  ) {
    setState(() {
      if (acknowledged) {
        _acknowledgedTaskId = task.id;
        _acknowledgedCollection = collection;
      } else {
        _clearCashAcknowledgment();
      }
    });
  }

  Future<void> _capturePhoto() async {
    if (_isPickingPhoto) return;
    setState(() {
      _isPickingPhoto = true;
      _photoSelectionError = null;
    });
    try {
      final result = await widget.photoCaptureLauncher.capture(context);
      if (!mounted) return;
      if (result.status == DeliveryPhotoCaptureStatus.chooseFile) {
        setState(() => _isPickingPhoto = false);
        await _pickPhoto();
        return;
      }
      final file = result.file;
      if (result.status == DeliveryPhotoCaptureStatus.captured &&
          file != null) {
        final selection = await loadDeliveryPhotoSelection(
          file,
          captured: true,
        );
        if (!mounted) return;
        setState(() => _selectedPhoto = selection);
        return;
      }
      setState(() => _photoSelectionError = _captureMessage(result.status));
    } on FormatException catch (error) {
      if (mounted) setState(() => _photoSelectionError = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _photoSelectionError = 'The captured photo could not be opened. Retake it or choose a photo file.',
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingPhoto = false);
    }
  }

  Future<void> _pickPhoto() async {
    if (_isPickingPhoto) return;
    setState(() {
      _isPickingPhoto = true;
      _photoSelectionError = null;
    });
    try {
      final file = await openFile(
        acceptedTypeGroups: const <XTypeGroup>[_deliveryPhotoTypeGroup],
      );
      if (file == null) {
        setState(
          () => _photoSelectionError = 'Photo selection was cancelled. Choose a photo when you are ready.',
        );
        return;
      }
      final selection = await loadDeliveryPhotoSelection(file, captured: false);
      if (!mounted) return;
      setState(() => _selectedPhoto = selection);
    } on FormatException catch (error) {
      if (mounted) setState(() => _photoSelectionError = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _photoSelectionError =
              'The photo could not be opened. Choose it again and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingPhoto = false);
    }
  }

  Future<void> _confirmDelivered(PickupTask task) async {
    final controller = widget.deliveryController;
    final payment = await controller.prepareDeliveryPayment(task);
    if (!mounted || payment == null) return;

    if (payment.isCod &&
        !cashAcknowledgmentMatches(task, controller.contexts[task.id])) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cash due changed. Review the current amount and confirm collection again.',
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('Confirm delivery'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (payment.isCod)
              Text('Cash collection acknowledged: ${payment.displayAmount}.')
            else
              const Text('This Order is prepaid and paid.'),
            const Text(
              'Submit the photo and Delivered request for Logistics validation.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delivered'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await controller.submitDelivered(
      task,
      photo: _selectedPhoto,
      confirmedCollection: payment,
      onCancel: (cancel) {
        if (mounted) setState(() => _cancelPhotoUpload = cancel);
      },
    );
    if (!mounted) return;
    setState(() {
      _cancelPhotoUpload = null;
      if (!controller.hasPendingProof(task) &&
          controller.proofs[task.id] != null) {
        _selectedPhoto = null;
      }
      if (controller.isCompletionPending(task) ||
          controller.completions[task.id]?.isDelivered == true) {
        _clearCashAcknowledgment();
      }
    });
  }
}

String _captureMessage(DeliveryPhotoCaptureStatus status) => switch (status) {
  DeliveryPhotoCaptureStatus.cancelled => 'Camera capture was cancelled. Open the camera again or choose a photo file.',
  DeliveryPhotoCaptureStatus.chooseFile =>
    'Choose a JPEG, PNG, or WebP photo under 10 MiB.',
  DeliveryPhotoCaptureStatus.permissionDenied => 'Camera permission was denied. Allow it in Android settings, then retry, or choose a photo file.',
  DeliveryPhotoCaptureStatus.unavailable =>
    'A rear camera is unavailable. Choose a photo file instead.',
  DeliveryPhotoCaptureStatus.busy =>
    'The camera is busy. Wait a moment and retry, or choose a photo file.',
  DeliveryPhotoCaptureStatus.failed =>
    'The photo was not captured. Retake it or choose a photo file.',
  DeliveryPhotoCaptureStatus.captured =>
    'The captured photo could not be opened. Retake it or choose a photo file.',
};
