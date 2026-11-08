import 'package:flutter/material.dart';

/// FinTech typographic hierarchy for Scannify.
///
/// Uses `Inter` / `Manrope` with native system fallbacks and enforces
/// [FontFeature.tabularFigures] on monetary amounts so digits align cleanly
/// in lists and never jitter during counter animations.
abstract final class AppTypography {
  static const String primaryFontFamily = 'Inter';
  static const List<String> fontFallbacks = <String>[
    'Manrope',
    'SF Pro Display',
    'SF Pro Text',
    'Roboto',
    'Segoe UI',
    'sans-serif',
  ];

  /// Hero financial amount on the Home Dashboard summary card (e.g. `1 428,50 €`).
  static TextStyle heroAmount(Color color) => TextStyle(
    fontFamily: primaryFontFamily,
    fontFamilyFallback: fontFallbacks,
    fontSize: 36,
    height: 1.15,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.0,
    color: color,
    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
  );

  /// Medium financial amount used in ReceiptCard and summary metrics.
  static TextStyle cardAmount(Color color) => TextStyle(
    fontFamily: primaryFontFamily,
    fontFamilyFallback: fontFallbacks,
    fontSize: 16,
    height: 1.25,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: color,
    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
  );

  /// builds a complete Material 3 [TextTheme] for the given [primaryText] and [secondaryText] colors.
  static TextTheme buildTextTheme({
    required Color primaryText,
    required Color secondaryText,
  }) {
    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: primaryFontFamily,
        fontFamilyFallback: fontFallbacks,
        fontSize: 36,
        height: 1.15,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.0,
        color: primaryText,
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      ),
      displayMedium: TextStyle(
        fontFamily: primaryFontFamily,
        fontFamilyFallback: fontFallbacks,
        fontSize: 28,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.7,
        color: primaryText,
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      ),
      headlineLarge: TextStyle(
        fontFamily: primaryFontFamily,
        fontFamilyFallback: fontFallbacks,
        fontSize: 24,
        height: 1.25,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: primaryText,
      ),
      headlineMedium: TextStyle(
        fontFamily: primaryFontFamily,
        fontFamilyFallback: fontFallbacks,
        fontSize: 20,
        height: 1.3,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: primaryText,
      ),
      titleLarge: TextStyle(
        fontFamily: primaryFontFamily,
        fontFamilyFallback: fontFallbacks,
        fontSize: 18,
        height: 1.35,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: primaryText,
      ),
      titleMedium: TextStyle(
        fontFamily: primaryFontFamily,
        fontFamilyFallback: fontFallbacks,
        fontSize: 16,
        height: 1.4,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: primaryText,
      ),
      titleSmall: TextStyle(
        fontFamily: primaryFontFamily,
        fontFamilyFallback: fontFallbacks,
        fontSize: 14,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: primaryText,
      ),
      bodyLarge: TextStyle(
        fontFamily: primaryFontFamily,
        fontFamilyFallback: fontFallbacks,
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: primaryText,
      ),
      bodyMedium: TextStyle(
        fontFamily: primaryFontFamily,
        fontFamilyFallback: fontFallbacks,
        fontSize: 14,
        height: 1.45,
        fontWeight: FontWeight.w400,
        color: secondaryText,
      ),
      bodySmall: TextStyle(
        fontFamily: primaryFontFamily,
        fontFamilyFallback: fontFallbacks,
        fontSize: 12,
        height: 1.4,
        fontWeight: FontWeight.w400,
        color: secondaryText,
      ),
      labelLarge: TextStyle(
        fontFamily: primaryFontFamily,
        fontFamilyFallback: fontFallbacks,
        fontSize: 14,
        height: 1.25,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: primaryText,
      ),
      labelMedium: TextStyle(
        fontFamily: primaryFontFamily,
        fontFamilyFallback: fontFallbacks,
        fontSize: 12,
        height: 1.25,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: secondaryText,
      ),
      labelSmall: TextStyle(
        fontFamily: primaryFontFamily,
        fontFamilyFallback: fontFallbacks,
        fontSize: 11,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        color: secondaryText,
      ),
    );
  }
}
