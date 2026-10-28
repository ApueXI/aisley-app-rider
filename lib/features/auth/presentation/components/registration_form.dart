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
    final step = _verification.verified ? _step : 0;
    final busy = _isSubmitting || _isPickingEvidence;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: busy ? null : _backRegistration,
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Courier registration'),
      ),
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
              if (step == 0) ...[
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
                  'Verify access to your email before continuing. Logistics reviews your application after registration.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
              ],
              Text(
                'Step ${step + 1} of 6 · ${_registrationSteps[step]}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (step + 1) / 6,
                semanticsLabel: 'Registration step ${step + 1} of 6',
              ),
              const SizedBox(height: 24),
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
                        controller: _verification,
                        disabled: busy,
                        emailFocusNode: _emailVerificationFocus,
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
              ] else if (step == 5) ...[
                if (!widget.authController.canRegister)
                  const Text(
                    'Please wait before submitting your registration again.',
                  ),
                const Text(
                  'Your selected Logistics organization must approve your application before you can sign in.',
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: widget.authController.canRegister && !busy
                      ? _submit
                      : null,
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Submit registration'),
                ),
              ] else if (step > 0 || _verification.verified)
                FilledButton(
                  onPressed: busy ? null : _continueStep,
                  child: const Text('Continue'),
                ),
              if (step > 0)
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
