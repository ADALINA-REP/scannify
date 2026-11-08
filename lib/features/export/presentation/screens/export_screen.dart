import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/settings/app_preferences.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';
import '../../../receipts/domain/entities/receipt.dart';
import '../../domain/services/export_service.dart';

/// Reporting periods available on the Export screen.
enum ExportPeriodPreset { currentMonth, previousMonth, currentYear, allTime }

/// Financial Export screen (Section 9F).
///
/// Allows selecting a reporting period and format (CSV or PDF), previews the
/// report summary and category breakdown, activates the rewarded-ad unlock flow
/// on mobile, and shares or downloads the generated file.
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({
    super.key,
    this.onBackPressed,
  });

  final VoidCallback? onBackPressed;

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  ExportPeriodPreset _selectedPreset = ExportPeriodPreset.currentMonth;
  ExportFormat _selectedFormat = ExportFormat.pdf;
  bool _includePhotos = true;
  bool _isExporting = false;

  List<Receipt> _filterReceiptsForPreset(
    List<Receipt> allReceipts,
    ExportPeriodPreset preset,
    SelectedMonth dashboardMonth,
  ) {
    final now = DateTime.now();
    switch (preset) {
      case ExportPeriodPreset.currentMonth:
        return allReceipts
            .where(
              (r) =>
                  r.date.year == dashboardMonth.year &&
                  r.date.month == dashboardMonth.month,
            )
            .toList();
      case ExportPeriodPreset.previousMonth:
        final prev = dashboardMonth.previousMonth;
        return allReceipts
            .where(
              (r) => r.date.year == prev.year && r.date.month == prev.month,
            )
            .toList();
      case ExportPeriodPreset.currentYear:
        return allReceipts.where((r) => r.date.year == now.year).toList();
      case ExportPeriodPreset.allTime:
        return allReceipts;
    }
  }

  String _periodLabelForPreset(
    ExportPeriodPreset preset,
    SelectedMonth dashboardMonth,
    AppLanguage language,
  ) {
    final locale = language.localeString;
    switch (preset) {
      case ExportPeriodPreset.currentMonth:
        final d = DateTime(dashboardMonth.year, dashboardMonth.month);
        final formatted = DateFormat.yMMMM(locale).format(d);
        return formatted[0].toUpperCase() + formatted.substring(1);
      case ExportPeriodPreset.previousMonth:
        final prev = dashboardMonth.previousMonth;
        final d = DateTime(prev.year, prev.month);
        final formatted = DateFormat.yMMMM(locale).format(d);
        return formatted[0].toUpperCase() + formatted.substring(1);
      case ExportPeriodPreset.currentYear:
        return '${DateTime.now().year}';
      case ExportPeriodPreset.allTime:
        return AppStrings(language).periodAllReceipts;
    }
  }

  Future<void> _startExportWorkflow(
    List<Receipt> periodReceipts,
    String periodLabel,
  ) async {
    if (_isExporting) return;

    final prefs = ref.read(appPreferencesProvider);
    final strings = prefs.strings;

    if (periodReceipts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(strings.exportNoReceiptsError),
        ),
      );
      return;
    }

    final adService = ref.read(adServiceProvider);
    final premium = ref.read(premiumServiceProvider).currentEntitlements;
    final requiresRewardedAd =
        adService.isSupportedPlatform && !premium.hasAdFreeExports;

    final request = ExportRequest(
      receipts: periodReceipts,
      format: _selectedFormat,
      periodLabel: periodLabel,
      reportTitle: strings.accountingReportTitle,
      currencySymbol: prefs.currency.symbol,
      currencyCode: prefs.currency.code,
      includeReceiptImages:
          _includePhotos && _selectedFormat == ExportFormat.pdf,
      isAccountingDossier: true,
    );

    if (requiresRewardedAd) {
      await _showRewardedExportDialog(request);
      return;
    }

    setState(() {
      _isExporting = true;
    });

    try {
      final exportService = ref.read(exportServiceProvider);
      final result = await exportService.executeRewardedExport(request);
      if (!mounted) return;

      if (result.isSuccess && result.document != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              strings.exportReadySuccess(result.document!.fileName),
            ),
          ),
        );
      } else if (result.errorMessage != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result.errorMessage!)));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _showRewardedExportDialog(ExportRequest request) async {
    String? dialogError;
    bool isWorking = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            final strings = ref.read(appPreferencesProvider).strings;
            return RewardedAdDialog(
              title: strings.exportRewardTitle,
              message: strings.exportRewardBody,
              watchVideoLabel: dialogError != null
                  ? strings.retry
                  : strings.watchVideo,
              maybeLaterLabel: strings.maybeLater,
              errorMessage: dialogError,
              isLoading: isWorking,
              onMaybeLater: () => Navigator.of(dialogContext).pop(),
              onWatchVideo: () async {
                setDialogState(() {
                  isWorking = true;
                  dialogError = null;
                });

                final exportService = ref.read(exportServiceProvider);
                final result = await exportService.executeRewardedExport(
                  request,
                );

                if (!dialogContext.mounted) return;

                if (result.isSuccess) {
                  Navigator.of(dialogContext).pop();
                } else {
                  setDialogState(() {
                    isWorking = false;
                    dialogError =
                        result.errorMessage ??
                        'Ad unavailable right now. Please try again.';
                  });
                }
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.scannifyColors;
    final textTheme = Theme.of(context).textTheme;
    final prefs = ref.watch(appPreferencesProvider);
    final strings = prefs.strings;

    final selectedMonth = ref.watch(selectedDashboardMonthProvider);
    final allReceiptsAsync = ref.watch(allReceiptsStreamProvider);
    final premiumAsync = ref.watch(premiumEntitlementsStreamProvider);
    final isAdFreeExport =
        premiumAsync.valueOrNull?.hasAdFreeExports ??
        !ref.watch(adServiceProvider).isSupportedPlatform;

    final allReceipts = allReceiptsAsync.valueOrNull ?? const <Receipt>[];
    final periodReceipts = _filterReceiptsForPreset(
      allReceipts,
      _selectedPreset,
      selectedMonth,
    );
    final periodLabel = _periodLabelForPreset(
      _selectedPreset,
      selectedMonth,
      prefs.language,
    );

    int totalMinorUnits = 0;
    final categoryBreakdown = <String, int>{};
    for (final r in periodReceipts) {
      totalMinorUnits += r.amountMinorUnits;
      categoryBreakdown.update(
        r.category,
        (v) => v + r.amountMinorUnits,
        ifAbsent: () => r.amountMinorUnits,
      );
    }

    final sortedCategories = categoryBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      backgroundColor: colors.primaryBackground,
      appBar: CustomAppBar(
        title: strings.navExport,
        onBackPressed: widget.onBackPressed,
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
            // 1. Reporting Period Selector
            Text(
              strings.reportingPeriod,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                _PeriodPresetChip(
                  label: strings.periodCurrentMonth,
                  isSelected:
                      _selectedPreset == ExportPeriodPreset.currentMonth,
                  onTap: () => setState(() {
                    _selectedPreset = ExportPeriodPreset.currentMonth;
                  }),
                ),
                _PeriodPresetChip(
                  label: strings.periodPreviousMonth,
                  isSelected:
                      _selectedPreset == ExportPeriodPreset.previousMonth,
                  onTap: () => setState(() {
                    _selectedPreset = ExportPeriodPreset.previousMonth;
                  }),
                ),
                _PeriodPresetChip(
                  label: strings.periodCurrentYear,
                  isSelected: _selectedPreset == ExportPeriodPreset.currentYear,
                  onTap: () => setState(() {
                    _selectedPreset = ExportPeriodPreset.currentYear;
                  }),
                ),
                _PeriodPresetChip(
                  label: strings.periodAllReceipts,
                  isSelected: _selectedPreset == ExportPeriodPreset.allTime,
                  onTap: () => setState(() {
                    _selectedPreset = ExportPeriodPreset.allTime;
                  }),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),

            // 2. Format Selection (PDF vs CSV)
            Text(
              strings.exportFormat,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: _FormatSelectorCard(
                    icon: Icons.picture_as_pdf_rounded,
                    title: strings.pdfReportOptionTitle,
                    subtitle: strings.pdfReportOptionSubtitle,
                    isSelected: _selectedFormat == ExportFormat.pdf,
                    onTap: () => setState(() {
                      _selectedFormat = ExportFormat.pdf;
                    }),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _FormatSelectorCard(
                    icon: Icons.table_chart_rounded,
                    title: strings.csvReportOptionTitle,
                    subtitle: strings.csvReportOptionSubtitle,
                    isSelected: _selectedFormat == ExportFormat.csv,
                    onTap: () => setState(() {
                      _selectedFormat = ExportFormat.csv;
                    }),
                  ),
                ),
              ],
            ),

            if (_selectedFormat == ExportFormat.pdf) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Container(
                decoration: BoxDecoration(
                  color: colors.cardBackground,
                  borderRadius: AppRadii.cardBorderRadius,
                  border: Border.all(color: colors.border),
                ),
                child: SwitchListTile(
                  value: _includePhotos,
                  onChanged: (val) => setState(() => _includePhotos = val),
                  activeThumbColor: colors.primaryEmerald,
                  secondary: Icon(
                    Icons.attach_file_rounded,
                    color: colors.primaryEmerald,
                  ),
                  title: Text(
                    strings.attachReceiptPhotosTitle,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    strings.attachReceiptPhotosSubtitle,
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.secondaryText,
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.xl),

            // 3. Report Preview Summary Card
            Text(
              strings.reportPreview,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        periodLabel,
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primaryEmerald.withValues(alpha: 0.14),
                          borderRadius: AppRadii.chipBorderRadius,
                        ),
                        child: Text(
                          _selectedFormat.extension.toUpperCase(),
                          style: textTheme.labelSmall?.copyWith(
                            color: colors.primaryEmerald,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            strings.totalAmountMetric,
                            style: textTheme.labelSmall?.copyWith(
                              color: colors.secondaryText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            prefs.formatMinorUnits(totalMinorUnits),
                            style: AppTypography.heroAmount(
                              colors.primaryEmerald,
                            ).copyWith(fontSize: 26),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          Text(
                            strings.receiptsMetric,
                            style: textTheme.labelSmall?.copyWith(
                              color: colors.secondaryText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${periodReceipts.length}',
                            style: textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (sortedCategories.isNotEmpty) ...<Widget>[
                    Divider(color: colors.border, height: 28),
                    Text(
                      strings.categoryBreakdown,
                      style: textTheme.labelLarge?.copyWith(
                        color: colors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ...sortedCategories.take(5).map((entry) {
                      final pct = totalMinorUnits > 0
                          ? ((entry.value / totalMinorUnits) * 100.0)
                                .toStringAsFixed(1)
                          : '0.0';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                strings.categoryDisplayName(entry.key),
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colors.primaryText,
                                ),
                              ),
                            ),
                            Text(
                              '$pct%',
                              style: textTheme.bodySmall?.copyWith(
                                color: colors.secondaryText,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Text(
                              prefs.formatMinorUnits(entry.value),
                              style: AppTypography.cardAmount(
                                colors.primaryText,
                              ).copyWith(fontSize: 14),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // 4. Rewarded Ad Notice (when on mobile free tier)
            if (!isAdFreeExport)
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colors.secondaryBackground,
                  borderRadius: const BorderRadius.all(
                    Radius.circular(AppRadii.md),
                  ),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.play_circle_outline_rounded,
                      color: colors.primaryEmerald,
                      size: 22,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        strings.exportRewardBody,
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.secondaryText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // 5. Primary Export CTA
            ScanButton(
              label: strings.exportFormatCta(
                _selectedFormat.extension.toUpperCase(),
              ),
              icon: Icons.ios_share_rounded,
              isFullWidth: true,
              isLoading: _isExporting,
              onPressed: () =>
                  _startExportWorkflow(periodReceipts, periodLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodPresetChip extends StatelessWidget {
  const _PeriodPresetChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.scannifyColors;
    final textTheme = Theme.of(context).textTheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSpacing.minTouchTarget),
      child: Material(
        color: isSelected
            ? colors.primaryEmerald.withValues(alpha: 0.16)
            : colors.secondaryBackground,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.chipBorderRadius,
          side: BorderSide(
            color: isSelected ? colors.primaryEmerald : colors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticsUtil.selection();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs + 2,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  label,
                  style: textTheme.labelLarge?.copyWith(
                    color: isSelected
                        ? colors.primaryEmerald
                        : colors.primaryText,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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

class _FormatSelectorCard extends StatelessWidget {
  const _FormatSelectorCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.scannifyColors;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: isSelected
          ? colors.primaryEmerald.withValues(alpha: 0.12)
          : colors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.cardBorderRadius,
        side: BorderSide(
          color: isSelected ? colors.primaryEmerald : colors.border,
          width: isSelected ? 1.6 : 1.0,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticsUtil.selection();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                icon,
                color: isSelected ? colors.primaryEmerald : colors.primaryText,
                size: 26,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? colors.primaryEmerald
                      : colors.primaryText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: textTheme.bodySmall?.copyWith(
                  color: colors.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
