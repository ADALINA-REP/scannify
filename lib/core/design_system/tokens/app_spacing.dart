import 'package:flutter/material.dart';

/// Standardized spacing, border radius, and touch-target ergonomics tokens.
abstract final class AppSpacing {
  static const double xxs = 4.0;
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 48.0;

  /// Mandatory minimum interactive touch target dimension (48 x 48 dp).
  static const double minTouchTarget = 48.0;

  /// Standard horizontal screen padding on mobile portrait layouts.
  static const EdgeInsets screenHorizontalPadding = EdgeInsets.symmetric(
    horizontal: md,
  );

  /// Maximum content width for centered tablet/Web dashboard layouts.
  static const double maxContentWidth = 1140.0;
  static const double maxNarrowContentWidth = 680.0;
}

/// Standardized corner radii for Scannify cards, inputs, chips, and sheets.
abstract final class AppRadii {
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
  static const double pill = 999.0;

  static const BorderRadius cardBorderRadius = BorderRadius.all(
    Radius.circular(lg),
  );
  static const BorderRadius buttonBorderRadius = BorderRadius.all(
    Radius.circular(md),
  );
  static const BorderRadius chipBorderRadius = BorderRadius.all(
    Radius.circular(pill),
  );
  static const BorderRadius sheetTopBorderRadius = BorderRadius.vertical(
    top: Radius.circular(xl),
  );
}
