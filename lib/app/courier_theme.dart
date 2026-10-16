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
        surface: brightness == Brightness.light
            ? const Color(0xFFFFFFFF)
            : const Color(0xFF1C1C1E),
        surfaceContainerLowest: brightness == Brightness.light
            ? const Color(0xFFFFFFFF)
            : const Color(0xFF141416),
        surfaceContainerLow: brightness == Brightness.light
            ? const Color(0xFFF7F7F8)
            : const Color(0xFF1C1C1E),
        surfaceContainer: brightness == Brightness.light
            ? const Color(0xFFF5F5F6)
            : const Color(0xFF242428),
        surfaceContainerHigh: brightness == Brightness.light
            ? const Color(0xFFF2F2F4)
            : const Color(0xFF2B2B30),
        surfaceContainerHighest: brightness == Brightness.light
            ? const Color(0xFFF0F0F2)
            : const Color(0xFF303034),
        onSurface: brightness == Brightness.light
            ? const Color(0xFF202024)
            : const Color(0xFFF3F3F5),
        onSurfaceVariant: brightness == Brightness.light
            ? const Color(0xFF55555D)
            : const Color(0xFFC6C6CE),
      );

  return ThemeData(
    brightness: brightness,
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: brightness == Brightness.light
        ? const Color(0xFFF7F7F8)
        : const Color(0xFF141416),
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: brightness == Brightness.light
          ? Colors.white
          : const Color(0xFF1C1C1E),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      errorMaxLines: 6,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: scheme.error, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    dialogTheme: DialogThemeData(backgroundColor: scheme.surface),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primaryContainer,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
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
