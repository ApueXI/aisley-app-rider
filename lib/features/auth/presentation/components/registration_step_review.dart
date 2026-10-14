part of '../registration_screen.dart';

extension _RegistrationReviewStep on _RegistrationScreenState {
  Widget _buildReviewStep(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _buildReviewSummary(context),
      const SizedBox(height: 24),
      _twoColumn(
        _passwordField(
          controller: _passwordController,
          label: 'Password',
          serverKey: 'password',
        ),
        _passwordField(
          controller: _passwordConfirmationController,
          label: 'Confirm password',
          serverKey: 'password_confirmation',
          confirmation: true,
        ),
      ),
      const SizedBox(height: 24),
    ],
  );
}
