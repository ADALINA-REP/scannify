import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/settings/app_preferences.dart';
import 'privacy_policy_screen.dart';

/// Settings screen (Section 9G).
///
/// Manages Theme Mode (Dark / Light / System), Currency, Language (EN / FR),
/// Daily Quota inspection & rewarded unlock, Scannify Pro access, Privacy Policy,
/// Complete Local Data Deletion, and App Version metadata.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({
    super.key,
    this.onBackPressed,
  });

  final VoidCallback? onBackPressed;

  /// Feature flag to toggle Scannify Pro paywall visibility.
  /// Set to `true` when ready to re-enable Scannify Pro offerings.
  static const bool showScannifyPro = false;

  Future<void> _confirmDeleteAllLocalData(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final strings = ref.read(appPreferencesProvider).strings;
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: strings.deleteConfirmTitle,
      message: strings.deleteConfirmMessage,
      confirmLabel: strings.deleteAllConfirmCta,
      cancelLabel: strings.cancel,
      isDestructive: true,
      icon: Icons.delete_sweep_rounded,
    );

    if (!confirmed || !context.mounted) return;

    await ref.read(receiptRepositoryProvider).deleteAllReceipts();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(strings.allDataDeletedSuccess),
        ),
      );
    }
  }

  void _showLanguagePickerBottomSheet(BuildContext context, WidgetRef ref) {
    HapticsUtil.selection();
    final colors = context.scannifyColors;
    final textTheme = Theme.of(context).textTheme;
    final prefs = ref.read(appPreferencesProvider);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top drag pill
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header: Language title & close button (matches design mockup)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 12, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        prefs.strings.languageSheetTitle,
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colors.primaryText,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: colors.secondaryText,
                          size: 24,
                        ),
                        onPressed: () => Navigator.of(sheetContext).pop(),
                      ),
                    ],
                  ),
                ),
                Divider(color: colors.border, height: 1),
                // Language List items
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: AppLanguage.values.length,
                    separatorBuilder: (_, __) => Divider(
                      color: colors.border.withValues(alpha: 0.5),
                      height: 1,
                      indent: 80,
                    ),
                    itemBuilder: (context, index) {
                      final lang = AppLanguage.values[index];
                      final isSelected = prefs.language == lang;

                      return InkWell(
                        onTap: () {
                          HapticsUtil.selection();
                          ref
                              .read(appPreferencesProvider.notifier)
                              .setLanguage(lang);
                          Navigator.of(sheetContext).pop();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? colors.primaryEmerald.withValues(
                                          alpha: 0.16,
                                        )
                                      : (lang == AppLanguage.automatic
                                          ? const Color(
                                              0xFF0284C7,
                                            ).withValues(alpha: 0.12)
                                          : colors.elevatedSurface),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? colors.primaryEmerald.withValues(
                                            alpha: 0.35,
                                          )
                                        : colors.border,
                                    width: 1,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: lang == AppLanguage.automatic
                                    ? const Icon(
                                        Icons.public_rounded,
                                        color: Color(0xFF0284C7),
                                        size: 24,
                                      )
                                    : Text(
                                        lang.flagEmoji,
                                        style: const TextStyle(fontSize: 22),
                                      ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      lang.label,
                                      style: textTheme.bodyLarge?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: isSelected
                                            ? colors.primaryEmerald
                                            : colors.primaryText,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      lang.englishName,
                                      style: textTheme.bodySmall?.copyWith(
                                        color: colors.secondaryText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: colors.primaryEmerald,
                                  size: 24,
                                )
                              else
                                const SizedBox(width: 24),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCurrencyPickerBottomSheet(BuildContext context, WidgetRef ref) {
    HapticsUtil.selection();
    final colors = context.scannifyColors;
    final textTheme = Theme.of(context).textTheme;
    final prefs = ref.read(appPreferencesProvider);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 12, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        prefs.strings.primaryCurrencyTitle,
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colors.primaryText,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: colors.secondaryText,
                          size: 24,
                        ),
                        onPressed: () => Navigator.of(sheetContext).pop(),
                      ),
                    ],
                  ),
                ),
                Divider(color: colors.border, height: 1),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: SupportedCurrency.values.length,
                    separatorBuilder: (_, __) => Divider(
                      color: colors.border.withValues(alpha: 0.5),
                      height: 1,
                      indent: 80,
                    ),
                    itemBuilder: (context, index) {
                      final curr = SupportedCurrency.values[index];
                      final isSelected = prefs.currency == curr;

                      return InkWell(
                        onTap: () {
                          HapticsUtil.selection();
                          ref
                              .read(appPreferencesProvider.notifier)
                              .setCurrency(curr);
                          Navigator.of(sheetContext).pop();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? colors.primaryEmerald.withValues(
                                          alpha: 0.16,
                                        )
                                      : colors.elevatedSurface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? colors.primaryEmerald.withValues(
                                            alpha: 0.35,
                                          )
                                        : colors.border,
                                    width: 1,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  curr.flagEmoji,
                                  style: const TextStyle(fontSize: 22),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      curr.name,
                                      style: textTheme.bodyLarge?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: isSelected
                                            ? colors.primaryEmerald
                                            : colors.primaryText,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${curr.code} (${curr.symbol}) • ${curr.region}',
                                      style: textTheme.bodySmall?.copyWith(
                                        color: colors.secondaryText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: colors.primaryEmerald,
                                  size: 24,
                                )
                              else
                                const SizedBox(width: 24),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.scannifyColors;
    final textTheme = Theme.of(context).textTheme;
    final prefs = ref.watch(appPreferencesProvider);
    final prefsNotifier = ref.read(appPreferencesProvider.notifier);
    final strings = prefs.strings;

    return Scaffold(
      backgroundColor: colors.primaryBackground,
      appBar: CustomAppBar(
        title: strings.navSettings,
        onBackPressed: onBackPressed,
      ),
      body: ResponsiveConstrainedBox(
        maxWidth: AppSpacing.maxNarrowContentWidth,
        padding: ResponsiveUtils.responsiveHorizontalPadding(context),
        child: ListView(
          padding: const EdgeInsets.only(
            top: AppSpacing.sm,
            bottom: AppSpacing.xxl,
          ),
          children: <Widget>[
            // 1. Appearance (Theme Mode)
            Text(
              strings.appearanceTitle,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.cardBackground,
                borderRadius: AppRadii.cardBorderRadius,
                border: Border.all(color: colors.border),
              ),
              child: Column(
                children: <Widget>[
                  _ThemeOptionTile(
                    icon: Icons.dark_mode_rounded,
                    title: strings.themeDark,
                    isSelected: prefs.themeMode == ThemeMode.dark,
                    onTap: () => prefsNotifier.setThemeMode(ThemeMode.dark),
                  ),
                  Divider(color: colors.border, height: 16),
                  _ThemeOptionTile(
                    icon: Icons.light_mode_rounded,
                    title: strings.themeLight,
                    isSelected: prefs.themeMode == ThemeMode.light,
                    onTap: () => prefsNotifier.setThemeMode(ThemeMode.light),
                  ),
                  Divider(color: colors.border, height: 16),
                  _ThemeOptionTile(
                    icon: Icons.brightness_auto_rounded,
                    title: strings.themeSystem,
                    isSelected: prefs.themeMode == ThemeMode.system,
                    onTap: () => prefsNotifier.setThemeMode(ThemeMode.system),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // 3. Currency & Language Preferences
            Text(
              strings.currencyAndLanguageTitle,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              decoration: BoxDecoration(
                color: colors.cardBackground,
                borderRadius: AppRadii.cardBorderRadius,
                border: Border.all(color: colors.border),
              ),
              child: Column(
                children: <Widget>[
                  _SettingsListSelectionTile(
                    leadingWidget: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colors.primaryEmerald.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colors.primaryEmerald.withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        prefs.currency.flagEmoji,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                    title: strings.primaryCurrencyTitle,
                    subtitle:
                        '${prefs.currency.name} • ${prefs.currency.code} (${prefs.currency.symbol})',
                    badgeText: prefs.currency.code,
                    onTap: () => _showCurrencyPickerBottomSheet(context, ref),
                  ),
                  Divider(color: colors.border, height: 1),
                  _SettingsListSelectionTile(
                    leadingWidget: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: (prefs.language == AppLanguage.automatic
                                ? const Color(0xFF0284C7)
                                : colors.primaryEmerald)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (prefs.language == AppLanguage.automatic
                                  ? const Color(0xFF0284C7)
                                  : colors.primaryEmerald)
                              .withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: prefs.language == AppLanguage.automatic
                          ? const Icon(
                              Icons.public_rounded,
                              color: Color(0xFF0284C7),
                              size: 24,
                            )
                          : Text(
                              prefs.language.flagEmoji,
                              style: const TextStyle(fontSize: 22),
                            ),
                    ),
                    title: strings.applicationLanguageTitle,
                    subtitle:
                        '${prefs.language.label} (${prefs.language.englishName})',
                    badgeText: prefs.language.code.toUpperCase(),
                    onTap: () => _showLanguagePickerBottomSheet(context, ref),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // 4. Privacy, Local Storage & About Scannify
            Text(
              strings.privacyAndAboutTitle,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              decoration: BoxDecoration(
                color: colors.cardBackground,
                borderRadius: AppRadii.cardBorderRadius,
                border: Border.all(color: colors.border),
              ),
              child: Column(
                children: <Widget>[
                  ListTile(
                    leading: Icon(
                      Icons.privacy_tip_outlined,
                      color: colors.primaryEmerald,
                    ),
                    title: Text(
                      strings.privacyPolicyTitle,
                      style: textTheme.titleSmall,
                    ),
                    subtitle: Text(
                      strings.privacyPolicySubtitle,
                      style: textTheme.bodySmall,
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const PrivacyPolicyScreen(),
                        ),
                      );
                    },
                  ),
                  Divider(color: colors.border, height: 1),
                  ListTile(
                    leading: Icon(
                      Icons.delete_forever_rounded,
                      color: colors.error,
                    ),
                    title: Text(
                      strings.deleteAllDataTitle,
                      style: textTheme.titleSmall?.copyWith(
                        color: colors.error,
                      ),
                    ),
                    subtitle: Text(
                      strings.deleteAllDataSubtitle,
                      style: textTheme.bodySmall,
                    ),
                    onTap: () => _confirmDeleteAllLocalData(context, ref),
                  ),
                  Divider(color: colors.border, height: 1),
                  ListTile(
                    leading: Icon(
                      Icons.info_outline_rounded,
                      color: colors.secondaryText,
                    ),
                    title: Text('Scannify', style: textTheme.titleSmall),
                    subtitle: Text(
                      '${strings.appDescription} • v1.0.0+1',
                      style: textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeOptionTile extends StatelessWidget {
  const _ThemeOptionTile({
    required this.icon,
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.scannifyColors;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      borderRadius: const BorderRadius.all(Radius.circular(AppRadii.sm)),
      onTap: () {
        HapticsUtil.selection();
        onTap();
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSpacing.minTouchTarget),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Row(
            children: <Widget>[
              Icon(
                icon,
                color: isSelected
                    ? colors.primaryEmerald
                    : colors.secondaryText,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? colors.primaryEmerald
                        : colors.primaryText,
                  ),
                ),
              ),
              Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: isSelected ? colors.primaryEmerald : colors.mutedText,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsListSelectionTile extends StatelessWidget {
  const _SettingsListSelectionTile({
    required this.leadingWidget,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.onTap,
  });

  final Widget leadingWidget;
  final String title;
  final String subtitle;
  final String badgeText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.scannifyColors;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      borderRadius: AppRadii.cardBorderRadius,
      onTap: () {
        HapticsUtil.selection();
        onTap();
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSpacing.minTouchTarget),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: <Widget>[
              leadingWidget,
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colors.elevatedSurface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: colors.border),
                ),
                child: Text(
                  badgeText,
                  style: textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.primaryEmerald,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: colors.secondaryText,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
