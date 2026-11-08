import 'package:meta/meta.dart';
import '../entities/receipt.dart';

/// Supported sorting options when querying receipts.
enum ReceiptSortOrder { dateDesc, dateAsc, amountDesc, amountAsc, merchantAsc }

/// Dynamic filter and sort specification for querying receipts.
@immutable
class ReceiptFilter {
  const ReceiptFilter({
    this.searchQuery,
    this.category,
    this.startDate,
    this.endDate,
    this.minAmountMinorUnits,
    this.maxAmountMinorUnits,
    this.sortOrder = ReceiptSortOrder.dateDesc,
  });

  /// Case-insensitive substring query matching merchant name or category.
  final String? searchQuery;

  /// Exact category filter (null or empty matches all categories).
  final String? category;

  /// Inclusive lower bound for receipt transaction date.
  final DateTime? startDate;

  /// Inclusive upper bound for receipt transaction date.
  final DateTime? endDate;

  /// Inclusive minimum amount in integer minor currency units.
  final int? minAmountMinorUnits;

  /// Inclusive maximum amount in integer minor currency units.
  final int? maxAmountMinorUnits;

  /// Sort order applied to matching results.
  final ReceiptSortOrder sortOrder;

  ReceiptFilter copyWith({
    String? searchQuery,
    bool clearSearchQuery = false,
    String? category,
    bool clearCategory = false,
    DateTime? startDate,
    bool clearStartDate = false,
    DateTime? endDate,
    bool clearEndDate = false,
    int? minAmountMinorUnits,
    bool clearMinAmount = false,
    int? maxAmountMinorUnits,
    bool clearMaxAmount = false,
    ReceiptSortOrder? sortOrder,
  }) {
    return ReceiptFilter(
      searchQuery: clearSearchQuery ? null : (searchQuery ?? this.searchQuery),
      category: clearCategory ? null : (category ?? this.category),
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      minAmountMinorUnits: clearMinAmount
          ? null
          : (minAmountMinorUnits ?? this.minAmountMinorUnits),
      maxAmountMinorUnits: clearMaxAmount
          ? null
          : (maxAmountMinorUnits ?? this.maxAmountMinorUnits),
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

/// Aggregated financial summary for a specific calendar month.
///
/// Uses integer minor currency units ([totalMinorUnits]) internally to avoid
/// floating-point rounding drift.
@immutable
class MonthlyExpenseSummary {
  const MonthlyExpenseSummary({
    required this.year,
    required this.month,
    required this.totalMinorUnits,
    required this.receiptCount,
    this.previousMonthTotalMinorUnits,
    this.categoryTotalsMinorUnits = const <String, int>{},
  });

  final int year;
  final int month;

  /// Total monthly expenditure in integer minor currency units (e.g. cents).
  final int totalMinorUnits;

  /// Total number of receipts recorded in this month.
  final int receiptCount;

  /// Total expenditure of the immediately preceding calendar month in minor units,
  /// or `null` if no receipts existed in the previous month.
  final int? previousMonthTotalMinorUnits;

  /// Breakdown of expenses by category in integer minor currency units.
  final Map<String, int> categoryTotalsMinorUnits;

  /// Total monthly expenditure in major currency units (e.g. `142.50`).
  double get totalAmount => Receipt.minorToMajorUnits(totalMinorUnits);

  /// Previous month's total in major currency units, if available.
  double? get previousMonthTotalAmount => previousMonthTotalMinorUnits != null
      ? Receipt.minorToMajorUnits(previousMonthTotalMinorUnits!)
      : null;

  /// Relative percentage change compared to the previous month (e.g. `+12.5` or `-8.0`).
  /// Returns `null` if there is no previous month baseline or previous month total was zero.
  double? get percentageChangeFromPreviousMonth {
    final prev = previousMonthTotalMinorUnits;
    if (prev == null || prev <= 0) {
      return null;
    }
    return ((totalMinorUnits - prev) / prev) * 100.0;
  }
}

/// Abstract repository contract for offline local receipt persistence and
/// financial aggregation.
abstract interface class ReceiptRepository {
  /// Saves a new [Receipt] or overwrites an existing one with the same ID.
  Future<void> saveReceipt(Receipt receipt);

  /// Updates an existing [Receipt], setting its `updatedAt` timestamp.
  Future<void> updateReceipt(Receipt receipt);

  /// Deletes the receipt identified by [id] from local storage.
  Future<void> deleteReceipt(String id);

  /// Deletes all locally stored receipts (complete local data reset).
  Future<void> deleteAllReceipts();

  /// Retrieves a single [Receipt] by [id], or `null` if not found.
  Future<Receipt?> getReceiptById(String id);

  /// Returns all locally stored receipts ordered by transaction date descending.
  Future<List<Receipt>> getAllReceipts();

  /// Reactive stream emitting all receipts whenever the local store changes.
  Stream<List<Receipt>> watchAllReceipts();

  /// Reactive stream emitting receipts belonging to the current calendar month.
  Stream<List<Receipt>> watchCurrentMonthReceipts();

  /// Reactive stream emitting receipts belonging to the specified [year] and [month].
  Stream<List<Receipt>> watchReceiptsByMonth({
    required int year,
    required int month,
  });

  /// Returns receipts matching the dynamic [filter] and sorting criteria.
  Future<List<Receipt>> queryReceipts(ReceiptFilter filter);

  /// Computes the exact monthly total in integer minor currency units.
  Future<int> getMonthlyTotalMinorUnits({
    required int year,
    required int month,
  });

  /// Computes the monthly total in major currency units.
  Future<double> getMonthlyTotal({required int year, required int month});

  /// Returns the number of receipts for the given [year] and [month].
  Future<int> getMonthlyReceiptCount({required int year, required int month});

  /// Returns the total number of receipts stored across all dates.
  Future<int> getTotalReceiptCount();

  /// Computes a complete [MonthlyExpenseSummary] for [year] and [month],
  /// including previous-month comparison and category breakdown.
  Future<MonthlyExpenseSummary> getMonthlySummary({
    required int year,
    required int month,
  });
}
