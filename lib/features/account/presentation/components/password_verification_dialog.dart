import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/account_controller.dart';

class PasswordVerificationDialog extends StatefulWidget {
  const PasswordVerificationDialog({
    super.key,
    required this.controller,
    required this.onVerify,
    required this.onResend,
    this.hasUnsavedProfileChanges = false,
  });
  final AccountController controller;
  final Future<bool> Function(String code) onVerify;
  final Future<bool> Function() onResend;
  final bool hasUnsavedProfileChanges;
  @override
  State<PasswordVerificationDialog> createState() =>
      _PasswordVerificationDialogState();
}

class _PasswordVerificationDialogState
    extends State<PasswordVerificationDialog> {
  final _code = TextEditingController();
  Timer? _timer;
  String? _localError;
  String? _ownerId;
  @override
  void initState() {
    super.initState();
    _ownerId = widget.controller.account?.id;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    widget.controller.addListener(_onChanged);
  }

  void _onChanged() {
    if (!mounted) return;
    final c = widget.controller;
    if (c.status == AccountStatus.signedOut ||
        c.status == AccountStatus.forbidden ||
        c.account == null ||
        c.account?.id != _ownerId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller, challenge = c.passwordChallenge;
    final seconds = challenge?.resendSeconds ?? 0;
    return PopScope(
      canPop: !c.isBusy,
      child: AlertDialog(
        scrollable: true,
        title: const Text('Verify password change'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your verification email is queued for ${challenge?.maskedEmail ?? "your account email"}. Check your inbox and spam folder. Only the latest code works; it expires ten minutes after requesting it.',
            ),
            const SizedBox(height: 12),
            const Text('Confirming the change signs you out on every device.'),
            if (widget.hasUnsavedProfileChanges)
              const Text(
                'Unsaved profile changes and selected photos will be lost.',
              ),
            if (challenge?.expired ?? false)
              const Text('This code has expired. Request a new code.'),
            if (c.errorMessage != null)
              Semantics(liveRegion: true, child: Text(c.errorMessage!)),
            TextField(
              controller: _code,
              autofocus: true,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              maxLength: 6,
              enabled: !c.isBusy && !c.passwordRequiresReconciliation,
              decoration: InputDecoration(
                labelText: 'Verification code',
                errorText: _localError ?? c.fieldError('verification_code'),
              ),
            ),
            TextButton(
              onPressed:
                  c.isBusy ||
                      seconds > 0 ||
                      c.passwordCoolingDown ||
                      c.passwordRequiresReconciliation
                  ? null
                  : () async {
                      if (await widget.onResend() && mounted) {
                        _code.clear();
                        setState(() {
                          _localError = null;
                        });
                      }
                    },
              child: Text(
                seconds > 0 ? 'Resend in ${seconds}s' : 'Resend code',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: c.isBusy ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed:
                c.isBusy ||
                    c.passwordCoolingDown ||
                    c.passwordRequiresReconciliation ||
                    challenge == null ||
                    challenge.expired
                ? null
                : () async {
                    if (!RegExp(r'^[0-9]{6}$').hasMatch(_code.text)) {
                      setState(() {
                        _localError = 'Enter the six-digit code.';
                      });
                      return;
                    }
                    setState(() {
                      _localError = null;
                    });
                    await widget.onVerify(_code.text);
                  },
            child: Text(
              c.isBusy ? 'Please wait…' : 'Verify and update password',
            ),
          ),
        ],
      ),
    );
  }
}
