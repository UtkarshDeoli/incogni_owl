import 'package:flutter/material.dart';

class AppTheme {
  // Professional color scheme - anonymous & sleek feel
  static const Color _darkBg = Color(0xFF222831);
  static const Color _darkSurface = Color(0xFF393E46);
  static const Color _darkSurfaceVariant = Color(0xFF2A2D35);
  static const Color _glassAccent = Color(0xFF00ADB5);
  static const Color _glassAccentSecondary = Color(0xFF00C9D7);
  static const Color _textPrimary = Color(0xFFEEEEEE);
  static const Color _textSecondary = Color(0xFFB0B0B0);
  static const Color _border = Color(0xFF3A4050);

  // Get the dark theme
  static ThemeData getDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _darkBg,
      colorScheme: ColorScheme.dark(
        primary: _glassAccent,
        secondary: _glassAccentSecondary,
        tertiary: _glassAccent,
        surface: _darkSurface,
        surfaceContainerHighest: _darkSurfaceVariant,
        outline: _border,
        onPrimary: _darkBg,
        onSecondary: Colors.white,
        onSurface: _textPrimary,
        error: const Color(0xFFFF6B6B),
      ),
      // Theme for ElevatedButton (glass style)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _darkSurfaceVariant.withOpacity(0.7),
          foregroundColor: _textPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(
              color: _glassAccent,
              width: 1.5,
            ),
          ),
        ),
      ),
      // Theme for TextButton
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _glassAccent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      // Theme for OutlinedButton
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _glassAccent,
          side: const BorderSide(
            color: _glassAccent,
            width: 1.5,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkSurfaceVariant.withOpacity(0.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _glassAccent, width: 2),
        ),
        hintStyle: const TextStyle(color: _textSecondary),
        labelStyle: const TextStyle(color: _textSecondary),
      ),
      // Typography
      typography: Typography.material2021(),
      textTheme: _buildTextTheme(),
      // Dialog theme
      dialogTheme: DialogThemeData(
        backgroundColor: _darkSurface,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(
            color: _glassAccent,
            width: 0.5,
          ),
        ),
      ),
      // App bar theme
      appBarTheme: const AppBarTheme(
        backgroundColor: _darkSurfaceVariant,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          color: _textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: _glassAccent),
      ),
      // Chip theme
      chipTheme: ChipThemeData(
        backgroundColor: _darkSurfaceVariant,
        disabledColor: _darkSurfaceVariant.withOpacity(0.5),
        selectedColor: _glassAccent,
        labelPadding: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        side: const BorderSide(
          color: _border,
          width: 1,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        brightness: Brightness.dark,
        labelStyle: const TextStyle(
          color: _textSecondary,
          fontSize: 13,
        ),
      ),
    );
  }

  // Text theme
  static TextTheme _buildTextTheme() {
    return const TextTheme(
      displayLarge: TextStyle(
        color: _textPrimary,
        fontSize: 32,
        fontWeight: FontWeight.bold,
      ),
      displayMedium: TextStyle(
        color: _textPrimary,
        fontSize: 28,
        fontWeight: FontWeight.bold,
      ),
      displaySmall: TextStyle(
        color: _textPrimary,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
      headlineMedium: TextStyle(
        color: _textPrimary,
        fontSize: 22,
        fontWeight: FontWeight.w600,
      ),
      headlineSmall: TextStyle(
        color: _textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: TextStyle(
        color: _textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(
        color: _textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      titleSmall: TextStyle(
        color: _textSecondary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: TextStyle(
        color: _textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.normal,
      ),
      bodyMedium: TextStyle(
        color: _textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.normal,
      ),
      bodySmall: TextStyle(
        color: _textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.normal,
      ),
      labelLarge: TextStyle(
        color: _glassAccent,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: TextStyle(
        color: _glassAccent,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      labelSmall: TextStyle(
        color: _textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  // Color constants for easy access in widgets
  static const Color darkBg = _darkBg;
  static const Color darkSurface = _darkSurface;
  static const Color darkSurfaceVariant = _darkSurfaceVariant;
  static const Color glassAccent = _glassAccent;
  static const Color glassAccentSecondary = _glassAccentSecondary;
  static const Color textPrimary = _textPrimary;
  static const Color textSecondary = _textSecondary;
  static const Color border = _border;
}
