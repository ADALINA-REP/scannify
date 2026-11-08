import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/settings/app_preferences.dart';
import '../../../export/domain/services/export_service.dart';
import '../../../receipts/domain/entities/receipt.dart';
import '../providers/dashboard_providers.dart';
import '../widgets/deductible_vat_card.dart';

/// Home Financial Dashboard screen (Section 9A).
///
/// Displays the Scannify brand header, month selector, hero monthly expense
/// summary card with previous-month comparison, recent transactions list,
/// and prominent thumb-friendly Scan Receipt CTA.
class HomeDashboardScreen extends ConsumerWidget {
  const HomeDashboardScreen({
    super.key,
    required this.onScanReceiptPressed,
    required this.onReceiptTapped,
    required this.onViewAllHistoryPressed,
    required this.onSettingsPressed,
  });

  final VoidCallback onScanReceiptPressed;
  final ValueChanged<Receipt> onReceiptTapped;
  final VoidCallback onViewAllHistoryPressed;
  final VoidCallback onSettingsPressed;

  String _formatMonthLabel(SelectedMonth selected, AppLanguage language) {
    final date = DateTime(selected.year, selected.month);
    final locale = language.localeString;
    final formatted = DateFormat.yMMMM(locale).format(date);
    if (formatted.isEmpty) return formatted;
    return formatted[0].toUpperCase() + formatted.substring(1);
  }

  Future<void> _generateMonthlyAccountingDossier(
    BuildContext context,
    WidgetRef ref,
    List<Receipt> receipts,
    String monthLabel,
    AppPreferencesState prefs,
  ) async {
    final strings = prefs.strings;
    if (receipts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            strings.noReceiptsInMonthToExport(monthLabel),
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(strings.generatingAccountingReport),
        duration: const Duration(seconds: 2),
      ),
    );

    final request = ExportRequest(
      receipts: receipts,
      format: ExportFormat.pdf,
      periodLabel: monthLabel,
      reportTitle: strings.accountingReportTitle,
      currencySymbol: prefs.currency.symbol,
      currencyCode: prefs.currency.code,
      includeReceiptImages: true,
      isAccountingDossier: true,
    );

