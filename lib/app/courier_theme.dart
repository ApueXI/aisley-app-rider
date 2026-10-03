import 'package:flutter/material.dart';

ThemeData buildCourierTheme(Brightness brightness) {
  const brandPrimary = Color(0xFFE6007A);
  final primary = brightness == Brightness.light
      ? const Color(0xFFC00065)
      : const Color(0xFFFF85BD);
  const deepPurple = Color(0xFF4C1268);
  final error = brightness == Brightness.light
      ? const Color(0xFFB3261E)
      : const Color(0xFFFFB4AB);
  const warning = Color(0xFFFF8800);
  final scheme =
      ColorScheme.fromSeed(
        seedColor: brandPrimary,
        brightness: brightness,
      ).copyWith(
        primary: primary,
        onPrimary: brightness == Brightness.light ? Colors.white : Colors.black,
        secondary: brightness == Brightness.light
            ? deepPurple
            : const Color(0xFFDCB0F1),
        onSecondary: brightness == Brightness.light
            ? Colors.white
            : Colors.black,
        error: error,
        onError: brightness == Brightness.light ? Colors.white : Colors.black,
      );

  return ThemeData(
    brightness: brightness,
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: brightness == Brightness.light
        ? const Color(0xFFF9F7FA)
        : const Color(0xFF151117),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: brightness == Brightness.light
          ? Colors.white
          : const Color(0xFF211B23),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.error, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: deepPurple,
      contentTextStyle: const TextStyle(color: Colors.white),
    ),
    extensions: <ThemeExtension<dynamic>>[
      const _CourierTheme(warning: warning),
    ],
  );
}

class _CourierTheme extends ThemeExtension<_CourierTheme> {
  const _CourierTheme({required this.warning});

  final Color warning;

  @override
  _CourierTheme copyWith({Color? warning}) {
    return _CourierTheme(warning: warning ?? this.warning);
  }

  @override
  _CourierTheme lerp(ThemeExtension<_CourierTheme>? other, double t) {
    if (other is! _CourierTheme) {
      return this;
    }
    return _CourierTheme(
      warning: Color.lerp(warning, other.warning, t) ?? warning,
    );
  }
}
