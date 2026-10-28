import 'package:flutter/material.dart';

import '../../app/courier_theme.dart';

enum CourierStatusTone { neutral, info, success, warning, critical }

/// A readable status label with a restrained semantic surface treatment.
class CourierStatusBadge extends StatelessWidget {
  const CourierStatusBadge({
    required this.label,
    this.tone = CourierStatusTone.neutral,
    super.key,
  });

  final String label;
  final CourierStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = theme.extension<CourierThemeTokens>();
    final (background, foreground, border) = switch (tone) {
      CourierStatusTone.neutral => (
        scheme.surfaceContainerHighest,
        scheme.onSurface,
        scheme.outlineVariant,
      ),
      CourierStatusTone.info => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
        scheme.secondary,
      ),
      CourierStatusTone.success => (
        tokens?.successBackground ?? scheme.tertiaryContainer,
        tokens?.onSuccessBackground ?? scheme.onTertiaryContainer,
        tokens?.successBorder ?? scheme.tertiary,
      ),
      CourierStatusTone.warning => (
        scheme.surfaceContainerHigh,
        scheme.onSurface,
        tokens?.warning ?? scheme.outline,
      ),
      CourierStatusTone.critical => (
        scheme.errorContainer,
        scheme.onErrorContainer,
        scheme.error,
      ),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(color: foreground),
        ),
      ),
    );
  }
}
