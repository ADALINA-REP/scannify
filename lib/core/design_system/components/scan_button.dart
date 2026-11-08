import 'package:flutter/material.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../utils/animation_utils.dart';

/// Signature Emerald primary receipt scan button.
///
/// Designed for thumb-friendly mobile reachability ($\ge 54\text{ dp}$ height)
/// with an optional quota indicator badge.
class ScanButton extends StatelessWidget {
  const ScanButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.badgeText,
    this.icon = Icons.document_scanner_rounded,
    this.isLoading = false,
    this.isFullWidth = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final String? badgeText;
  final IconData icon;
  final bool isLoading;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    final colors = context.scannifyColors;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      enabled: onPressed != null && !isLoading,
      label: badgeText != null ? '$label ($badgeText)' : label,
      child: SizedBox(
        width: isFullWidth ? double.infinity : null,
        height: 54.0,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(
              Radius.circular(AppRadii.pill),
            ),
            gradient: LinearGradient(
              colors: <Color>[colors.primaryEmerald, colors.secondaryEmerald],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: colors.primaryEmerald.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: const BorderRadius.all(
                Radius.circular(AppRadii.pill),
              ),
              onTap: (onPressed != null && !isLoading)
                  ? () {
                      HapticsUtil.mediumImpact();
                      onPressed!();
                    }
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  mainAxisSize: isFullWidth
                      ? MainAxisSize.max
                      : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    if (isLoading)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Color(0xFF041F15),
                        ),
                      )
                    else
                      Icon(icon, color: const Color(0xFF041F15), size: 22),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          color: const Color(0xFF041F15),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (badgeText != null) ...<Widget>[
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF041F15,
                          ).withValues(alpha: 0.16),
                          borderRadius: AppRadii.chipBorderRadius,
                        ),
                        child: Text(
                          badgeText!,
                          style: textTheme.labelSmall?.copyWith(
                            color: const Color(0xFF041F15),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
