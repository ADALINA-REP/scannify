import 'package:flutter/material.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../utils/animation_utils.dart';

/// Smooth pulsing skeleton placeholder for receipt cards and dashboard summaries.
///
/// Automatically respects system reduced-motion preferences.
class LoadingSkeleton extends StatefulWidget {
  const LoadingSkeleton({
    super.key,
    this.width = double.infinity,
    this.height = 72.0,
    this.borderRadius = AppRadii.md,
  });

  /// Creates a vertical list of receipt card skeletons.
  static Widget list({int itemCount = 3}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(itemCount, (int index) {
        return Padding(
          padding: EdgeInsets.only(bottom: index == itemCount - 1 ? 0 : 12),
          child: const LoadingSkeleton(height: 70),
        );
      }),
    );
  }

  final double width;
  final double height;
  final double borderRadius;

  @override
  State<LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.scannifyColors;
    final reducedMotion = AppAnimations.isReducedMotion(context);

    if (reducedMotion) {
      return _buildBox(colors.elevatedSurface, colors.border);
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? _) {
        final surface = Color.lerp(
          colors.cardBackground,
          colors.elevatedSurface,
          _controller.value,
        )!;
        return _buildBox(surface, colors.border);
      },
    );
  }

  Widget _buildBox(Color fill, Color borderColor) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.all(Radius.circular(widget.borderRadius)),
        border: Border.all(color: borderColor.withValues(alpha: 0.6)),
      ),
    );
  }
}
