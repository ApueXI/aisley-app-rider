import 'package:flutter/material.dart';

import '../../../shared/presentation/courier_status_badge.dart';
import '../../../shared/presentation/courier_surface_card.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../policy/presentation/controllers/policy_controller.dart';
import '../../policy/presentation/policy_screen.dart';
import '../domain/linehaul_trip.dart';
import 'linehaul_controller.dart';
import 'linehaul_route_screen.dart';

part 'linehaul_trip_detail_cards.dart';

class LinehaulTripDetailScreen extends StatefulWidget {
  const LinehaulTripDetailScreen({
    required this.tripId,
    required this.controller,
    required this.authController,
    this.policyController,
    super.key,
  });

  final String tripId;
  final LinehaulController controller;
  final AuthController authController;
  final PolicyController? policyController;

  @override
  State<LinehaulTripDetailScreen> createState() =>
      _LinehaulTripDetailScreenState();
}

class _LinehaulTripDetailScreenState extends State<LinehaulTripDetailScreen> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final trip = controller.trips
            .where((candidate) => candidate.id == widget.tripId)
            .firstOrNull;
        if (trip == null) return _unavailableScreen(controller);

        return PopScope(
          canPop: !controller.saving,
          child: Scaffold(
            appBar: AppBar(title: const Text('Linehaul job')),
            body: RefreshIndicator(
              onRefresh: controller.load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  _LinehaulJobSummary(trip: trip),
                  if (controller.error case final error?) ...[
                    const SizedBox(height: 12),
                    _LinehaulErrorCard(
                      message: error,
                      onRetry: controller.uncertain
                          ? controller.retry
                          : controller.load,
                      onOpenPolicies: widget.policyController == null
                          ? null
                          : _openPolicies,
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (trip.courierArrivedAt case final arrivedAt?) ...[
                    _ArrivalReportedCard(arrivedAt: arrivedAt),
                    const SizedBox(height: 16),
                    const _WaitForLogisticsCard(),
                  ] else if (trip.status == 'in_transfer') ...[
                    const _ArrivalNeededCard(),
                  ] else if (trip.status == 'receiving') ...[
                    const _LogisticsReceivingCard(),
                  ] else if (trip.status == 'received') ...[
                    const _LogisticsReceivedCard(),
                  ] else ...[
                    CourierSurfaceCard(child: Text(trip.guidance)),
                  ],
                ],
              ),
            ),
            bottomNavigationBar: _actions(trip, controller),
          ),
        );
      },
    );
  }

  Widget _unavailableScreen(LinehaulController controller) => Scaffold(
    appBar: AppBar(title: const Text('Linehaul job')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              controller.error ?? 'This linehaul job is no longer available.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: controller.loading || controller.coolingDown
                  ? null
                  : controller.load,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh linehaul jobs'),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _actions(LinehaulTrip trip, LinehaulController controller) {
    final action = trip.canDepart
        ? 'depart'
        : trip.canReportArrival
        ? 'arrival'
        : null;
    final actionLabel = switch (action) {
      'depart' => 'Depart',
      'arrival' => 'Report arrival at hub',
      _ => null,
    };
    final refreshLabel = trip.courierArrivedAt == null
        ? 'Refresh trip status'
        : 'Refresh arrival status';
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (controller.uncertain) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: controller.saving || controller.coolingDown
                      ? null
                      : controller.retry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry same confirmation'),
                ),
              ),
              const SizedBox(height: 8),
            ] else if (action != null) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                      controller.loading ||
                          controller.saving ||
                          controller.coolingDown
                      ? null
                      : () => _confirm(action, trip),
                  icon: Icon(
                    action == 'depart'
                        ? Icons.local_shipping_outlined
                        : Icons.flag_outlined,
                  ),
                  label: Text(actionLabel!),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        controller.loading ||
                            controller.saving ||
                            controller.coolingDown
                        ? null
                        : controller.load,
                    icon: const Icon(Icons.refresh),
                    label: Text(refreshLabel, textAlign: TextAlign.center),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        controller.saving ||
                            controller.routeLoading ||
                            controller.routeCoolingDown ||
                            controller.coolingDown
                        ? null
                        : _openRoute,
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('View route'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirm(String action, LinehaulTrip trip) async {
    final controller = widget.controller;
    final revision = trip.revision;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: Text(
          action == 'depart' ? 'Confirm departure?' : 'Confirm arrival?',
        ),
        content: Text(
          action == 'depart'
              ? 'Confirm you have physically left ${trip.fromHub} after origin Logistics released the trip.'
              : 'Confirm you have reached ${trip.toHub}. This reports your arrival but does not confirm cargo receipt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(action == 'depart' ? 'Depart' : 'Report arrival'),
          ),
        ],
      ),
    );
    if (accepted == true &&
        mounted &&
        controller.selected?.id == trip.id &&
        controller.selected?.revision == revision) {
      await controller.confirm(action);
    }
  }

  Future<void> _openRoute() async {
    final controller = widget.controller;
    if (controller.route == null && !controller.routeLoading) {
      await controller.loadRoute();
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LinehaulRouteScreen(controller: controller),
      ),
    );
  }

  Future<void> _openPolicies() async {
    final policy = widget.policyController;
    if (policy == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PolicyScreen(
          authController: widget.authController,
          policyController: policy,
        ),
      ),
    );
    if (mounted) await widget.controller.load();
  }
}

String _linehaulStatusLabel(String status) => switch (status) {
  'pending_acceptance' => 'Awaiting approval',
  'scheduled' => 'Scheduled',
  'rejected' => 'Rejected',
  'cancelled' => 'Cancelled',
  'receiving' => 'Receiving',
  'received' => 'Received',
  _ => 'Status unavailable',
};

String formatTripDate(DateTime? value) {
  if (value == null) return 'Not recorded';
  final p = value.toUtc().add(const Duration(hours: 8));
  return '${p.year}-${p.month.toString().padLeft(2, '0')}-${p.day.toString().padLeft(2, '0')} ${p.hour.toString().padLeft(2, '0')}:${p.minute.toString().padLeft(2, '0')} (Philippine time)';
}
