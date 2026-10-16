part of '../dashboard_screen.dart';

extension _DashboardShellContent on _DashboardScreenState {
  Widget _home() => Scaffold(
    appBar: AppBar(
      title: const Text('AISLEY'),
      actions: [
        if (widget.notificationController case final notifications?)
          AnimatedBuilder(
            animation: notifications,
            builder: (context, _) => IconButton(
              tooltip: 'Notifications',
              onPressed: _openNotifications,
              icon: Badge(
                isLabelVisible: (notifications.unreadCount ?? 0) > 0,
                label: Text('${notifications.unreadCount ?? 0}'),
                child: const Icon(Icons.notifications_none_outlined),
              ),
            ),
          ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: _refreshDashboard,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          widget.authController,
          ?widget.accountController,
        ]),
        builder: (context, _) => _DashboardBody(
          authController: widget.authController,
          onSignOut: _confirmSignOut,
          pickupController: widget.pickupController,
          onOpenPickups: _openPickups,
          deliveryController: widget.deliveryController,
          historyController: widget.historyController,
          onOpenDeliveries: _openDeliveries,
          onOpenHistory: _openHistory,
          onOpenBatches: widget.batchController == null ? null : _openBatches,
          onOpenNotifications: widget.notificationController == null
              ? null
              : _openNotifications,
          previewController: widget.dashboardPreviewController,
          profilePhoto: widget.accountController?.profilePhoto,
        ),
      ),
    ),
  );

  Widget _destination(int index) => switch (index) {
    0 => _home(),
    1 => _WorkDestinations(
      onPickups: widget.pickupController == null ? null : _openPickups,
      onDeliveries: widget.deliveryController == null ? null : _openDeliveries,
      onBatches: widget.batchController == null ? null : _openBatches,
      onHistory: widget.historyController == null ? null : _openHistory,
    ),
    2 => PickupScreen(
      authController: widget.authController,
      pickupController: widget.pickupController!,
      policyController: widget.policyController,
      onOpenDelivery: _openDeliveries,
      onOpenBatches: _openBatches,
      chatController: widget.chatController,
    ),
    3 => DeliveryScreen(
      authController: widget.authController,
      deliveryController: widget.deliveryController!,
      policyController: widget.policyController,
      onOpenPickup: _openPickups,
      chatController: widget.chatController,
    ),
    4 => FinalMileBatchScreen(
      authController: widget.authController,
      batchController: widget.batchController!,
      policyController: widget.policyController,
    ),
    5 => HistoryScreen(
      authController: widget.authController,
      historyController: widget.historyController!,
      policyController: widget.policyController,
    ),
    6 =>
      widget.chatController == null
          ? const Scaffold(
              appBar: null,
              body: Center(child: Text('Task messages are unavailable.')),
            )
          : ChatInboxScreen(
              controller: widget.chatController!,
              authController: widget.authController,
            ),
    _ => _AccountDestinations(
      name: widget.authController.courier?.displayName ?? 'Courier',
      onProfile: widget.accountController == null ? null : _openAccount,
      onSecurity: widget.accountController == null
          ? null
          : () => _openAccount(section: AccountSection.security),
      onVehicle: widget.vehicleController == null
          ? null
          : () => _pushPage(
              VehicleScreen(
                authController: widget.authController,
                vehicleController: widget.vehicleController!,
              ),
            ),
      onPolicies: widget.policyController == null
          ? null
          : () => _pushPage(
              PolicyScreen(
                authController: widget.authController,
                policyController: widget.policyController!,
              ),
            ),
      onSupport: widget.supportTicketController == null
          ? null
          : _openSupportTickets,
      onSignOut: widget.authController.isSigningOut ? null : _confirmSignOut,
    ),
  };
}
