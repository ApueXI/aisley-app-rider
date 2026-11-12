part of '../dashboard_screen.dart';

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.authController,
    this.pickupController,
    required this.onOpenPickups,
    this.deliveryController,
    this.historyController,
    required this.onOpenDeliveries,
    required this.onOpenHistory,
    required this.onOpenWork,
    this.onOpenBatches,
    this.onOpenNotifications,
    this.previewController,
  });

  final AuthController authController;
  final PickupController? pickupController;
  final VoidCallback onOpenPickups;
  final DeliveryController? deliveryController;
  final HistoryController? historyController;
  final VoidCallback onOpenDeliveries, onOpenHistory;
  final VoidCallback onOpenWork;
  final VoidCallback? onOpenBatches, onOpenNotifications;
  final DashboardPreviewController? previewController;

  @override
  Widget build(BuildContext context) {
    final snapshot = authController.dashboard;
    final loading =
        authController.dashboardStatus == DashboardLoadStatus.loading;
    return ListView(
      key: const PageStorageKey('home-work'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _WelcomeCard(courier: authController.courier!),
        if (pickupController != null || deliveryController != null) ...[
          const SizedBox(height: 16),
          _WorkShortcuts(
            onOpenPickups: pickupController == null ? null : onOpenPickups,
            onOpenDeliveries: deliveryController == null
                ? null
                : onOpenDeliveries,
          ),
        ],
        if (authController.dashboardErrorMessage case final message?) ...[
          const SizedBox(height: 16),
          _DashboardErrorBanner(
            message: message,
            onRetry: authController.canRetryDashboard
                ? authController.loadDashboard
                : null,
          ),
        ],
        if (snapshot?.operational == true)
          _DashboardAggregate(
            snapshot: snapshot!,
            onRetry: authController.canRetryDashboard
                ? authController.loadDashboard
                : null,
            onOpenPickups: onOpenPickups,
            onOpenDeliveries: onOpenDeliveries,
            onOpenWork: onOpenWork,
            onOpenBatches: onOpenBatches,
            onOpenNotifications: onOpenNotifications,
          )
        else ...[
          if (previewController case final previews?)
            _DashboardTaskPreviews(
              controller: previews,
              onOpenFirstMile: onOpenPickups,
              onOpenFinalMile: onOpenDeliveries,
            ),
          _LegacyWorkStatus(
            snapshot: snapshot,
            loading: loading,
            stale: authController.dashboardErrorMessage != null,
            hasPreviews: previewController != null,
          ),
        ],
        if (snapshot?.operational != true)
          TextButton.icon(
            onPressed: loading || !authController.canRetryDashboard
                ? null
                : authController.loadDashboard,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh dashboard'),
          ),
      ],
    );
  }
}
