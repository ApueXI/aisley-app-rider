part of '../registration_screen.dart';

const _registrationSteps = [
  'Email verification',
  'Personal details',
  'Address',
  'Logistics and vehicle',
  'Required evidence',
  'Review and password',
];

extension _RegistrationForm on _RegistrationScreenState {
  Widget _buildRegistrationForm(BuildContext context) {
    if (_result case final result?) return _buildSubmitted(context, result);
    final step = _step;
    final busy = _isSubmitting || _isPickingEvidence;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: busy ? null : _backRegistration,
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(_step == 0 ? 'Verify your email' : 'Courier registration'),
      ),
      bottomNavigationBar: _step == 0 && !_verification.verified
          ? _RegistrationEmailActionBar(
              controller: _verification,
              enabled:
                  !_isSubmitting &&
                  !_isPickingEvidence &&
                  widget.authController.canRegister,
              onPressed:
                  _registrationEmailFieldsKey.currentState?.submitCurrentAction,
            )
          : null,
      body: SafeArea(
        child: IndexedStack(
          index: step,
          children: [
            for (var page = 0; page < 6; page++)
              ExcludeFocus(
                excluding: step != page,
                child: TickerMode(
                  enabled: step == page,
                  child: page == 0
                      ? _buildStepPage(context, page)
                      : Form(
                          key: _stepFormKeys[page - 1],
                          child: _buildStepPage(context, page),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepPage(BuildContext context, int step) {
    final busy = _isSubmitting || _isPickingEvidence;
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      controller: _stepScrolls[step],
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (step == 1) ...[
                Row(
                  children: [
                    Icon(
                      Icons.local_shipping_outlined,
                      size: 28,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'AISLEY Rider',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Create your account',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Complete your details before verifying your email. Logistics reviews your application after registration.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
              ],
              if (step > 0) ...[
                Text(
                  'Step $step of 6 · ${_registrationSteps[step]}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: step / 6,
                  semanticsLabel: 'Registration step $step of 6',
                ),
                const SizedBox(height: 24),
              ] else
                const SizedBox(height: 12),
              CourierSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_submissionError case final error?) ...[
                      _RegistrationErrorBanner(message: error),
                      const SizedBox(height: 16),
                    ],
                    if (_fieldErrors.isNotEmpty) ...[
                      _RegistrationFieldErrorSummary(errors: _fieldErrors),
                      const SizedBox(height: 16),
                    ],
                    switch (step) {
                      0 => RegistrationEmailFields(
                        key: _registrationEmailFieldsKey,
                        controller: _verification,
                        showInlineAction: false,
                        draftEmail: _emailController.text,
                        disabled: busy || !widget.authController.canRegister,
                        emailFocusNode: _emailVerificationFocus,
                        onVerified: _submit,
                      ),
                      1 => _buildPersonalStep(context),
                      2 => _buildAddressStep(context),
                      3 => _buildLogisticsStep(context),
                      4 => _buildEvidenceStep(context),
                      _ => _buildReviewStep(context),
                    },
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_isSubmitting) ...[
                const LinearProgressIndicator(
                  semanticsLabel: 'Submitting registration',
                ),
                const SizedBox(height: 12),
                const Text('Submitting your application…'),
                OutlinedButton(
                  onPressed: _cancelSubmission,
                  child: const Text('Cancel upload'),
                ),
              ] else if (step > 0)
                FilledButton(
                  onPressed:
                      busy ||
                          (step == 5 &&
                              (_verification.emailVerificationRequired ==
                                      null ||
                                  !widget.authController.canRegister))
                      ? null
                      : _continueStep,
                  child: Text(
                    step == 5
                        ? (_verification.emailVerificationRequired == false
                              ? 'Create account'
                              : 'Continue to email verification')
                        : 'Continue',
                  ),
                ),
              if ((step == 5 || step == 0) &&
                  !widget.authController.canRegister)
                const Text(
                  'Please wait before submitting your registration again.',
                ),
              if (step == 5 && _verification.configLoading)
                const Text('Loading registration settings…'),
              if (step == 5 && _verification.configError != null) ...[
                Text(_verification.configError!),
                TextButton(
                  onPressed: _verification.loadConfig,
                  child: const Text('Retry registration settings'),
                ),
              ],
              if (step == 0)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: busy ? null : _backRegistration,
                  icon: const Icon(Icons.edit_note_outlined),
                  label: const Text('Back to review'),
                )
              else if (step != 1)
                TextButton(
                  onPressed: busy ? null : _backRegistration,
                  child: const Text('Back'),
                ),
              TextButton(
                onPressed: busy ? null : _leaveRegistration,
                child: const Text('Already registered? Sign in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegistrationEmailActionBar extends StatelessWidget {
  const _RegistrationEmailActionBar({
    required this.controller,
    required this.enabled,
    required this.onPressed,
  });

  final RegistrationEmailController controller;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final hasChallenge = controller.challenge != null;
        final actionEnabled =
            enabled &&
            !controller.busy &&
            !controller.coolingDown &&
            (hasChallenge
                ? !controller.expired
                : controller.resendSeconds == 0);
        return SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onPressed: actionEnabled ? onPressed : null,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final label = controller.busy
                        ? 'Please wait…'
                        : hasChallenge
                        ? 'Verify and submit'
                        : 'Send verification code';
                    final stackAction =
                        constraints.maxWidth < 300 ||
                        MediaQuery.textScalerOf(context).scale(1) > 1.25;
                    final text = Text(label, textAlign: TextAlign.center);

                    if (controller.busy) return text;
                    if (stackAction) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          text,
                          const SizedBox(height: 4),
                          const Icon(Icons.arrow_forward),
                        ],
                      );
                    }
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(child: text),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
