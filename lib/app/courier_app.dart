import 'package:flutter/material.dart';

import 'courier_theme.dart';

import '../features/account/presentation/controllers/account_controller.dart';
import '../features/auth/presentation/controllers/auth_controller.dart';
import '../features/auth/presentation/blocked_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/registration_screen.dart';
import '../features/batch/presentation/controllers/final_mile_batch_controller.dart';
import '../features/chat/presentation/controllers/chat_controller.dart';
import '../features/dashboard/presentation/controllers/dashboard_preview_controller.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/delivery/presentation/controllers/delivery_controller.dart';
import '../features/history/presentation/controllers/history_controller.dart';
import '../features/notification/presentation/controllers/notification_controller.dart';
import '../features/policy/presentation/controllers/policy_controller.dart';
import '../features/policy/presentation/policy_screen.dart';
import '../features/pickup/presentation/controllers/pickup_controller.dart';
import '../features/support/presentation/controllers/support_ticket_controller.dart';
import '../features/vehicle/presentation/controllers/vehicle_controller.dart';

class CourierApp extends StatelessWidget {
  const CourierApp({
    required this.authController,
    this.accountController,
    this.batchController,
    this.policyController,
    this.pickupController,
    this.deliveryController,
    this.historyController,
    this.notificationController,
    this.chatController,
    this.supportTicketController,
    this.dashboardPreviewController,
    this.vehicleController,
    super.key,
  });

  final AuthController authController;
  final AccountController? accountController;
  final FinalMileBatchController? batchController;
  final PolicyController? policyController;
  final PickupController? pickupController;
  final DeliveryController? deliveryController;
  final HistoryController? historyController;
  final NotificationController? notificationController;
  final ChatController? chatController;
  final SupportTicketController? supportTicketController;
  final DashboardPreviewController? dashboardPreviewController;
  final VehicleController? vehicleController;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aisley Courier',
      theme: buildCourierTheme(Brightness.light),
      darkTheme: buildCourierTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: AuthGate(
        authController: authController,
        accountController: accountController,
        batchController: batchController,
        policyController: policyController,
        pickupController: pickupController,
        deliveryController: deliveryController,
        historyController: historyController,
        notificationController: notificationController,
        chatController: chatController,
        supportTicketController: supportTicketController,
        dashboardPreviewController: dashboardPreviewController,
        vehicleController: vehicleController,
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({
    required this.authController,
    this.accountController,
    this.batchController,
    this.policyController,
    this.pickupController,
    this.deliveryController,
    this.historyController,
    this.notificationController,
    this.chatController,
    this.supportTicketController,
    this.dashboardPreviewController,
    this.vehicleController,
    super.key,
  });

  final AuthController authController;
  final AccountController? accountController;
  final FinalMileBatchController? batchController;
  final PolicyController? policyController;
  final PickupController? pickupController;
  final DeliveryController? deliveryController;
  final HistoryController? historyController;
  final NotificationController? notificationController;
  final ChatController? chatController;
  final SupportTicketController? supportTicketController;
  final DashboardPreviewController? dashboardPreviewController;
  final VehicleController? vehicleController;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _showRegistration = false;

  @override
  Widget build(BuildContext context) {
    final authController = widget.authController;
    return AnimatedBuilder(
      animation: authController,
      builder: (context, child) {
        return switch (authController.status) {
          AuthStatus.checkingSession => const CheckingSessionScreen(
            key: ValueKey('checking-session'),
          ),
          AuthStatus.signedOut || AuthStatus.authenticating =>
            _showRegistration
                ? RegistrationScreen(
                    key: const ValueKey('registration'),
                    authController: authController,
                    onSignIn: _showSignIn,
                  )
                : LoginScreen(
                    key: const ValueKey('login'),
                    authController: authController,
                    onRegister: _showRegistrationScreen,
                  ),
          AuthStatus.authenticated => DashboardScreen(
            key: const ValueKey('dashboard'),
            authController: authController,
            accountController: widget.accountController,
            batchController: widget.batchController,
            policyController: widget.policyController,
            pickupController: widget.pickupController,
            deliveryController: widget.deliveryController,
            historyController: widget.historyController,
            notificationController: widget.notificationController,
            chatController: widget.chatController,
            supportTicketController: widget.supportTicketController,
            dashboardPreviewController: widget.dashboardPreviewController,
            vehicleController: widget.vehicleController,
          ),
          AuthStatus.pendingApproval => BlockedAccessScreen.pending(
            key: const ValueKey('pending-approval'),
            authController: authController,
          ),
          AuthStatus.rejected => BlockedAccessScreen.rejected(
            key: const ValueKey('rejected'),
            authController: authController,
          ),
          AuthStatus.suspendedOrDeactivated => BlockedAccessScreen.suspended(
            key: const ValueKey('suspended'),
            authController: authController,
          ),
          AuthStatus.invalidAffiliation => BlockedAccessScreen.affiliation(
            key: const ValueKey('invalid-affiliation'),
            authController: authController,
          ),
          AuthStatus.accessDenied => BlockedAccessScreen.denied(
            key: const ValueKey('access-denied'),
            authController: authController,
          ),
          AuthStatus.policyConsentRequired =>
            widget.policyController == null
                ? PolicyConsentUnavailableScreen(
                    key: const ValueKey('policy-consent-unavailable'),
                    authController: authController,
                  )
                : PolicyScreen(
                    key: const ValueKey('policy-consent-required'),
                    authController: authController,
                    policyController: widget.policyController!,
                    requiredForAccess: true,
                    showSignOutAction: true,
                    onConsentComplete: authController.completePolicyConsent,
                  ),
          AuthStatus.recoverableNetworkFailure => RetrySessionScreen(
            key: const ValueKey('network-retry'),
            authController: authController,
          ),
          AuthStatus.secureStorageFailure => SecureStorageFailureScreen(
            key: const ValueKey('secure-storage-failure'),
            authController: authController,
          ),
        };
      },
    );
  }

  void _showRegistrationScreen() {
    if (!mounted) {
      return;
    }
    setState(() {
      _showRegistration = true;
    });
  }

  void _showSignIn() {
    if (!mounted) {
      return;
    }
    setState(() {
      _showRegistration = false;
    });
  }
}

class CheckingSessionScreen extends StatelessWidget {
  const CheckingSessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Semantics(
            liveRegion: true,
            label: 'Checking your Courier session',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(height: 20),
                Text(
                  'Checking your Courier session…',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
