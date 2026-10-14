import 'package:flutter/material.dart';

import 'controllers/auth_controller.dart';

class BlockedAccessScreen extends StatelessWidget {
  const BlockedAccessScreen({
    required this.authController,
    required this.title,
    required this.message,
    required this.icon,
    super.key,
  });

  const BlockedAccessScreen.pending({
    required AuthController authController,
    Key? key,
  }) : this(
         authController: authController,
         title: 'Application pending',
         message: 'The selected Logistics organization still needs to review your Courier application.',
         icon: Icons.hourglass_top_rounded,
         key: key,
       );

  const BlockedAccessScreen.rejected({
    required AuthController authController,
    Key? key,
  }) : this(
         authController: authController,
         title: 'Application not approved',
         message: 'Your application was not approved. Contact your Logistics organization for help.',
         icon: Icons.info_outline_rounded,
         key: key,
       );

  const BlockedAccessScreen.suspended({
    required AuthController authController,
    Key? key,
  }) : this(
         authController: authController,
         title: 'Access unavailable',
         message: 'Your Courier account is suspended or inactive. Contact your Logistics organization for help.',
         icon: Icons.lock_outline_rounded,
         key: key,
       );

  const BlockedAccessScreen.affiliation({
    required AuthController authController,
    Key? key,
  }) : this(
         authController: authController,
         title: 'Logistics affiliation unavailable',
         message: 'Your Logistics affiliation is unavailable. Contact your Logistics organization before signing in again.',
         icon: Icons.domain_disabled_outlined,
         key: key,
       );

  const BlockedAccessScreen.denied({
    required AuthController authController,
    Key? key,
  }) : this(
         authController: authController,
         title: 'Access unavailable',
         message:
             'This Courier account is not currently allowed to access the app.',
         icon: Icons.block_outlined,
         key: key,
       );

  final AuthController authController;
  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return _StatusMessageScreen(
      icon: icon,
      title: title,
      message: message,
      actionLabel: 'Return to sign in',
      onAction: authController.returnToSignIn,
    );
  }
}

class PolicyConsentUnavailableScreen extends StatelessWidget {
  const PolicyConsentUnavailableScreen({
    required this.authController,
    super.key,
  });

  final AuthController authController;

  @override
  Widget build(BuildContext context) {
    return _StatusMessageScreen(
      icon: Icons.policy_outlined,
      title: 'Policy consent unavailable',
      message: 'The app is missing the policy screen needed to complete consent. Return to sign in and try again.',
      actionLabel: 'Return to sign in',
      onAction: authController.returnToSignIn,
    );
  }
}

class RetrySessionScreen extends StatelessWidget {
  const RetrySessionScreen({required this.authController, super.key});

  final AuthController authController;

  @override
  Widget build(BuildContext context) {
    return _StatusMessageScreen(
      icon: Icons.cloud_off_outlined,
      title: 'Connection unavailable',
      message: authController.errorMessage ?? 'We could not check your Courier session. Your access was not changed.',
      actionLabel: 'Retry',
      onAction: authController.canRetrySession ? authController.retry : null,
      waitingMessage: authController.canRetrySession
          ? null
          : 'Please wait before checking your session again.',
    );
  }
}

class SecureStorageFailureScreen extends StatelessWidget {
  const SecureStorageFailureScreen({required this.authController, super.key});

  final AuthController authController;

  @override
  Widget build(BuildContext context) {
    final platformHint = Theme.of(context).platform == TargetPlatform.linux
        ? ' On Linux, unlock the default Secret Service keyring and try again.'
        : '';
    return _StatusMessageScreen(
      icon: Icons.security_outlined,
      title: 'Secure session storage unavailable',
      message:
          '${authController.errorMessage ?? 'The app cannot safely read or update your session on this device.'}$platformHint',
      actionLabel: 'Try again',
      onAction: authController.retry,
    );
  }
}

class _StatusMessageScreen extends StatelessWidget {
  const _StatusMessageScreen({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.waitingMessage,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback? onAction;
  final String? waitingMessage;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                children: [
                  Icon(icon, size: 32, color: scheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (waitingMessage != null) ...[
                    Semantics(liveRegion: true, child: Text(waitingMessage!)),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onAction,
                      child: Text(actionLabel),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
