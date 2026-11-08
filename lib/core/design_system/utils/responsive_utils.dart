import 'package:flutter/material.dart';
import '../tokens/app_spacing.dart';

/// Device viewport classification.
enum DeviceFormFactor { mobile, tablet, desktop }

/// Responsive layout utilities optimized for Mobile portrait ergonomics,
/// Tablet multi-column layouts, and centered Web views (max 1140 px).
abstract final class ResponsiveUtils {
  static const double mobileBreakpoint = 600.0;
  static const double tabletBreakpoint = 1024.0;

  static DeviceFormFactor formFactorOf(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= tabletBreakpoint) return DeviceFormFactor.desktop;
    if (width >= mobileBreakpoint) return DeviceFormFactor.tablet;
    return DeviceFormFactor.mobile;
  }

  static bool isMobile(BuildContext context) =>
      formFactorOf(context) == DeviceFormFactor.mobile;

  static bool isTabletOrLarger(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= mobileBreakpoint;

  static EdgeInsets responsiveHorizontalPadding(BuildContext context) {
    final factor = formFactorOf(context);
    return switch (factor) {
      DeviceFormFactor.mobile => const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
      ),
      DeviceFormFactor.tablet => const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
      ),
      DeviceFormFactor.desktop => const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
      ),
    };
  }
}

/// Centers content within [maxWidth] so mobile FinTech components never
/// stretch excessively on tablets or desktop/Web viewports.
class ResponsiveConstrainedBox extends StatelessWidget {
  const ResponsiveConstrainedBox({
    super.key,
    required this.child,
    this.maxWidth = AppSpacing.maxContentWidth,
    this.padding,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final content = padding != null
        ? Padding(padding: padding!, child: child)
        : child;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: content,
      ),
    );
  }
}
