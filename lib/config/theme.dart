import 'package:flutter/material.dart';

import 'themes.dart';

/// Static Doom One colors (kept for backward compatibility across the code
/// base). Use [AppTheme.dark] for the dynamic version driven by ThemeManager.
class AppTheme {
  static const base = Color(0xFF282C34);
  static const surface = Color(0xFF21242B);
  static const overlay = Color(0xFF3F444A);
  static const text = Color(0xFFBBC2CF);
  static const muted = Color(0xFF5B6268);
  static const primary = Color(0xFF51AFEF);
  static const success = Color(0xFF98BE65);
  static const warning = Color(0xFFECBE7B);
  static const error = Color(0xFFFF6C6B);
  static const accent = Color(0xFFC678DD);

  static ThemeData dark([AppPalette p = kDoomOne]) {
    final scheme = ColorScheme.dark(
      surface: p.surface,
      primary: p.primary,
      secondary: p.accent,
      error: p.error,
      onSurface: p.text,
      onPrimary: p.base,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(
        surface: p.base,
        surfaceContainer: p.surface,
        surfaceContainerHigh: p.overlay,
        surfaceContainerHighest: p.overlay,
        onSurface: p.text,
        outline: p.overlay,
        outlineVariant: p.overlay,
      ),
      scaffoldBackgroundColor: p.base,
      canvasColor: p.base,
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      bottomAppBarTheme: BottomAppBarThemeData(color: p.base),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.base,
        surfaceTintColor: Colors.transparent,
        indicatorColor: p.primary,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surface,
        selectedColor: p.primary,
        surfaceTintColor: Colors.transparent,
        side: BorderSide(color: p.overlay),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.base,
        foregroundColor: p.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        hintStyle: TextStyle(color: p.muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: p.overlay),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: p.overlay),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: p.primary, width: 2),
        ),
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: p.text),
        bodyMedium: TextStyle(color: p.text),
        titleLarge: TextStyle(color: p.text, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: p.text, fontWeight: FontWeight.w600),
      ),
      iconTheme: IconThemeData(color: p.text),
      dividerColor: p.overlay,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.surface,
        contentTextStyle: TextStyle(color: p.text),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
