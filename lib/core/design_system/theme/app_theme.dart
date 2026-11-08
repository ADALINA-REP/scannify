import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// Constructs Scannify's customized Material Design 3 Dark and Light [ThemeData].
abstract final class AppTheme {
  static ThemeData get darkTheme => _buildTheme(ScannifyThemeColors.dark);
  static ThemeData get lightTheme => _buildTheme(ScannifyThemeColors.light);

  static ThemeData _buildTheme(ScannifyThemeColors palette) {
    final brightness = palette.isDark ? Brightness.dark : Brightness.light;
    final textTheme = AppTypography.buildTextTheme(
      primaryText: palette.primaryText,
      secondaryText: palette.secondaryText,
    );

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: palette.primaryEmerald,
      onPrimary: const Color(0xFF041F15),
      primaryContainer: palette.primaryEmerald.withValues(alpha: 0.16),
      onPrimaryContainer: palette.secondaryEmerald,
      secondary: palette.secondaryEmerald,
      onSecondary: const Color(0xFF041F15),
      secondaryContainer: palette.elevatedSurface,
      onSecondaryContainer: palette.primaryText,
      error: palette.error,
      onError: Colors.white,
      surface: palette.cardBackground,
      onSurface: palette.primaryText,
      onSurfaceVariant: palette.secondaryText,
      outline: palette.border,
      outlineVariant: palette.border.withValues(alpha: 0.6),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.primaryBackground,
      canvasColor: palette.secondaryBackground,
      dividerColor: palette.border,
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[palette],
      appBarTheme: AppBarTheme(
        backgroundColor: palette.primaryBackground,
        foregroundColor: palette.primaryText,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        systemOverlayStyle: palette.isDark
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: palette.secondaryBackground,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: palette.secondaryBackground,
              ),
      ),
      cardTheme: CardThemeData(
        color: palette.cardBackground,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.cardBorderRadius,
          side: BorderSide(color: palette.border, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.primaryEmerald,
          foregroundColor: const Color(0xFF041F15),
          disabledBackgroundColor: palette.elevatedSurface,
          disabledForegroundColor: palette.mutedText,
          elevation: 0,
          minimumSize: const Size(
            AppSpacing.minTouchTarget,
            AppSpacing.minTouchTarget,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm + 2,
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadii.buttonBorderRadius,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.primaryText,
          minimumSize: const Size(
            AppSpacing.minTouchTarget,
            AppSpacing.minTouchTarget,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm + 2,
          ),
          side: BorderSide(color: palette.border, width: 1.2),
          textStyle: textTheme.labelLarge,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadii.buttonBorderRadius,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.primaryEmerald,
          minimumSize: const Size(
            AppSpacing.minTouchTarget,
            AppSpacing.minTouchTarget,
          ),
          textStyle: textTheme.labelLarge,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadii.buttonBorderRadius,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.secondaryBackground,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: palette.mutedText),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: palette.secondaryText,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadii.buttonBorderRadius,
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.buttonBorderRadius,
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.buttonBorderRadius,
          borderSide: BorderSide(color: palette.primaryEmerald, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadii.buttonBorderRadius,
          borderSide: BorderSide(color: palette.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadii.buttonBorderRadius,
          borderSide: BorderSide(color: palette.error, width: 1.6),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(AppRadii.xl)),
          side: BorderSide(color: palette.border),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.cardBackground,
        modalBackgroundColor: palette.cardBackground,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadii.sheetTopBorderRadius,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.elevatedSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: palette.primaryText,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.buttonBorderRadius,
          side: BorderSide(color: palette.border),
        ),
      ),
    );
  }
}
