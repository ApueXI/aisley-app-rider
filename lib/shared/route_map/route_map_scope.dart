import 'package:flutter/widgets.dart';

import '../../core/security/courier_map_security.dart';
import 'route_map_data.dart';

typedef RouteMapBuilder = Widget Function(
  BuildContext context,
  RouteMapData data,
  VoidCallback onFailure,
);

class RouteMapScope extends InheritedWidget {
  const RouteMapScope({
    required this.security,
    required super.child,
    this.renderer,
    super.key,
  });
  final CourierMapSecurity security;
  final RouteMapBuilder? renderer;
  static RouteMapScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RouteMapScope>();
  @override
  bool updateShouldNotify(RouteMapScope oldWidget) =>
      security != oldWidget.security || renderer != oldWidget.renderer;
}
