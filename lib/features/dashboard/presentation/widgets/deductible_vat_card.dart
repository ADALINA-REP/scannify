import 'package:flutter/material.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/settings/app_preferences.dart';
import '../providers/dashboard_providers.dart';

/// FinTech Widget (P2) displaying real-time deductible VAT (TVA récupérable)
/// for freelancers, independent professionals, and SMBs.
///
/// Provides a 1-click shortcut to generate the complete certified monthly
/// accounting dossier (P1) with all attached receipt photos.
class DeductibleVatCard extends StatelessWidget {
  const DeductibleVatCard({
    super.key,
    required this.taxSummary,
    required this.prefs,
    required this.onGenerateAccountingDossier,
  });

  final MonthlyTaxSummary taxSummary;
  final AppPreferencesState prefs;
  final VoidCallback onGenerateAccountingDossier;

  @override
  Widget build(BuildContext context) {
    final colors = context.scannifyColors;
    final textTheme = Theme.of(context).textTheme;

    final vatFormatted = prefs.formatMinorUnits(taxSummary.deductibleVatMinor);
    final htFormatted = prefs.formatMinorUnits(taxSummary.totalHtMinor);
    final ttcFormatted = prefs.formatMinorUnits(taxSummary.totalTtcMinor);

    return Container(
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: AppRadii.cardBorderRadius,
        border: Border.all(
          color: colors.primaryEmerald.withValues(alpha: 0.28),
          width: 1.2,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colors.primaryEmerald.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: AppRadii.cardBorderRadius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Accent gradient bar at top
            Container(
              height: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    colors.primaryEmerald,
                    colors.primaryEmerald.withValues(alpha: 0.4),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Header Row: Title & Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: colors.primaryEmerald.withValues(alpha: 0.14),
                              borderRadius: const BorderRadius.all(
                                Radius.circular(8),
                              ),
                            ),
                            child: Icon(
                              Icons.account_balance_wallet_rounded,
                              size: 18,
                              color: colors.primaryEmerald,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            prefs.strings.deductibleVatTitle,
                            style: textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: colors.primaryText,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: colors.secondaryBackground,
                          borderRadius: AppRadii.chipBorderRadius,
                          border: Border.all(color: colors.border),
                        ),
                        child: Text(
                          prefs.strings.taxCreditBadge,
                          style: textTheme.labelSmall?.copyWith(
                            color: colors.primaryEmerald,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Hero Deductible VAT Amount
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: <Widget>[
                      Text(
                        '+$vatFormatted',
                        style: textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colors.primaryEmerald,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      if (taxSummary.certifiedReceiptsCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primaryEmerald.withValues(alpha: 0.12),
                            borderRadius: AppRadii.chipBorderRadius,
                          ),
                          child: Text(
                            prefs.strings.verifiedCountBadge(
                              taxSummary.certifiedReceiptsCount,
                            ),
                            style: textTheme.labelSmall?.copyWith(
                              color: colors.primaryEmerald,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 2),

                  Text(
                    prefs.strings.deductibleVatSubtitle,
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.secondaryText,
                      fontSize: 11.5,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // 3-Metrics Accounting Strip
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm + 2,
                    ),
                    decoration: BoxDecoration(
                      color: colors.secondaryBackground,
                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        _buildMetricColumn(
                          context,
                          label: prefs.strings.subtotalExclTax,
                          value: htFormatted,
                        ),
                        Container(
                          width: 1,
                          height: 24,
                          color: colors.border,
                        ),
                        _buildMetricColumn(
                          context,
                          label: prefs.strings.totalInclTax,
                          value: ttcFormatted,
                        ),
                        Container(
                          width: 1,
                          height: 24,
                          color: colors.border,
                        ),
                        _buildMetricColumn(
                          context,
                          label: prefs.strings.receiptsMetricLabel,
                          value: '${taxSummary.totalReceiptsCount}',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // 1-Click Accounting Dossier Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primaryEmerald,
                        foregroundColor: const Color(0xFF041F15),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: AppSpacing.md,
                        ),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                      ),
                      onPressed: onGenerateAccountingDossier,
                      icon: const Icon(
                        Icons.picture_as_pdf_rounded,
                        size: 18,
                      ),
                      label: Text(
                        prefs.strings.accountingReportCta,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
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

  Widget _buildMetricColumn(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final colors = context.scannifyColors;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(
            color: colors.secondaryText,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: colors.primaryText,
          ),
        ),
      ],
    );
  }
}
