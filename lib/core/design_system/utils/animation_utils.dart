import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Centralized micro-interaction durations, curves, reduced-motion checks,
/// haptic feedback helpers, and animated counter widgets.
abstract final class AppAnimations {
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration normal = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 450);

  static const Curve defaultCurve = Curves.easeOutCubic;
  static const Curve emphasizedCurve = Curves.easeInOutCubicEmphasized;

  /// Returns `true` if the user has enabled system reduced-motion accessibility preferences.
  static bool isReducedMotion(BuildContext context) {
    return MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  /// Resolves [duration] to [Duration.zero] when system reduced motion is active.
  static Duration resolveDuration(BuildContext context, Duration duration) {
    return isReducedMotion(context) ? Duration.zero : duration;
  }
}

/// Safe, subtle haptic feedback utility for mobile interactions.
abstract final class HapticsUtil {
  static Future<void> selection() async {
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }

  static Future<void> lightImpact() async {
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  static Future<void> mediumImpact() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }
}

/// Smoothly animates monetary amounts (in integer minor currency units) whenever
/// the total changes, while respecting reduced-motion preferences.
class AnimatedCurrencyCounter extends StatelessWidget {
  const AnimatedCurrencyCounter({
    super.key,
    required this.amountMinorUnits,
    required this.formatter,
    required this.style,
    this.duration = AppAnimations.slow,
  });

  final int amountMinorUnits;
  final String Function(int minorUnits) formatter;
  final TextStyle style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final effectiveDuration = AppAnimations.resolveDuration(context, duration);
    if (effectiveDuration == Duration.zero) {
      return Text(formatter(amountMinorUnits), style: style);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: amountMinorUnits.toDouble()),
      duration: effectiveDuration,
      curve: AppAnimations.defaultCurve,
      builder: (BuildContext context, double animatedValue, Widget? _) {
        return Text(formatter(animatedValue.round()), style: style);
      },
    );
  }
}

/// Subtle entrance transition (fade + slight upward slide) for ReceiptCards
/// and dashboard widgets, automatically bypassing animation when reduced motion is enabled.
class FadeSlideEntrance extends StatelessWidget {
  const FadeSlideEntrance({
    super.key,
    required this.child,
    this.index = 0,
    this.duration = AppAnimations.normal,
  });

  final Widget child;
  final int index;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final effectiveDuration = AppAnimations.resolveDuration(context, duration);
    if (effectiveDuration == Duration.zero) {
      return child;
    }

    final staggeredMs =
        (effectiveDuration.inMilliseconds + (index.clamp(0, 6) * 35));

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: staggeredMs),
      curve: AppAnimations.defaultCurve,
      child: child,
      builder: (BuildContext context, double value, Widget? builtChild) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1.0 - value) * 10.0),
            child: builtChild,
          ),
        );
      },
    );
  }
}
