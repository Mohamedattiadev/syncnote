import 'package:flutter/material.dart';

/// Doom One dark palette — matches user's nvim colorscheme.
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

  static ThemeData dark() {
    final scheme = ColorScheme.dark(
      surface: surface,
      primary: primary,
      secondary: accent,
      error: error,
      onSurface: text,
      onPrimary: base,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(
        surface: base,
        surfaceContainer: surface,
        surfaceContainerHigh: overlay,
        surfaceContainerHighest: overlay,
        onSurface: text,
        outline: overlay,
        outlineVariant: overlay,
      ),
      scaffoldBackgroundColor: base,
      canvasColor: base,
      dialogTheme: const DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: const CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      bottomAppBarTheme: const BottomAppBarThemeData(color: base),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: base,
        surfaceTintColor: Colors.transparent,
        indicatorColor: primary,
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: surface,
        selectedColor: primary,
        surfaceTintColor: Colors.transparent,
        side: BorderSide(color: overlay),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: base,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: const TextStyle(color: muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: overlay),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: overlay),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: text),
        bodyMedium: TextStyle(color: text),
        titleLarge: TextStyle(color: text, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: text, fontWeight: FontWeight.w600),
      ),
      iconTheme: const IconThemeData(color: text),
      dividerColor: overlay,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surface,
        contentTextStyle: const TextStyle(color: text),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
