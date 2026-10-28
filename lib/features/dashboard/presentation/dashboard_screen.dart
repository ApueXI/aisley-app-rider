import '../../linehaul/presentation/linehaul_controller.dart';
import '../../linehaul/presentation/linehaul_screen.dart';

import 'dart:async';

import '../../../shared/presentation/destination_scope.dart';
import '../../../shared/presentation/courier_section_header.dart';
import '../../../shared/presentation/courier_status_badge.dart';
import '../../../shared/presentation/courier_surface_card.dart';
import '../../../shared/presentation/sign_out_confirmation.dart';
import '../../vehicle/presentation/vehicle_screen.dart';
import '../../policy/presentation/policy_screen.dart';

import 'package:flutter/material.dart';

import '../../account/domain/account_models.dart';
import '../../account/presentation/controllers/account_controller.dart';
import '../../account/presentation/account_screen.dart';
import '../../auth/domain/auth_models.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../batch/presentation/controllers/final_mile_batch_controller.dart';
import '../../batch/presentation/final_mile_batch_screen.dart';
import '../../chat/presentation/chat_inbox_screen.dart';
import '../../chat/presentation/controllers/chat_controller.dart';
import '../../delivery/presentation/controllers/delivery_controller.dart';
import '../../delivery/presentation/delivery_screen.dart';
import '../../delivery/presentation/final_mile_task_entry_screen.dart';
import '../../history/presentation/controllers/history_controller.dart';
import '../../history/presentation/history_screen.dart';
import '../../notification/domain/notification_models.dart';
import '../../notification/domain/notification_target.dart';
import '../../notification/presentation/controllers/notification_controller.dart';
import '../../notification/presentation/notification_screen.dart';
import '../../policy/presentation/controllers/policy_controller.dart';
import '../../pickup/presentation/controllers/pickup_controller.dart';
import '../../pickup/presentation/pickup_screen.dart';
import '../../pickup/domain/pickup_models.dart';
import '../../support/presentation/controllers/support_ticket_controller.dart';
import '../../support/presentation/support_ticket_screen.dart';
import '../../vehicle/presentation/controllers/vehicle_controller.dart';
import '../domain/dashboard_models.dart';
import '../domain/dashboard_task_preview.dart';
import 'controllers/dashboard_preview_controller.dart';

