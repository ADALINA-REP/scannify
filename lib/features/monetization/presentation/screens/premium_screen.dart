import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/settings/app_preferences.dart';

/// Scannify Premium architecture & overview screen (Section 7 & Phase 4.9).
///
/// Presents Premium benefits and entitlement status. Prepared for official
/// App Store / Google Play in-app purchase integration without fake payment flows.
class PremiumScreen extends ConsumerWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.scannifyColors;
    final textTheme = Theme.of(context).textTheme;
    final prefs = ref.watch(appPreferencesProvider);
    final strings = prefs.strings;
    final entitlementsAsync = ref.watch(premiumEntitlementsStreamProvider);
    final isPremium = entitlementsAsync.valueOrNull?.isPremiumActive ?? false;

    return Scaffold(
      backgroundColor: colors.primaryBackground,
      appBar: const CustomAppBar(title: 'Scannify Pro'),
      body: ResponsiveConstrainedBox(
        maxWidth: AppSpacing.maxNarrowContentWidth,
        padding: ResponsiveUtils.responsiveHorizontalPadding(context),
        child: ListView(
          padding: const EdgeInsets.only(
            top: AppSpacing.md,
            bottom: AppSpacing.xxl,
          ),
          children: <Widget>[
            PremiumCard(
              title: 'Scannify Pro',
              subtitle: strings.proDesignedForSubtitle,
              benefits: strings.proBenefits,
              isActive: isPremium,
            ),
            const SizedBox(height: AppSpacing.xl),
            Container(
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
                      Icon(
                        Icons.storefront_rounded,
                        color: colors.primaryEmerald,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        strings.storeSubscriptionsTitle,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    strings.storeSubscriptionsBody,
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await ref
                            .read(premiumServiceProvider)
                            .refreshEntitlements();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                strings.restoreEntitlementsSuccess,
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.restore_rounded, size: 18),
                      label: Text(
                        strings.restoreEntitlementsCta,
                      ),
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
