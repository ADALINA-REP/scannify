import 'package:flutter/material.dart';

/// Scannify signature color tokens and semantic theme extension.
///
/// Built around the signature Emerald Green (`#10B981`) and Deep Obsidian
/// Slate (`#0B0D0C`) dark palette, paired with a high-contrast FinTech light palette.
abstract final class AppColors {
  // ---------------------------------------------------------------------------
  // Brand Signature Emerald
  // ---------------------------------------------------------------------------
  static const Color primaryEmerald = Color(0xFF10B981);
  static const Color secondaryEmerald = Color(0xFF34D399);
  static const Color deepEmerald = Color(0xFF059669);
  static const Color emeraldGlow = Color(0x2610B981);

  // ---------------------------------------------------------------------------
  // Default Dark Theme Palette (Mandatory Specification)
  // ---------------------------------------------------------------------------
  static const Color darkPrimaryBackground = Color(0xFF0B0D0C);
  static const Color darkSecondaryBackground = Color(0xFF121614);
  static const Color darkCardBackground = Color(0xFF1B211E);
  static const Color darkElevatedSurface = Color(0xFF222A26);
  static const Color darkPrimaryText = Color(0xFFF5F7F5);
  static const Color darkSecondaryText = Color(0xFFA1AAA4);
  static const Color darkMutedText = Color(0xFF6E7872);
  static const Color darkBorder = Color(0xFF29332D);
  static const Color darkError = Color(0xFFF87171);
  static const Color darkWarning = Color(0xFFFBBF24);
  static const Color darkSuccess = Color(0xFF10B981);

  // ---------------------------------------------------------------------------
  // Harmonious Light Theme Palette
  // ---------------------------------------------------------------------------
  static const Color lightPrimaryBackground = Color(0xFFF6F9F7);
  static const Color lightSecondaryBackground = Color(0xFFEDF2EF);
  static const Color lightCardBackground = Color(0xFFFFFFFF);
  static const Color lightElevatedSurface = Color(0xFFF0F5F2);
  static const Color lightPrimaryText = Color(0xFF0F1713);
  static const Color lightSecondaryText = Color(0xFF526058);
  static const Color lightMutedText = Color(0xFF7A8880);
  static const Color lightBorder = Color(0xFFDCE5DF);
  static const Color lightError = Color(0xFFDC2626);
  static const Color lightWarning = Color(0xFFD97706);
  static const Color lightSuccess = Color(0xFF059669);
}

/// Custom [ThemeExtension] exposing Scannify's semantic surface, text, border,
/// and status colors with smooth theme interpolation.
@immutable
class ScannifyThemeColors extends ThemeExtension<ScannifyThemeColors> {
  const ScannifyThemeColors({
    required this.primaryBackground,
    required this.secondaryBackground,
    required this.cardBackground,
    required this.elevatedSurface,
    required this.primaryEmerald,
    required this.secondaryEmerald,
    required this.primaryText,
    required this.secondaryText,
    required this.mutedText,
    required this.border,
    required this.error,
    required this.warning,
    required this.success,
    required this.isDark,
  });

  final Color primaryBackground;
  final Color secondaryBackground;
  final Color cardBackground;
  final Color elevatedSurface;
  final Color primaryEmerald;
  final Color secondaryEmerald;
  final Color primaryText;
  final Color secondaryText;
  final Color mutedText;
  final Color border;
  final Color error;
  final Color warning;
  final Color success;
  final bool isDark;

  static const ScannifyThemeColors dark = ScannifyThemeColors(
    primaryBackground: AppColors.darkPrimaryBackground,
    secondaryBackground: AppColors.darkSecondaryBackground,
    cardBackground: AppColors.darkCardBackground,
    elevatedSurface: AppColors.darkElevatedSurface,
    primaryEmerald: AppColors.primaryEmerald,
    secondaryEmerald: AppColors.secondaryEmerald,
    primaryText: AppColors.darkPrimaryText,
    secondaryText: AppColors.darkSecondaryText,
    mutedText: AppColors.darkMutedText,
    border: AppColors.darkBorder,
    error: AppColors.darkError,
    warning: AppColors.darkWarning,
    success: AppColors.darkSuccess,
    isDark: true,
  );

  static const ScannifyThemeColors light = ScannifyThemeColors(
    primaryBackground: AppColors.lightPrimaryBackground,
    secondaryBackground: AppColors.lightSecondaryBackground,
    cardBackground: AppColors.lightCardBackground,
    elevatedSurface: AppColors.lightElevatedSurface,
    primaryEmerald: AppColors.deepEmerald,
    secondaryEmerald: AppColors.primaryEmerald,
    primaryText: AppColors.lightPrimaryText,
    secondaryText: AppColors.lightSecondaryText,
    mutedText: AppColors.lightMutedText,
    border: AppColors.lightBorder,
    error: AppColors.lightError,
    warning: AppColors.lightWarning,
    success: AppColors.lightSuccess,
    isDark: false,
  );

  @override
  ScannifyThemeColors copyWith({
    Color? primaryBackground,
    Color? secondaryBackground,
    Color? cardBackground,
    Color? elevatedSurface,
    Color? primaryEmerald,
    Color? secondaryEmerald,
    Color? primaryText,
    Color? secondaryText,
    Color? mutedText,
    Color? border,
    Color? error,
    Color? warning,
    Color? success,
    bool? isDark,
  }) {
    return ScannifyThemeColors(
      primaryBackground: primaryBackground ?? this.primaryBackground,
      secondaryBackground: secondaryBackground ?? this.secondaryBackground,
      cardBackground: cardBackground ?? this.cardBackground,
      elevatedSurface: elevatedSurface ?? this.elevatedSurface,
      primaryEmerald: primaryEmerald ?? this.primaryEmerald,
      secondaryEmerald: secondaryEmerald ?? this.secondaryEmerald,
      primaryText: primaryText ?? this.primaryText,
      secondaryText: secondaryText ?? this.secondaryText,
      mutedText: mutedText ?? this.mutedText,
      border: border ?? this.border,
      error: error ?? this.error,
      warning: warning ?? this.warning,
      success: success ?? this.success,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  ScannifyThemeColors lerp(
    covariant ThemeExtension<ScannifyThemeColors>? other,
    double t,
  ) {
    if (other is! ScannifyThemeColors) return this;
    return ScannifyThemeColors(
      primaryBackground: Color.lerp(
        primaryBackground,
        other.primaryBackground,
        t,
      )!,
      secondaryBackground: Color.lerp(
        secondaryBackground,
        other.secondaryBackground,
        t,
      )!,
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      elevatedSurface: Color.lerp(elevatedSurface, other.elevatedSurface, t)!,
      primaryEmerald: Color.lerp(primaryEmerald, other.primaryEmerald, t)!,
      secondaryEmerald: Color.lerp(
        secondaryEmerald,
        other.secondaryEmerald,
        t,
      )!,
      primaryText: Color.lerp(primaryText, other.primaryText, t)!,
      secondaryText: Color.lerp(secondaryText, other.secondaryText, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      border: Color.lerp(border, other.border, t)!,
      error: Color.lerp(error, other.error, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      success: Color.lerp(success, other.success, t)!,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

/// Convenience extension on [BuildContext] to access [ScannifyThemeColors].
extension ScannifyThemeContextExtension on BuildContext {
  ScannifyThemeColors get scannifyColors =>
      Theme.of(this).extension<ScannifyThemeColors>() ??
      ScannifyThemeColors.dark;
}
