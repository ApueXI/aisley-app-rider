part of '../dashboard_screen.dart';

mixin _DashboardNavigation on State<DashboardScreen> {
  void _selectWork(int index);
  Future<void> _pushPage(Widget page);
  bool _confirmingSignOut = false;
  Future<void> _confirmSignOut() async {
    if (_confirmingSignOut || widget.authController.isSigningOut) return;
    _confirmingSignOut = true;
    final shouldSignOut = await confirmCourierSignOut(context);
    _confirmingSignOut = false;

    if (shouldSignOut != true || !mounted) {
      return;
    }

    final didSignOut = await widget.authController.signOut();
    if (!mounted || didSignOut) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Sign out could not be completed. Your session remains active.',
        ),
      ),
    );
  }

  Future<void> _openAccount({
    AccountSection section = AccountSection.profile,
  }) async {
    final accountController = widget.accountController;
    if (accountController == null || !mounted) {
      return;
    }

    await _pushPage(
      AccountScreen(
        authController: widget.authController,
        accountController: accountController,
        section: section,
        policyController: widget.policyController,
        vehicleController: widget.vehicleController,
      ),
    );
  }

  Future<void> _openPolicies() async {
    final controller = widget.policyController;
    if (controller == null || !mounted) return;
    await _pushPage(
      PolicyScreen(
        authController: widget.authController,
        policyController: controller,
      ),
    );
  }

  Future<void> _openPickups() async {
    if (!mounted || widget.pickupController == null) return;
    if (ModalRoute.of(context)?.isCurrent == true) {
      _selectWork(2);
    } else {
      await _pushPage(
        PickupScreen(
          authController: widget.authController,
          pickupController: widget.pickupController!,
          policyController: widget.policyController,
          onOpenDelivery: _openDeliveries,
          onOpenBatches: _openBatches,
          chatController: widget.chatController,
        ),
      );
    }
  }

  Future<void> _openBatches() async {
    if (!mounted || widget.batchController == null) return;
    if (ModalRoute.of(context)?.isCurrent == true) {
      _selectWork(4);
    } else {
      await _pushPage(
        FinalMileBatchScreen(
          authController: widget.authController,
          batchController: widget.batchController!,
          policyController: widget.policyController,
        ),
      );
    }
  }

  Future<void> _openDeliveries() async {
    if (!mounted || widget.deliveryController == null) return;
    if (ModalRoute.of(context)?.isCurrent == true) {
      _selectWork(3);
    } else {
      await _pushPage(
        DeliveryScreen(
          authController: widget.authController,
          deliveryController: widget.deliveryController!,
          policyController: widget.policyController,
          onOpenPickup: _openPickups,
          chatController: widget.chatController,
        ),
      );
    }
  }

  Future<void> _openHistory() async {
    if (!mounted || widget.historyController == null) return;
    if (ModalRoute.of(context)?.isCurrent == true) {
      _selectWork(5);
    } else {
      await _pushPage(
        HistoryScreen(
          authController: widget.authController,
          historyController: widget.historyController!,
          policyController: widget.policyController,
        ),
      );
    }
  }

  Future<void> _openNotifications() async {
    final notificationController = widget.notificationController;
    if (notificationController == null || !mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NotificationScreen(
          controller: notificationController,
          managePolling: true,
          onOpenTarget: _openNotificationTarget,
        ),
      ),
    );
  }

  Future<void> _openNotificationTarget(CourierNotification notification) async {
    if (!mounted || widget.authController.status != AuthStatus.authenticated) {
      return;
    }
    final target = NotificationTarget.resolve(notification);
    if (target?.kind == NotificationTargetKind.supportTicket) {
      final support = widget.supportTicketController;
      if (support == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The related support ticket is not currently available.',
            ),
          ),
        );
        return;
      }
      final ticket = await support.openDetailById(target!.resourceId);
      if (!mounted ||
          widget.authController.status != AuthStatus.authenticated) {
        support.closeDetail();
        return;
      }
      if (ticket == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              support.detailError ??
                  'The related support ticket is no longer available.',
            ),
          ),
        );
        support.closeDetail();
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SupportTicketDetailScreen(
            controller: support,
            authController: widget.authController,
            ticket: ticket,
            initiallyLoaded: true,
          ),
        ),
      );
      support.closeDetail();
      return;
    }

    final pickup = widget.pickupController;
    final delivery = widget.deliveryController;
    if (target == null ||
        pickup == null ||
        (target.kind == NotificationTargetKind.finalMileTask &&
            delivery == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The related work is not currently available to this Courier.',
          ),
        ),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => target.kind == NotificationTargetKind.pickupSchedule
            ? PickupScreen(
                authController: widget.authController,
                pickupController: pickup,
                scheduleId: target.resourceId,
                policyController: widget.policyController,
                chatController: widget.chatController,
              )
            : FinalMileTaskEntryScreen(
                taskId: target.resourceId,
                authController: widget.authController,
                pickupController: pickup,
                deliveryController: delivery!,
                policyController: widget.policyController,
                chatController: widget.chatController,
                onOpenBatches: widget.batchController == null
                    ? null
                    : _openBatches,
              ),
      ),
    );
  }

  Future<void> _openSupportTickets() async {
    final supportTicketController = widget.supportTicketController;
    if (supportTicketController == null || !mounted) return;
    await _pushPage(
      SupportTicketScreen(
        controller: supportTicketController,
        authController: widget.authController,
      ),
    );
  }
}
