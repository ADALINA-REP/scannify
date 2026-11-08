import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../receipts/domain/entities/receipt.dart';
import '../../../receipts/domain/repositories/receipt_repository.dart';

/// Represents a selected calendar month (`year` and `month` 1..12).
@immutable
class SelectedMonth {
  const SelectedMonth({required this.year, required this.month});

  factory SelectedMonth.current() {
    final now = DateTime.now();
    return SelectedMonth(year: now.year, month: now.month);
  }

  final int year;
  final int month;

  SelectedMonth get previousMonth {
    if (month == 1) {
      return SelectedMonth(year: year - 1, month: 12);
    }
    return SelectedMonth(year: year, month: month - 1);
  }

  SelectedMonth get nextMonth {
    if (month == 12) {
      return SelectedMonth(year: year + 1, month: 1);
    }
    return SelectedMonth(year: year, month: month + 1);
  }

  bool get canAdvanceToNextMonth {
    final now = DateTime.now();
    if (year < now.year) return true;
    if (year == now.year && month < now.month) return true;
    return false;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SelectedMonth && other.year == year && other.month == month;
  }

  @override
  int get hashCode => Object.hash(year, month);
}

/// Holds the currently selected month on the Home Dashboard.
final selectedDashboardMonthProvider = StateProvider<SelectedMonth>((ref) {
  return SelectedMonth.current();
});

/// Reactive stream of receipts belonging to the currently selected dashboard month.
final selectedMonthReceiptsProvider = StreamProvider<List<Receipt>>((ref) {
  final selected = ref.watch(selectedDashboardMonthProvider);
  final repository = ref.watch(receiptRepositoryProvider);
  return repository.watchReceiptsByMonth(
    year: selected.year,
    month: selected.month,
  );
});

/// Reactive [MonthlyExpenseSummary] for the currently selected dashboard month.
final selectedMonthSummaryProvider = FutureProvider<MonthlyExpenseSummary>((
  ref,
) async {
  // Watch the receipts stream so the summary automatically recomputes on any CRUD change.
  ref.watch(selectedMonthReceiptsProvider);
  ref.watch(allReceiptsStreamProvider);
  final selected = ref.watch(selectedDashboardMonthProvider);
  final repository = ref.watch(receiptRepositoryProvider);
  return repository.getMonthlySummary(
    year: selected.year,
    month: selected.month,
  );
});

/// Monthly VAT & Tax deductions calculation for the selected dashboard month.
@immutable
class MonthlyTaxSummary {
  const MonthlyTaxSummary({
    required this.totalTtcMinor,
    required this.totalHtMinor,
    required this.deductibleVatMinor,
    required this.certifiedReceiptsCount,
    required this.totalReceiptsCount,
    required this.receiptsWithImagesCount,
    required this.vatBreakdown,
  });

  final int totalTtcMinor;
  final int totalHtMinor;
  final int deductibleVatMinor;
  final int certifiedReceiptsCount;
  final int totalReceiptsCount;
  final int receiptsWithImagesCount;
  final Map<double, int> vatBreakdown;

  bool get hasReceipts => totalReceiptsCount > 0;
}

/// Reactive provider calculating deductible VAT and taxes for the active month.
final selectedMonthTaxSummaryProvider = Provider<MonthlyTaxSummary>((ref) {
  final receipts =
      ref.watch(selectedMonthReceiptsProvider).valueOrNull ?? const <Receipt>[];

  int totalTtc = 0;
  int totalHt = 0;
  int deductibleVat = 0;
  int certifiedCount = 0;
  int imagesCount = 0;
  final breakdown = <double, int>{};

  for (final r in receipts) {
    totalTtc += r.amountMinorUnits;
    totalHt += r.subtotalHtMinorUnits;
    final vat = r.effectiveVatMinorUnits;
    deductibleVat += vat;

    if (r.vatAmountMinorUnits != null) {
      certifiedCount++;
    }
    if (r.imagePath != null && r.imagePath!.isNotEmpty) {
      imagesCount++;
    }

    final rate = r.vatRate ??
        (switch (r.category) {
          ReceiptCategories.mealsAndDining => 10.0,
          ReceiptCategories.transportAndFuel => 10.0,
          ReceiptCategories.accommodation => 10.0,
          ReceiptCategories.groceries => 5.5,
          _ => 20.0,
        });
    breakdown.update(rate, (val) => val + vat, ifAbsent: () => vat);
  }

  return MonthlyTaxSummary(
    totalTtcMinor: totalTtc,
    totalHtMinor: totalHt,
    deductibleVatMinor: deductibleVat,
    certifiedReceiptsCount: certifiedCount,
    totalReceiptsCount: receipts.length,
    receiptsWithImagesCount: imagesCount,
    vatBreakdown: breakdown,
  );
});