    try {
      final exportService = ref.read(exportServiceProvider);
      final result = await exportService.executeRewardedExport(request);
      if (!context.mounted) return;

      if (!result.isSuccess && result.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.errorMessage!)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(strings.errorGeneratingAccountingReport),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.scannifyColors;
    final textTheme = Theme.of(context).textTheme;
    final prefs = ref.watch(appPreferencesProvider);
    final strings = prefs.strings;

    final selectedMonth = ref.watch(selectedDashboardMonthProvider);
    final monthReceiptsAsync = ref.watch(selectedMonthReceiptsProvider);
    final monthSummaryAsync = ref.watch(selectedMonthSummaryProvider);
    final taxSummary = ref.watch(selectedMonthTaxSummaryProvider);
    final quotaAsync = ref.watch(quotaStatusStreamProvider);

    final monthLabel = _formatMonthLabel(selectedMonth, prefs.language);

    final String? quotaBadgeText = quotaAsync.maybeWhen(
      data: (quota) => quota.isUnlimitedPremium
          ? 'PRO'
          : '${quota.totalAvailableScans}/${quota.dailyFreeLimit}',
      orElse: () => null,
    );

    return Scaffold(
      backgroundColor: colors.primaryBackground,
      appBar: CustomAppBar(
        title: strings.appName,
        showBrandLogo: true,
        actions: <Widget>[
          if (quotaBadgeText != null)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: colors.secondaryBackground,
                    borderRadius: AppRadii.chipBorderRadius,
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.bolt_rounded,
                        size: 14,
                        color: colors.primaryEmerald,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        strings.quotaScansBadge(quotaBadgeText),
                        style: textTheme.labelSmall?.copyWith(
                          color: colors.primaryText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          IconButton(
            constraints: const BoxConstraints(
              minWidth: AppSpacing.minTouchTarget,
              minHeight: AppSpacing.minTouchTarget,
            ),
            tooltip: strings.navSettings,
            icon: Icon(
              Icons.settings_outlined,
              color: colors.primaryText,
              size: 22,
            ),
            onPressed: onSettingsPressed,
          ),
        ],
      ),
      body: ResponsiveConstrainedBox(
        padding: ResponsiveUtils.responsiveHorizontalPadding(context),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: <Widget>[
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),

            // 1. Hero Monthly Expense Summary Card
            SliverToBoxAdapter(
              child: monthSummaryAsync.when(
                data: (summary) => ExpenseSummaryCard(
                  monthLabel: monthLabel,
                  totalLabel: strings.totalMonthlyExpenses,
                  totalMinorUnits: summary.totalMinorUnits,
                  amountFormatter: prefs.formatMinorUnits,
                  receiptCountLabel: strings.receiptsCountLabel(
                    summary.receiptCount,
                  ),
                  percentageChangeFromPreviousMonth:
                      summary.percentageChangeFromPreviousMonth,
                  comparisonFormatter: strings.vsPreviousMonth,
                  onPreviousMonth: () {
                    ref.read(selectedDashboardMonthProvider.notifier).state =
                        selectedMonth.previousMonth;
                  },
                  onNextMonth: () {
                    if (selectedMonth.canAdvanceToNextMonth) {
                      ref.read(selectedDashboardMonthProvider.notifier).state =
                          selectedMonth.nextMonth;
                    }
                  },
                  canGoNextMonth: selectedMonth.canAdvanceToNextMonth,
                ),
                loading: () => const LoadingSkeleton(
                  height: 176,
                  borderRadius: AppRadii.lg,
                ),
                error: (err, _) => ExpenseSummaryCard(
                  monthLabel: monthLabel,
                  totalLabel: strings.totalMonthlyExpenses,
                  totalMinorUnits: 0,
                  amountFormatter: prefs.formatMinorUnits,
                  receiptCountLabel: strings.receiptsCountLabel(0),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),

            // 1b. Deductible VAT / Pro Tax Card (Feature P2 & P1 Shortcut)
            SliverToBoxAdapter(
              child: DeductibleVatCard(
                taxSummary: taxSummary,
                prefs: prefs,
                onGenerateAccountingDossier: () {
                  final receipts =
                      monthReceiptsAsync.valueOrNull ?? const <Receipt>[];
                  _generateMonthlyAccountingDossier(
                    context,
                    ref,
                    receipts,
                    monthLabel,
                    prefs,
                  );
                },
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),

            // 2. Primary Thumb-Friendly Scan Button
            SliverToBoxAdapter(
              child: ScanButton(
                label: strings.scanReceiptCta,
                badgeText: quotaBadgeText,
                isFullWidth: true,
                onPressed: onScanReceiptPressed,
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),

            // 3. Recent Transactions Header
            SliverToBoxAdapter(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    strings.recentTransactions,
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextButton(
                    onPressed: onViewAllHistoryPressed,
                    child: Text(strings.viewAll),
                  ),
                ],
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xs)),

            // 4. Recent Receipts List or Empty State
            monthReceiptsAsync.when(
              data: (List<Receipt> receipts) {
                if (receipts.isEmpty) {
                  return SliverToBoxAdapter(
                    child: EmptyState(
                      title: strings.emptyDashboardTitle,
                      subtitle: strings.emptyDashboardSubtitle,
                      actionLabel: strings.scanReceiptCta,
                      onActionPressed: onScanReceiptPressed,
                    ),
                  );
                }

                final recentItems = receipts.take(10).toList();
                return SliverPadding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                  sliver: SliverList.separated(
                    itemCount: recentItems.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (BuildContext context, int index) {
                      final receipt = recentItems[index];
                      return ReceiptCard(
                        receipt: receipt,
                        formattedAmount: prefs.formatMinorUnits(
                          receipt.amountMinorUnits,
                        ),
                        index: index,
                        onTap: () => onReceiptTapped(receipt),
                      );
                    },
                  ),
                );
              },
              loading: () =>
                  SliverToBoxAdapter(child: LoadingSkeleton.list(itemCount: 4)),
              error: (Object error, StackTrace _) => SliverToBoxAdapter(
                child: EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: strings.errorLoadingData,
                  subtitle: error.toString(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
