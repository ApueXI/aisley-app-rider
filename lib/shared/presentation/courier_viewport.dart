import 'package:flutter/material.dart';

class CourierViewport extends StatelessWidget {
  const CourierViewport({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 840),
      child: LayoutBuilder(
        builder: (context, constraints) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(size: Size(constraints.maxWidth, constraints.maxHeight)),
          child: child,
        ),
      ),
    ),
  );
}
