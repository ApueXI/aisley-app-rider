import 'package:flutter/material.dart';

import '../../core/security/courier_map_security.dart';
import 'route_map_scope.dart';

/// Removes route screens and their private widget arguments after logout or
/// account denial, including routes pushed above the app's identity gate.
class RouteSessionBoundary extends StatefulWidget {
  const RouteSessionBoundary({required this.child, super.key});
  final Widget child;

  @override
  State<RouteSessionBoundary> createState() => _RouteSessionBoundaryState();
}

class _RouteSessionBoundaryState extends State<RouteSessionBoundary> {
  CourierMapSecurity? _security;
  bool _ended = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final security = RouteMapScope.maybeOf(context)?.security;
    if (security != _security) {
      _security?.removeListener(_sessionEnded);
      _security = security;
      security?.addListener(_sessionEnded);
    }
  }

  void _sessionEnded() {
    if (!mounted || _ended) return;
    setState(() => _ended = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    });
  }

  @override
  void dispose() {
    _security?.removeListener(_sessionEnded);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _ended ? const SizedBox.shrink() : widget.child;
}
