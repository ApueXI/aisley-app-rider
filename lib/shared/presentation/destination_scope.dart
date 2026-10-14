import 'package:flutter/material.dart';

/// Session-only root visibility and navigation supplied by the Courier shell.
class DestinationScope extends InheritedWidget {
  const DestinationScope({
    required this.visible,
    this.onBack,
    required super.child,
    super.key,
  });

  final bool visible;
  final VoidCallback? onBack;

  static DestinationScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DestinationScope>();

  @override
  bool updateShouldNotify(DestinationScope oldWidget) =>
      visible != oldWidget.visible || onBack != oldWidget.onBack;
}

Widget? destinationBackButton(BuildContext context) {
  final onBack = DestinationScope.of(context)?.onBack;
  return onBack == null
      ? null
      : IconButton(
          tooltip: 'Back to Work',
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back),
        );
}

/// Notifies roots when a detail, camera, form, or map covers the shell.
final courierRouteObserver = RouteObserver<ModalRoute<void>>();
