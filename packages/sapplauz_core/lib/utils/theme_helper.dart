import 'package:flutter/material.dart';

/// SApplauz brand tema (shared za mobile + desktop)
/// Paleta (ključne boje):
/// - #832D0B (primary)
/// - #EF7443 (secondary)
/// - #F7B9A1 (tertiary)
/// - #FDEEE8 (background)
class ThemeHelper {
  // Brand palette
  static const Color primaryColor = Color(0xFF832D0B);
  static const Color secondaryColor = Color(0xFFEF7443);
  static const Color tertiaryColor = Color(0xFFF7B9A1);
  static const Color backgroundColor = Color(0xFFFDEEE8);

  // Surfaces / text
  static const Color surfaceColor = Colors.white;
  static const Color textPrimaryColor = Color(0xFF1E1A18);
  static const Color textSecondaryColor = Color(0xFF5A4B45);

  // Status colors (ograničeno na brand nijanse)
  static const Color soldOutColor = primaryColor; // Rasprodano
  static const Color lastSeatsColor = secondaryColor; // Posljednja mjesta
  static const Color currentlyShowingColor = secondaryColor; // Trenutno se izvodi
  static const Color availableColor = primaryColor; // Dostupno

  static ColorScheme get lightColorScheme {
    return ColorScheme(
      brightness: Brightness.light,
      primary: primaryColor,
      onPrimary: Colors.white,
      secondary: secondaryColor,
      onSecondary: Colors.white,
      tertiary: tertiaryColor,
      onTertiary: primaryColor,
      error: secondaryColor, // držimo u brand paleti
      onError: Colors.white,
      surface: surfaceColor,
      onSurface: textPrimaryColor,
      // Material 3 extended:
      primaryContainer: tertiaryColor,
      onPrimaryContainer: primaryColor,
      secondaryContainer: tertiaryColor,
      onSecondaryContainer: primaryColor,
      tertiaryContainer: tertiaryColor,
      onTertiaryContainer: primaryColor,
      surfaceContainerHighest: backgroundColor,
      outline: tertiaryColor,
      outlineVariant: tertiaryColor,
      shadow: Colors.black26,
      scrim: Colors.black54,
      inverseSurface: textPrimaryColor,
      onInverseSurface: backgroundColor,
      inversePrimary: secondaryColor,
      surfaceTint: primaryColor,
    );
  }

  static ThemeData get lightTheme {
    final cs = lightColorScheme;
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: textPrimaryColor,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: primaryColor,
        contentTextStyle: TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.primary,
          side: BorderSide(color: cs.primary, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cs.primary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: cs.secondary,
        foregroundColor: cs.onSecondary,
      ),
      dividerTheme: DividerThemeData(color: tertiaryColor.withOpacity(0.8)),
      textTheme: const TextTheme().apply(
        bodyColor: textPrimaryColor,
        displayColor: textPrimaryColor,
      ),
    );
  }

  static Color getPerformanceStatusColor({
    required bool isSoldOut,
    required bool isAlmostSoldOut,
    required bool isCurrentlyShowing,
  }) {
    if (isSoldOut) return soldOutColor;
    if (isCurrentlyShowing) return currentlyShowingColor;
    if (isAlmostSoldOut) return lastSeatsColor;
    return availableColor;
  }

  static String getPerformanceStatusText({
    required bool isSoldOut,
    required bool isAlmostSoldOut,
    required bool isCurrentlyShowing,
  }) {
    if (isSoldOut) return 'Rasprodano';
    if (isCurrentlyShowing) return 'Trenutno se izvodi';
    if (isAlmostSoldOut) return 'Posljednja mjesta';
    return 'Dostupno';
  }

  static IconData getPerformanceStatusIcon({
    required bool isSoldOut,
    required bool isAlmostSoldOut,
    required bool isCurrentlyShowing,
  }) {
    if (isSoldOut) return Icons.event_busy;
    if (isCurrentlyShowing) return Icons.play_circle_filled;
    if (isAlmostSoldOut) return Icons.warning;
    return Icons.check_circle;
  }
}

