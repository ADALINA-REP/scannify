import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/settings/app_preferences.dart';

/// Transparent Privacy Policy & Local Data Architecture disclosure screen (Section 12).
class PrivacyPolicyScreen extends ConsumerWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.scannifyColors;
    final strings = ref.watch(appPreferencesProvider).strings;

    return Scaffold(
      backgroundColor: colors.primaryBackground,
      appBar: CustomAppBar(
        title: strings.privacyScreenTitle,
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
            _PolicySectionCard(
              icon: Icons.shield_outlined,
              title: strings.privacySection1Title,
              body: strings.privacySection1Body,
            ),
            const SizedBox(height: AppSpacing.md),
            _PolicySectionCard(
              icon: Icons.memory_rounded,
              title: strings.privacySection2Title,
              body: strings.privacySection2Body,
            ),
            const SizedBox(height: AppSpacing.md),
            _PolicySectionCard(
              icon: Icons.folder_copy_outlined,
              title: strings.privacySection3Title,
              body: strings.privacySection3Body,
            ),
            const SizedBox(height: AppSpacing.md),
            _PolicySectionCard(
              icon: Icons.ads_click_rounded,
              title: strings.privacySection4Title,
              body: strings.privacySection4Body,
            ),
          ],
        ),
      ),
    );
  }
}

class _PolicySectionCard extends StatelessWidget {
  const _PolicySectionCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = context.scannifyColors;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: AppRadii.cardBorderRadius,
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: colors.primaryEmerald, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            style: textTheme.bodyMedium?.copyWith(color: colors.secondaryText),
          ),
        ],
      ),
    );
  }
}
