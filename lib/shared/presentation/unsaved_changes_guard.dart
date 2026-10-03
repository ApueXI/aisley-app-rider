import 'package:flutter/material.dart';

/// Protects user-initiated exits while leaving session cleanup to the owner.
class UnsavedChangesGuard extends StatefulWidget {
  const UnsavedChangesGuard({
    required this.hasUnsavedChanges,
    required this.child,
    this.isBusy = false,
    this.onLeave,
    super.key,
  });

  final bool hasUnsavedChanges;
  final bool isBusy;
  final VoidCallback? onLeave;
  final Widget child;

  @override
  State<UnsavedChangesGuard> createState() => UnsavedChangesGuardState();
}

class UnsavedChangesGuardState extends State<UnsavedChangesGuard> {
  bool _allowPop = false;
  bool _isLeaving = false;
  DialogRoute<bool>? _discardDialog;

  Future<void> requestLeave() async {
    if (_isLeaving || widget.isBusy) return;
    _isLeaving = true;
    try {
      if (widget.hasUnsavedChanges) {
        final navigator = Navigator.of(context);
        final dialog = DialogRoute<bool>(
          context: context,
          builder: (context) => AlertDialog(
            scrollable: true,
            title: const Text('Discard unsaved changes?'),
            content: const Text(
              'Your unsaved entries and selected files will be lost.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Discard'),
              ),
              FilledButton(
                autofocus: true,
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Keep editing'),
              ),
            ],
          ),
        );
        _discardDialog = dialog;
        final discard = await navigator.push(dialog);
        _discardDialog = null;
        if (discard != true || !mounted || widget.isBusy) return;
      }
      if (!mounted) return;
      if (widget.onLeave case final onLeave?) {
        onLeave();
      } else {
        await leaveWithoutConfirmation();
      }
    } finally {
      _isLeaving = false;
    }
  }

  /// Authorization loss must dismiss any prompt and clear private drafts.
  Future<void> leaveWithoutConfirmation() async {
    final navigator = Navigator.of(context);
    final ownerRoute = ModalRoute.of(context);
    final dialog = _discardDialog;
    _discardDialog = null;
    if (dialog != null && dialog.isActive) navigator.removeRoute(dialog);
    if (!mounted) return;
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    navigator.popUntil((route) => route == ownerRoute || route.isFirst);
    if (ownerRoute?.isCurrent == true && navigator.canPop()) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop:
          _allowPop ||
          (widget.onLeave == null &&
              !widget.hasUnsavedChanges &&
              !widget.isBusy),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) requestLeave();
      },
      child: widget.child,
    );
  }
}
