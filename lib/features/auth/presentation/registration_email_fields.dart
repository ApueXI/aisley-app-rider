import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'registration_email_controller.dart';

class RegistrationEmailFields extends StatefulWidget {
  const RegistrationEmailFields({
    super.key,
    required this.controller,
    this.onVerified,
    this.disabled = false,
    this.showInlineAction = true,
    this.draftEmail,
    this.emailFocusNode,
  });
  final RegistrationEmailController controller;
  final VoidCallback? onVerified;
  final bool disabled;
  final bool showInlineAction;
  final String? draftEmail;
  final FocusNode? emailFocusNode;
  @override
  RegistrationEmailFieldsState createState() => RegistrationEmailFieldsState();
}

class RegistrationEmailFieldsState extends State<RegistrationEmailFields> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _codeFocus = FocusNode();
  @override
  void initState() {
    super.initState();
    _email.text = widget.draftEmail ?? widget.controller.email;
  }

  @override
  void didUpdateWidget(covariant RegistrationEmailFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.draftEmail != null && _email.text != widget.draftEmail) {
      _email.text = widget.draftEmail!;
    }
  }

  Future<void> _send() async {
    final c = widget.controller;
    if (widget.disabled || c.busy || c.resendSeconds > 0) return;
    if (c.challenge == null && !(_form.currentState?.validate() ?? false)) {
      return;
    }
    if (await c.send(_email.text) && mounted) {
      _code.clear();
      _codeFocus.requestFocus();
    }
  }

  Future<void> _verify() async {
    if (widget.disabled || !(_form.currentState?.validate() ?? false)) return;
    if (await widget.controller.verify(_code.text) && mounted) {
      _code.clear();
      widget.onVerified?.call();
    } else if (mounted) {
      _codeFocus.requestFocus();
    }
  }

  Future<void> submitCurrentAction() async {
    if (widget.controller.challenge == null) {
      await _send();
    } else {
      await _verify();
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      return Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (c.challenge != null && !c.verified) ...[
              Text(
                'A 6-digit verification code was sent to',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 4),
              Text(
                c.email,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              _VerificationNotice(
                child: Text(
                  'Verifying your email submits your registration. Your application is pending only after the server confirms it, and Logistics approval is still required.',
                ),
              ),
              if (c.message == null || c.failed) ...[
                const SizedBox(height: 16),
                const Text(
                  'Check your inbox and spam folder for the latest code.',
                ),
              ],
            ] else ...[
              Text(
                c.verified ? 'Email access verified' : 'Email verification',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                c.verified
                    ? 'Inbox access verified for ${c.verifiedEmail}. This does not determine Courier eligibility or activate your account.'
                    : 'Enter the six-digit code sent to your email. Check your spam folder too. Verifying automatically submits your registration; Logistics approval is still required.',
              ),
            ],
            if (c.message != null) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  c.message!,
                  style: TextStyle(
                    color: c.failed
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (c.verified)
              const SizedBox.shrink()
            else ...[
              if (c.challenge == null)
                TextFormField(
                  controller: _email,
                  readOnly: widget.draftEmail != null,
                  focusNode: widget.emailFocusNode,
                  enabled: !c.busy && !widget.disabled,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  autocorrect: false,
                  maxLength: 255,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(labelText: 'Email address'),
                  validator: (v) =>
                      v == null ||
                          !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                              .hasMatch(v.trim())
                      ? 'Enter a valid email address.'
                      : null,
                  onFieldSubmitted: (_) => _send(),
                ),
              if (c.challenge != null && !c.verified) ...[
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          'Verification code',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.timer_outlined,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        c.expired
                            ? 'Code expired'
                            : 'Expires in ${_formatRemaining(c.challenge!.expiresAt.difference(c.clock()))}',
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _code,
                  focusNode: _codeFocus,
                  enabled: !c.busy && !widget.disabled,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  textInputAction: TextInputAction.done,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    hintText: 'Enter 6-digit code',
                  ),
                  validator: (v) =>
                      v == null || !RegExp(r'^[0-9]{6}$').hasMatch(v)
                      ? 'Enter all six digits.'
                      : null,
                  onFieldSubmitted: (_) => _verify(),
                ),
              ],
              if (c.challenge != null && !c.verified) ...[
                TextButton(
                  onPressed: c.busy || c.resendSeconds > 0 || widget.disabled
                      ? null
                      : _send,
                  child: Text(
                    c.resendSeconds > 0
                        ? 'Resend code (${_formatRemaining(Duration(seconds: c.resendSeconds))} cooldown)'
                        : 'Resend code',
                  ),
                ),
              ],
              if (widget.showInlineAction) ...[
                const SizedBox(height: 16),
                FilledButton(
                  onPressed:
                      c.busy ||
                          c.coolingDown ||
                          c.expired ||
                          widget.disabled ||
                          c.resendSeconds > 0 && c.challenge == null
                      ? null
                      : submitCurrentAction,
                  child: Text(
                    c.busy
                        ? 'Please wait…'
                        : c.challenge == null
                        ? 'Send verification code'
                        : 'Verify and submit',
                  ),
                ),
              ],
              if (c.coolingDown)
                Text('Please wait ${c.resendSeconds}s before trying again.'),
            ],
          ],
        ),
      );
    },
  );
}

class _VerificationNotice extends StatelessWidget {
  const _VerificationNotice({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(child: child),
        ],
      ),
    );
  }
}

String _formatRemaining(Duration remaining) {
  final seconds = remaining.inSeconds.clamp(0, 3600);
  final minutes = seconds ~/ 60;
  final rest = seconds % 60;
  return '$minutes:${rest.toString().padLeft(2, '0')}';
}
