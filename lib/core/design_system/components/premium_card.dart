import 'package:flutter/material.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../utils/animation_utils.dart';

/// Reusable FinTech banner/card highlighting Scannify Premium benefits.
class PremiumCard extends StatelessWidget {
  const PremiumCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.benefits,
    this.actionLabel,
    this.onActionPressed,
    this.isActive = false,
  });

  final String title;
  final String subtitle;
  final List<String> benefits;
  final String? actionLabel;
  final VoidCallback? onActionPressed;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final colors = context.scannifyColors;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: AppRadii.cardBorderRadius,
        border: Border.all(
          color: colors.primaryEmerald.withValues(alpha: 0.45),
          width: 1.4,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color.alphaBlend(
              colors.primaryEmerald.withValues(
                alpha: colors.isDark ? 0.14 : 0.08,
              ),
              colors.cardBackground,
            ),
            colors.cardBackground,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.primaryEmerald.withValues(alpha: 0.18),
                  borderRadius: const BorderRadius.all(
                    Radius.circular(AppRadii.sm),
                  ),
                ),
                child: Icon(
                  Icons.workspace_premium_rounded,
                  color: colors.primaryEmerald,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primaryEmerald.withValues(alpha: 0.2),
                    borderRadius: AppRadii.chipBorderRadius,
                  ),
                  child: Text(
                    'ACTIVE',
                    style: textTheme.labelSmall?.copyWith(
                      color: colors.primaryEmerald,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...benefits.map(
            (String benefit) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: colors.primaryEmerald,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      benefit,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colors.primaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (actionLabel != null && onActionPressed != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticsUtil.lightImpact();
                  onActionPressed!();
                },
                icon: const Icon(Icons.bolt_rounded, size: 20),
                label: Text(actionLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
