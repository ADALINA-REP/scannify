import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../features/receipts/domain/entities/receipt.dart';
import '../../localization/app_localizations.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';
import '../tokens/category_styles.dart';
import '../utils/animation_utils.dart';

/// Reusable FinTech receipt list card displaying the merchant name, transaction
/// date, category badge with vector icon, and right-aligned tabular amount.
class ReceiptCard extends StatelessWidget {
  const ReceiptCard({
    super.key,
    required this.receipt,
    required this.formattedAmount,
    this.onTap,
    this.index = 0,
  });

  final Receipt receipt;
  final String formattedAmount;
  final VoidCallback? onTap;
  final int index;

  static final DateFormat _shortDateFormat = DateFormat('dd/MM/yyyy');

  @override
  Widget build(BuildContext context) {
    final colors = context.scannifyColors;
    final textTheme = Theme.of(context).textTheme;
    final strings = AppStrings.of(context);
    final categoryStyle = CategoryStyles.forCategory(receipt.category);
    final localizedCategory = strings.categoryDisplayName(receipt.category);
    final dateText = _shortDateFormat.format(receipt.date);

    return FadeSlideEntrance(
      index: index,
      child: Semantics(
        button: onTap != null,
        label:
            '${receipt.merchantName}, $localizedCategory, $dateText, $formattedAmount',
        child: Material(
          color: colors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.all(Radius.circular(AppRadii.md)),
            side: BorderSide(color: colors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap != null
                ? () {
                    HapticsUtil.selection();
                    onTap!();
                  }
                : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppSpacing.minTouchTarget + 20,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm + 2,
                ),
                child: Row(
                  children: <Widget>[
                    // Category Vector Icon Container
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: categoryStyle.accentColor.withValues(
                          alpha: 0.14,
                        ),
                        borderRadius: const BorderRadius.all(
                          Radius.circular(AppRadii.sm),
                        ),
                      ),
                      child: Icon(
                        categoryStyle.icon,
                        color: categoryStyle.accentColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm + 2),

                    // Merchant Name & Date + Category Metadata
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            receipt.merchantName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: <Widget>[
                              Text(
                                dateText,
                                style: textTheme.bodySmall?.copyWith(
                                  color: colors.secondaryText,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                child: Container(
                                  width: 3,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: colors.mutedText,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  localizedCategory,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: categoryStyle.accentColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),

                    // Right-Aligned Financial Amount
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          formattedAmount,
                          textAlign: TextAlign.right,
                          style: AppTypography.cardAmount(colors.primaryText),
                        ),
                        if (receipt.imagePath != null) ...<Widget>[
                          const SizedBox(height: 4),
                          Icon(
                            Icons.photo_camera_back_rounded,
                            size: 13,
                            color: colors.mutedText,
                          ),
                        ],
                      ],
                    ),
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
