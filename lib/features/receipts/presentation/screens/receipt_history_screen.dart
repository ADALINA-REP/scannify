import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/settings/app_preferences.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';
import '../../domain/entities/receipt.dart';
import '../../domain/repositories/receipt_repository.dart';
import '../providers/receipt_history_providers.dart';

/// Receipt History screen (Section 9D).
///
/// Provides live search, category filtering, monthly navigation, multi-criteria
/// sorting, filtered expense totals, and the full transaction history list.
class ReceiptHistoryScreen extends ConsumerStatefulWidget {
  const ReceiptHistoryScreen({
    super.key,
    required this.onReceiptTapped,
    required this.onScanReceiptPressed,
    this.onBackPressed,
  });

  final ValueChanged<Receipt> onReceiptTapped;
  final VoidCallback onScanReceiptPressed;
  final VoidCallback? onBackPressed;

  @override
  ConsumerState<ReceiptHistoryScreen> createState() =>
      _ReceiptHistoryScreenState();
}

class _ReceiptHistoryScreenState extends ConsumerState<ReceiptHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  SelectedMonth? _filteredMonth;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyMonthFilter(SelectedMonth? month) {
    setState(() {
      _filteredMonth = month;
    });

    final currentFilter = ref.read(receiptHistoryFilterProvider);
    if (month == null) {
      ref.read(receiptHistoryFilterProvider.notifier).state = currentFilter
          .copyWith(clearStartDate: true, clearEndDate: true);
    } else {
      final start = DateTime(month.year, month.month, 1);
      final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
      ref.read(receiptHistoryFilterProvider.notifier).state = currentFilter
          .copyWith(startDate: start, endDate: end);
    }
  }

  String _formatMonthLabel(SelectedMonth selected, AppLanguage language) {
    final date = DateTime(selected.year, selected.month);
    final locale = language.localeString;
    final formatted = DateFormat.yMMMM(locale).format(date);
    if (formatted.isEmpty) return formatted;
    return formatted[0].toUpperCase() + formatted.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.scannifyColors;
    final textTheme = Theme.of(context).textTheme;
    final prefs = ref.watch(appPreferencesProvider);
    final strings = prefs.strings;

    final activeFilter = ref.watch(receiptHistoryFilterProvider);
    final filteredReceiptsAsync = ref.watch(filteredReceiptsProvider);

    return Scaffold(
      backgroundColor: colors.primaryBackground,
      appBar: CustomAppBar(
        title: strings.navHistory,
        onBackPressed: widget.onBackPressed,
        actions: <Widget>[
          PopupMenuButton<ReceiptSortOrder>(
            tooltip: strings.sortBy,
            icon: Icon(Icons.sort_rounded, color: colors.primaryText),
            color: colors.cardBackground,
            initialValue: activeFilter.sortOrder,
            onSelected: (ReceiptSortOrder order) {
              HapticsUtil.selection();
              ref.read(receiptHistoryFilterProvider.notifier).state =
                  activeFilter.copyWith(sortOrder: order);
            },
            itemBuilder: (BuildContext context) {
              return ReceiptSortOrder.values.map((ReceiptSortOrder order) {
                final selected = order == activeFilter.sortOrder;
                return PopupMenuItem<ReceiptSortOrder>(
                  value: order,
                  child: Row(
                    children: <Widget>[
                      Icon(
                        selected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        size: 18,
                        color: selected
                            ? colors.primaryEmerald
                            : colors.secondaryText,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        strings.sortOrderLabel(order),
                        style: textTheme.bodyMedium?.copyWith(
                          color: selected
                              ? colors.primaryEmerald
                              : colors.primaryText,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: ResponsiveConstrainedBox(
        padding: ResponsiveUtils.responsiveHorizontalPadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // 1. Search Input Field
            TextField(
              controller: _searchController,
              style: textTheme.bodyLarge,
              onChanged: (String value) {
                ref
                    .read(receiptHistoryFilterProvider.notifier)
                    .state = activeFilter.copyWith(
                  searchQuery: value,
                  clearSearchQuery: value.trim().isEmpty,
                );
              },
              decoration: InputDecoration(
                hintText: strings.searchHistoryHint,
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: colors.secondaryText,
                ),
                suffixIcon: (activeFilter.searchQuery?.isNotEmpty ?? false)
                    ? IconButton(
                        icon: Icon(
                          Icons.clear_rounded,
                          color: colors.secondaryText,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          ref
                              .read(receiptHistoryFilterProvider.notifier)
                              .state = activeFilter.copyWith(
                            clearSearchQuery: true,
                          );
                        },
                      )
                    : null,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // 2. Monthly Navigation Filter Bar
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  FilterChip(
                    selected: _filteredMonth == null,
                    label: Text(strings.allDates),
                    onSelected: (_) => _applyMonthFilter(null),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  FilterChip(
                    selected: _filteredMonth != null,
                    label: Text(
                      _filteredMonth != null
                          ? _formatMonthLabel(_filteredMonth!, prefs.language)
                          : strings.filterByMonth,
                    ),
                    onSelected: (_) {
                      if (_filteredMonth == null) {
                        _applyMonthFilter(SelectedMonth.current());
                      } else {
                        _applyMonthFilter(null);
                      }
                    },
                  ),
                  if (_filteredMonth != null) ...<Widget>[
                    const SizedBox(width: AppSpacing.xs),
                    IconButton(
                      constraints: const BoxConstraints(
                        minWidth: AppSpacing.minTouchTarget,
                        minHeight: AppSpacing.minTouchTarget,
                      ),
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: () =>
                          _applyMonthFilter(_filteredMonth!.previousMonth),
                    ),
                    IconButton(
                      constraints: const BoxConstraints(
                        minWidth: AppSpacing.minTouchTarget,
                        minHeight: AppSpacing.minTouchTarget,
                      ),
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: _filteredMonth!.canAdvanceToNextMonth
                          ? () => _applyMonthFilter(_filteredMonth!.nextMonth)
                          : null,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),

            // 3. Category Horizontal Filter Chips
            SizedBox(
              height: AppSpacing.minTouchTarget,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xs),
                    child: CategoryChip(
                      category: ReceiptCategories.other,
                      labelOverride: strings.allCategoriesLabel,
                      showIcon: false,
                      isSelected: activeFilter.category == null,
                      onSelected: () {
                        ref.read(receiptHistoryFilterProvider.notifier).state =
                            activeFilter.copyWith(clearCategory: true);
                      },
                    ),
                  ),
                  ...ReceiptCategories.all.map((String category) {
                    final selected = activeFilter.category == category;
                    return Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xs),
                      child: CategoryChip(
                        category: category,
                        isSelected: selected,
                        onSelected: () {
                          ref
                              .read(receiptHistoryFilterProvider.notifier)
                              .state = selected
                              ? activeFilter.copyWith(clearCategory: true)
                              : activeFilter.copyWith(category: category);
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 4. Filtered Summary & Receipt List
            Expanded(
              child: filteredReceiptsAsync.when(
                data: (List<Receipt> receipts) {
                  if (receipts.isEmpty) {
                    return EmptyState(
                      icon: Icons.manage_search_rounded,
                      title: strings.noReceiptsFound,
                      subtitle: strings.noReceiptsFoundSubtitle,
                      actionLabel: strings.scanReceiptCta,
                      onActionPressed: widget.onScanReceiptPressed,
                    );
                  }

                  int filteredSumMinor = 0;
                  for (final r in receipts) {
                    filteredSumMinor += r.amountMinorUnits;
                  }

                  return Column(
                    children: <Widget>[
                      // Filtered Expense Summary Bar
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: colors.secondaryBackground,
                          borderRadius: const BorderRadius.all(
                            Radius.circular(AppRadii.sm),
                          ),
                          border: Border.all(color: colors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text(
                              strings.receiptsCountLabel(receipts.length),
                              style: textTheme.labelLarge?.copyWith(
                                color: colors.secondaryText,
                              ),
                            ),
                            Text(
                              prefs.formatMinorUnits(filteredSumMinor),
                              style: AppTypography.cardAmount(
                                colors.primaryEmerald,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // Receipt Cards List
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.only(
                            bottom: AppSpacing.xxl,
                          ),
                          itemCount: receipts.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (BuildContext context, int index) {
                            final receipt = receipts[index];
                            return ReceiptCard(
                              receipt: receipt,
                              formattedAmount: prefs.formatMinorUnits(
                                receipt.amountMinorUnits,
                              ),
                              index: index,
                              onTap: () => widget.onReceiptTapped(receipt),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
                loading: () => LoadingSkeleton.list(itemCount: 5),
                error: (Object err, StackTrace _) => EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Error',
                  subtitle: err.toString(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
