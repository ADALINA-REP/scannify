import 'package:flutter/material.dart';
import '../../localization/app_localizations.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../tokens/category_styles.dart';
import '../utils/animation_utils.dart';

/// Selectable expense category pill chip with vector icon and $48\text{ dp}$
/// minimum interactive height for one-handed mobile selection.
class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.category,
    this.labelOverride,
    this.isSelected = false,
    this.onSelected,
    this.showIcon = true,
  });

  final String category;
  final String? labelOverride;
  final bool isSelected;
  final VoidCallback? onSelected;
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    final colors = context.scannifyColors;
    final textTheme = Theme.of(context).textTheme;
    final strings = AppStrings.of(context);
    final style = CategoryStyles.forCategory(category);
    final displayLabel = labelOverride ?? strings.categoryDisplayName(category);

    final Color bgColor = isSelected
        ? colors.primaryEmerald.withValues(alpha: 0.18)
        : colors.secondaryBackground;
    final Color borderColor = isSelected
        ? colors.primaryEmerald
        : colors.border;
    final Color textColor = isSelected
        ? colors.primaryEmerald
        : colors.primaryText;

    return Semantics(
      button: onSelected != null,
      selected: isSelected,
      label: displayLabel,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSpacing.minTouchTarget),
        child: Material(
          color: bgColor,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadii.chipBorderRadius,
            side: BorderSide(color: borderColor, width: isSelected ? 1.5 : 1.0),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onSelected != null
                ? () {
                    HapticsUtil.selection();
                    onSelected!();
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs + 2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (showIcon) ...<Widget>[
                    Icon(
                      style.icon,
                      size: 16,
                      color: isSelected
                          ? colors.primaryEmerald
                          : style.accentColor,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  Text(
                    displayLabel,
                    style: textTheme.labelLarge?.copyWith(
                      color: textColor,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
