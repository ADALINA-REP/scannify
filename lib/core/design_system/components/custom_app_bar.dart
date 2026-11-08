import 'package:flutter/material.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../utils/animation_utils.dart';

/// Signature FinTech top application bar for Scannify.
///
/// Can display the recognizable Scannify Emerald emblem on the Home Dashboard
/// or a standard screen title with accessible $48 \times 48\text{ dp}$ action targets.
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.showBrandLogo = false,
    this.actions,
    this.leading,
    this.onBackPressed,
  });

  final String title;
  final String? subtitle;
  final bool showBrandLogo;
  final List<Widget>? actions;
  final Widget? leading;
  final VoidCallback? onBackPressed;

  @override
  Size get preferredSize => const Size.fromHeight(64.0);

  @override
  Widget build(BuildContext context) {
    final colors = context.scannifyColors;
    final textTheme = Theme.of(context).textTheme;
    final canPop = Navigator.maybeOf(context)?.canPop() ?? false;

    Widget? resolvedLeading = leading;
    if (resolvedLeading == null && (canPop || onBackPressed != null)) {
      resolvedLeading = IconButton(
        constraints: const BoxConstraints(
          minWidth: AppSpacing.minTouchTarget,
          minHeight: AppSpacing.minTouchTarget,
        ),
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 20,
          color: colors.primaryText,
        ),
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: () {
          HapticsUtil.selection();
          if (onBackPressed != null) {
            onBackPressed!();
          } else {
            Navigator.of(context).maybePop();
          }
        },
      );
    }

    return AppBar(
      toolbarHeight: 64.0,
      backgroundColor: colors.primaryBackground,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      leading: resolvedLeading,
      titleSpacing: resolvedLeading != null ? 0 : AppSpacing.md,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (showBrandLogo) ...<Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(Radius.circular(10)),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: colors.primaryEmerald.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: colors.primaryEmerald,
                  child: const Icon(
                    Icons.document_scanner_rounded,
                    color: Color(0xFF041F15),
                    size: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.secondaryText,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: actions != null
          ? <Widget>[...actions!, const SizedBox(width: AppSpacing.xs)]
          : null,
    );
  }
}
