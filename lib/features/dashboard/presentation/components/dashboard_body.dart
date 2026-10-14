part of '../dashboard_screen.dart';

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.authController,
    required this.onSignOut,
    this.pickupController,
    required this.onOpenPickups,
    this.deliveryController,
    this.historyController,
    required this.onOpenDeliveries,
    required this.onOpenHistory,
    this.onOpenBatches,
    this.onOpenNotifications,
    this.previewController,
    this.profilePhoto,
  });

  final AuthController authController;
  final VoidCallback onSignOut;
  final PickupController? pickupController;
  final VoidCallback onOpenPickups;
  final DeliveryController? deliveryController;
  final HistoryController? historyController;
  final VoidCallback onOpenDeliveries, onOpenHistory;
  final VoidCallback? onOpenBatches, onOpenNotifications;
  final DashboardPreviewController? previewController;
  final ProfilePhotoData? profilePhoto;

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
        _WelcomeCard(
          courier: authController.courier!,
          profilePhoto: profilePhoto,
        ),
        const SizedBox(height: 24),
        if (authController.dashboardErrorMessage case final message?) ...[
          _DashboardErrorBanner(
            message: message,
            onRetry: authController.canRetryDashboard
                ? authController.loadDashboard
                : null,
          ),
          const SizedBox(height: 16),
        ],
        if (snapshot?.operational == true)
          _DashboardAggregate(
            snapshot: snapshot!,
            stale: authController.dashboardErrorMessage != null,
            onOpenPickups: onOpenPickups,
            onOpenDeliveries: onOpenDeliveries,
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
        const SizedBox(height: 24),
        if (pickupController != null || deliveryController != null) ...[
          Text(
            'Work shortcuts',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (pickupController != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('Pickup orders'),
              trailing: const Icon(Icons.chevron_right),
              onTap: onOpenPickups,
            ),
          if (deliveryController != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.local_shipping_outlined),
              title: const Text('Delivery work'),
              trailing: const Icon(Icons.chevron_right),
              onTap: onOpenDeliveries,
            ),
        ],
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
