import 'package:flutter/material.dart';
import '../../localization/app_localizations.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../utils/animation_utils.dart';

/// Primary navigation destinations in Scannify.
enum ScannifyNavTab { dashboard, history, exportReport, settings }

/// Thumb-friendly mobile bottom navigation bar with a prominent central
/// Emerald receipt-scanner trigger and $48 \times 48\text{ dp}$ minimum targets.
class CustomBottomNavigation extends StatelessWidget {
  const CustomBottomNavigation({
    super.key,
    required this.currentTab,
    required this.onTabSelected,
    required this.onScanPressed,
    this.strings,
  });

  final ScannifyNavTab currentTab;
  final ValueChanged<ScannifyNavTab> onTabSelected;
  final VoidCallback onScanPressed;
  final AppStrings? strings;

  @override
  Widget build(BuildContext context) {
    final colors = context.scannifyColors;
    final s = strings ?? AppStrings.of(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.secondaryBackground,
        border: Border(top: BorderSide(color: colors.border, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                Expanded(
                  child: _NavTabButton(
                    icon: Icons.grid_view_rounded,
                    label: s.navDashboard,
                    isSelected: currentTab == ScannifyNavTab.dashboard,
                    onTap: () => onTabSelected(ScannifyNavTab.dashboard),
                  ),
                ),
                Expanded(
                  child: _NavTabButton(
                    icon: Icons.receipt_long_rounded,
                    label: s.navHistory,
                    isSelected: currentTab == ScannifyNavTab.history,
                    onTap: () => onTabSelected(ScannifyNavTab.history),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                  ),
                  child: Semantics(
                    button: true,
                    label: s.scanReceiptCta,
                    child: SizedBox(
                      width: 54,
                      height: 54,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: <Color>[
                              colors.primaryEmerald,
                              colors.secondaryEmerald,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: colors.primaryEmerald.withValues(
                                alpha: 0.35,
                              ),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () {
                              HapticsUtil.mediumImpact();
                              onScanPressed();
                            },
                            child: const Icon(
                              Icons.document_scanner_rounded,
                              color: Color(0xFF041F15),
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _NavTabButton(
                    icon: Icons.ios_share_rounded,
                    label: s.navExport,
                    isSelected: currentTab == ScannifyNavTab.exportReport,
                    onTap: () => onTabSelected(ScannifyNavTab.exportReport),
                  ),
                ),
                Expanded(
                  child: _NavTabButton(
                    icon: Icons.tune_rounded,
                    label: s.navSettings,
                    isSelected: currentTab == ScannifyNavTab.settings,
                    onTap: () => onTabSelected(ScannifyNavTab.settings),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTabButton extends StatelessWidget {
  const _NavTabButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.scannifyColors;
    final textTheme = Theme.of(context).textTheme;
    final activeColor = isSelected
        ? colors.primaryEmerald
        : colors.secondaryText;

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(AppRadii.sm)),
        onTap: () {
          HapticsUtil.selection();
          onTap();
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: AppSpacing.minTouchTarget,
            minHeight: AppSpacing.minTouchTarget,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 22, color: activeColor),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelSmall?.copyWith(
                  color: activeColor,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
