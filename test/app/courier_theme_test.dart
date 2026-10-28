import 'package:aisley_app/app/courier_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Courier theme preserves the platform palette and semantic colors', () {
    final light = buildCourierTheme(Brightness.light);
    final dark = buildCourierTheme(Brightness.dark);
    final lightTokens = light.extension<CourierThemeTokens>()!;
    final darkTokens = dark.extension<CourierThemeTokens>()!;

    expect(light.useMaterial3, isTrue);
    expect(dark.useMaterial3, isTrue);
    expect(light.colorScheme.primary, const Color(0xFFC00065));
    expect(dark.colorScheme.primary, const Color(0xFFFF85BD));
    expect(light.colorScheme.secondary, const Color(0xFF4C1268));
    expect(dark.colorScheme.secondary, const Color(0xFFDCB0F1));
    expect(light.colorScheme.outlineVariant, const Color(0xFFE2E2E6));
    expect(dark.colorScheme.outlineVariant, const Color(0xFF44444A));
    expect(lightTokens.successBackground, const Color(0xFFE8F5E9));
    expect(darkTokens.successBackground, const Color(0xFF173624));
    expect(lightTokens.warning, const Color(0xFFFF8800));

    expect(
      _contrastRatio(
        lightTokens.onSuccessBackground,
        lightTokens.successBackground,
      ),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrastRatio(
        darkTokens.onSuccessBackground,
        darkTokens.successBackground,
      ),
      greaterThanOrEqualTo(4.5),
    );
  });
}

double _contrastRatio(Color foreground, Color background) {
  final first = foreground.computeLuminance();
  final second = background.computeLuminance();
  final lighter = first > second ? first : second;
  final darker = first > second ? second : first;
  return (lighter + 0.05) / (darker + 0.05);
}