part 'components/dashboard_body.dart';
part 'components/dashboard_cards.dart';
part 'components/dashboard_aggregate.dart';
part 'components/dashboard_status.dart';
part 'components/dashboard_task_previews.dart';
part 'components/dashboard_navigation.dart';
part 'components/dashboard_destinations.dart';
part 'components/dashboard_shell_content.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    required this.authController,
    this.accountController,
    this.batchController,
    this.linehaulController,
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
  final LinehaulController? linehaulController;
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
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver, RouteAware, _DashboardNavigation {
  int _tab = 0;
  int _workIndex = 1;
  final _visited = <int>{0};
  bool _routeVisible = true;
  bool _foreground = true;
  ModalRoute<void>? _route;

  int get _index => switch (_tab) {
    0 => 0,
    1 => _workIndex,
    2 => 6,
    _ => 7,
  };

  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    widget.authController.addListener(_handleSession);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_refreshDashboard(refreshNotifications: false));
      _syncPolling();
      final account = widget.accountController;
      if (account != null && account.account == null) {
        unawaited(account.loadAccount());
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != _route) {
      courierRouteObserver.unsubscribe(this);
      _route = route;
      if (route != null) courierRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPushNext() => _setRouteVisible(false);
  @override
  void didPopNext() {
    _setRouteVisible(true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncPolling();
    });
    if (_tab == 0) unawaited(_refreshDashboard());
  }

  void _setRouteVisible(bool value) {
    if (!mounted || _routeVisible == value) return;
    setState(() => _routeVisible = value);
    _syncPolling();
  }

  void _syncPolling() {
    final visible =
        _routeVisible &&
        _foreground &&
        widget.authController.status == AuthStatus.authenticated;
    if (visible && _tab == 0) {
      widget.notificationController?.startPolling();
    } else {
      widget.notificationController?.stopPolling();
    }
    if (!visible || _tab != 2) widget.chatController?.stopPolling();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() => _foreground = state == AppLifecycleState.resumed);
    _syncPolling();
    if (_foreground && _routeVisible && _tab == 0) {
      unawaited(_refreshDashboard(refreshNotifications: false));
    }
  }

  void _handleSession() {
    if (widget.authController.status == AuthStatus.authenticated) return;
    widget.notificationController?.stopPolling();
    widget.chatController?.stopPolling();
    widget.dashboardPreviewController?.clear();
    if (widget.authController.status == AuthStatus.policyConsentRequired) {
      return;
    }
    // A session gate must cover every pushed private destination immediately.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    });
  }

  @override
  void dispose() {
    courierRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    widget.authController.removeListener(_handleSession);
    widget.notificationController?.stopPolling();
    widget.chatController?.stopPolling();
    super.dispose();
  }

  void _selectTab(int tab) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _tab = tab;
      _visited.add(_index);
    });
    _syncPolling();
    if (tab == 0) unawaited(_refreshDashboard());
  }

  @override
  void _selectWork(int index) {
    setState(() {
      _tab = 1;
      _workIndex = index;
      _visited.add(index);
    });
    _syncPolling();
  }

  @override
  Future<void> _pushPage(Widget page) async {
    final wasVisible = _routeVisible;
    _setRouteVisible(false);
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted && widget.authController.status == AuthStatus.authenticated) {
      _setRouteVisible(wasVisible && ModalRoute.of(context)?.isCurrent == true);
      _syncPolling();
    }
  }

  Future<void> _refreshDashboard({bool refreshNotifications = true}) async {
    if (widget.authController.status != AuthStatus.authenticated) return;
    await widget.authController.loadDashboard();
    if (!mounted || widget.authController.status != AuthStatus.authenticated) {
      return;
    }
    await Future.wait<void>([
      if (widget.authController.dashboard?.operational != true)
        if (widget.dashboardPreviewController case final controller?)
          controller.refreshAll(),
      if (refreshNotifications && widget.notificationController != null)
        widget.notificationController!.refresh(silent: true),
    ]);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.authController,
    builder: (context, _) {
      if (widget.authController.status != AuthStatus.authenticated) {
        final needsPolicy =
            widget.authController.status == AuthStatus.policyConsentRequired;
        return Scaffold(
          appBar: AppBar(title: const Text('AISLEY Courier')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    needsPolicy
                        ? 'Review the current policies before opening Courier work.'
                        : 'Session ended.',
                  ),
                  if (needsPolicy && widget.policyController != null)
                    TextButton(
                      onPressed: _openPolicies,
                      child: const Text('Review policies'),
                    ),
                ],
              ),
            ),
          ),
        );
      }
      if (widget.authController.courier == null) return const SizedBox.shrink();
      return PopScope(
        canPop: _tab == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _selectTab(0);
        },
        child: Scaffold(
          body: IndexedStack(
            index: _index,
            children: [
              for (var i = 0; i < 8; i++)
                DestinationScope(
                  visible: i == _index && _routeVisible && _foreground,
                  onBack: i >= 2 && i <= 5 ? () => _selectWork(1) : null,
                  child: TickerMode(
                    enabled: i == _index && _routeVisible && _foreground,
                    child: _visited.contains(i)
                        ? _destination(i)
                        : const SizedBox.shrink(),
                  ),
                ),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: _selectTab,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.local_shipping_outlined),
                selectedIcon: Icon(Icons.local_shipping),
                label: 'Work',
              ),
              NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline),
                selectedIcon: Icon(Icons.chat_bubble),
                label: 'Task messages',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Account',
              ),
            ],
          ),
        ),
      );
    },
  );
}
