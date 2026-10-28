import 'package:flutter/material.dart';

/// A section title that can move its trailing content below the title.
class CourierSectionHeader extends StatelessWidget {
  const CourierSectionHeader({
    required this.title,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final stackTrailing =
            constraints.maxWidth < 330 ||
            !constraints.maxWidth.isFinite ||
            textScale > 1.25;

        if (trailing == null) {
          return _titleContent(context);
        }

        if (stackTrailing) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _titleContent(context),
              const SizedBox(height: 4),
              trailing!,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _titleContent(context)),
            const SizedBox(width: 12),
            Flexible(child: trailing!),
          ],
        );
      },
    );
  }

  Widget _titleContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        if (subtitle case final text?) ...[
          const SizedBox(height: 4),
          Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
