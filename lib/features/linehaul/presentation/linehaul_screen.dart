import 'package:flutter/material.dart';

import '../../../shared/presentation/courier_section_header.dart';
import '../../../shared/presentation/courier_surface_card.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../policy/presentation/controllers/policy_controller.dart';
import '../../policy/presentation/policy_screen.dart';
import 'linehaul_controller.dart';
import 'linehaul_trip_detail.dart';

class LinehaulScreen extends StatefulWidget {
  const LinehaulScreen({
    required this.controller,
    required this.authController,
    this.policyController,
    super.key,
  });
  final LinehaulController controller;
  final AuthController authController;
  final PolicyController? policyController;
  @override
  State<LinehaulScreen> createState() => _LinehaulScreenState();
}

class _LinehaulScreenState extends State<LinehaulScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.controller.load();
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      return PopScope(
        canPop: !c.saving,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Linehaul jobs'),
            actions: [
              IconButton(
                tooltip: 'Refresh linehaul jobs',
                onPressed: c.loading || c.saving || c.coolingDown
                    ? null
                    : c.load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: RefreshIndicator(
                onRefresh: c.load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    const CourierSectionHeader(
                      title: 'Assigned hub transfers',
                      subtitle: 'Report physical departure and arrival. Logistics confirms cargo receipt and unloading.',
                    ),
                    if (c.loading || c.saving)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: LinearProgressIndicator(),
                      ),
                    if (c.error case final error?) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            error,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ),
                      if (widget.policyController != null)
                        TextButton(
                          onPressed: c.saving ? null : _policies,
                          child: const Text('Review policies'),
                        ),
                    ],
                    if (c.uncertain)
                      Wrap(
                        spacing: 8,
                        children: [
                          FilledButton(
                            onPressed: c.saving || c.coolingDown
                                ? null
                                : c.retry,
                            child: const Text('Retry same confirmation'),
                          ),
                          TextButton(
                            onPressed: c.loading || c.saving || c.coolingDown
                                ? null
                                : c.load,
                            child: const Text('Check server state'),
                          ),
                        ],
                      ),
                    if (!c.loading && c.trips.isEmpty && c.error == null)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'No assigned linehaul trips. Pull to refresh.',
                        ),
                      ),
                    for (final item in c.trips)
                      CourierSurfaceCard(
                        padding: EdgeInsets.zero,
                        onTap: c.locked || c.loading
                            ? null
                            : () => _openTrip(item.id),
                        child: ListTile(
                          selected: item.id == c.selectedId,
                          title: Text(
                            item.direction == 'return'
                                ? 'Return linehaul job'
                                : 'Outbound linehaul job',
                          ),
                          subtitle: Text(
                            '${item.fromHub} → ${item.toHub}\n${item.statusLabel} · ${item.parcelCount} ${item.parcelCount == 1 ? 'parcel' : 'parcels'}',
                          ),
                          trailing: item.id == c.selectedId
                              ? const Icon(Icons.chevron_right)
                              : const Icon(Icons.chevron_right),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  Future<void> _openTrip(String id) async {
    final controller = widget.controller;
    final routeLoad = controller.select(id);
    if (controller.selectedId != id) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LinehaulTripDetailScreen(
          tripId: id,
          controller: controller,
          authController: widget.authController,
          policyController: widget.policyController,
        ),
      ),
    );
    await routeLoad;
  }

  Future<void> _policies() async {
    final policy = widget.policyController;
    if (policy == null) return;
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
