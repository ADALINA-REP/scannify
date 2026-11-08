import 'package:flutter/material.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';
import '../utils/animation_utils.dart';

/// Premium FinTech monthly expense overview card with integrated month selector,
/// animated hero amount counter, receipt count badge, and previous-month trend indicator.
class ExpenseSummaryCard extends StatelessWidget {
  const ExpenseSummaryCard({
    super.key,
    required this.monthLabel,
    required this.totalLabel,
    required this.totalMinorUnits,
    required this.amountFormatter,
    required this.receiptCountLabel,
    this.percentageChangeFromPreviousMonth,
    this.comparisonFormatter,
    this.onPreviousMonth,
    this.onNextMonth,
    this.canGoNextMonth = true,
  });

  final String monthLabel;
  final String totalLabel;
  final int totalMinorUnits;
  final String Function(int minorUnits) amountFormatter;
  final String receiptCountLabel;
  final double? percentageChangeFromPreviousMonth;
  final String Function(String signedPct)? comparisonFormatter;
  final VoidCallback? onPreviousMonth;
  final VoidCallback? onNextMonth;
  final bool canGoNextMonth;

  @override
  Widget build(BuildContext context) {
    final colors = context.scannifyColors;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      container: true,
      label:
          '$totalLabel ($monthLabel): ${amountFormatter(totalMinorUnits)}, $receiptCountLabel',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: AppRadii.cardBorderRadius,
          border: Border.all(
            color: colors.primaryEmerald.withValues(alpha: 0.30),
            width: 1.2,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              colors.cardBackground,
              Color.alphaBlend(
                colors.primaryEmerald.withValues(
                  alpha: colors.isDark ? 0.08 : 0.05,
                ),
                colors.cardBackground,
              ),
            ],
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: colors.primaryEmerald.withValues(
                alpha: colors.isDark ? 0.07 : 0.05,
              ),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Top Row: Month Selector & Receipt Count Pill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                _buildMonthSelector(context, colors, textTheme),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primaryEmerald.withValues(alpha: 0.14),
                    borderRadius: AppRadii.chipBorderRadius,
                    border: Border.all(
                      color: colors.primaryEmerald.withValues(alpha: 0.30),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.receipt_long_rounded,
                        size: 14,
                        color: colors.primaryEmerald,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        receiptCountLabel,
                        style: textTheme.labelMedium?.copyWith(
                          color: colors.primaryEmerald,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Label
            Text(
              totalLabel.toUpperCase(),
              style: textTheme.labelSmall?.copyWith(
                color: colors.secondaryText,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),

            // Animated Hero Financial Total
            AnimatedCurrencyCounter(
              amountMinorUnits: totalMinorUnits,
              formatter: amountFormatter,
              style: AppTypography.heroAmount(colors.primaryText),
            ),

            if (percentageChangeFromPreviousMonth != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              _buildComparisonBadge(colors, textTheme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSelector(
    BuildContext context,
    ScannifyThemeColors colors,
    TextTheme textTheme,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: colors.secondaryBackground,
        borderRadius: AppRadii.chipBorderRadius,
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            constraints: const BoxConstraints(
              minWidth: AppSpacing.minTouchTarget,
              minHeight: AppSpacing.minTouchTarget,
            ),
            padding: EdgeInsets.zero,
            icon: Icon(
              Icons.chevron_left_rounded,
              color: colors.primaryText,
              size: 22,
            ),
            onPressed: onPreviousMonth != null
                ? () {
                    HapticsUtil.selection();
                    onPreviousMonth!();
                  }
                : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Text(
              monthLabel,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            constraints: const BoxConstraints(
              minWidth: AppSpacing.minTouchTarget,
              minHeight: AppSpacing.minTouchTarget,
            ),
            padding: EdgeInsets.zero,
            icon: Icon(
              Icons.chevron_right_rounded,
              color: canGoNextMonth ? colors.primaryText : colors.mutedText,
              size: 22,
            ),
            onPressed: (canGoNextMonth && onNextMonth != null)
                ? () {
                    HapticsUtil.selection();
                    onNextMonth!();
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonBadge(
    ScannifyThemeColors colors,
    TextTheme textTheme,
  ) {
    final pct = percentageChangeFromPreviousMonth!;
    final isIncrease = pct > 0.05;
    final isDecrease = pct < -0.05;
    final sign = isIncrease ? '+' : '';
    final formattedPct = '$sign${pct.toStringAsFixed(1)}%';
    final text = comparisonFormatter != null
        ? comparisonFormatter!(formattedPct)
        : '$formattedPct vs last month';

    final IconData trendIcon = isIncrease
        ? Icons.trending_up_rounded
        : isDecrease
        ? Icons.trending_down_rounded
        : Icons.trending_flat_rounded;

    final Color badgeColor = isDecrease
        ? colors.primaryEmerald
        : isIncrease
        ? colors.warning
        : colors.secondaryText;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(trendIcon, size: 16, color: badgeColor),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: textTheme.bodySmall?.copyWith(
              color: badgeColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
