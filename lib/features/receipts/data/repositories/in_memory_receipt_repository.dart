import 'dart:async';

import '../../../../core/storage/receipt_image_storage_service.dart';
import '../../domain/entities/receipt.dart';
import '../../domain/repositories/receipt_repository.dart';

/// Fast, deterministic in-memory implementation of [ReceiptRepository].
///
/// Ideal for widget tests, integration tests running inside Flutter's
/// `FakeAsync` zone, and preview environments where disk-backed `RandomAccessFile`
/// locks would block synchronous frame pumping.
class InMemoryReceiptRepository implements ReceiptRepository {
  InMemoryReceiptRepository({
    Iterable<Receipt>? initialReceipts,
    ReceiptImageStorageService? imageStorageService,
    DateTime Function()? clock,
  }) : _imageStorageService = imageStorageService,
       _clock = clock ?? DateTime.now {
    if (initialReceipts != null) {
      for (final receipt in initialReceipts) {
        _store[receipt.id] = receipt;
      }
    }
  }

  final Map<String, Receipt> _store = <String, Receipt>{};
  final StreamController<void> _changeController =
      StreamController<void>.broadcast();
  final ReceiptImageStorageService? _imageStorageService;
  final DateTime Function() _clock;

  /// Direct read-only snapshot of stored receipts for test assertions.
  Map<String, Receipt> get entries => Map<String, Receipt>.unmodifiable(_store);

  @override
  Future<void> saveReceipt(Receipt receipt) async {
    receipt.validate();
    _store[receipt.id] = receipt;
    _changeController.add(null);
  }

  @override
  Future<void> updateReceipt(Receipt receipt) async {
    receipt.validate();
    final existing = _store[receipt.id];
    if (existing != null &&
        existing.imagePath != null &&
        existing.imagePath != receipt.imagePath) {
      await _imageStorageService?.deleteReceiptImage(existing.imagePath);
    }

    final updated = receipt.copyWith(updatedAt: receipt.updatedAt ?? _clock());
    _store[updated.id] = updated;
    _changeController.add(null);
  }

  @override
  Future<void> deleteReceipt(String id) async {
    final existing = _store.remove(id);
    if (existing?.imagePath != null) {
      await _imageStorageService?.deleteReceiptImage(existing!.imagePath);
    }
    _changeController.add(null);
  }

  @override
  Future<void> deleteAllReceipts() async {
    _store.clear();
    await _imageStorageService?.deleteAllReceiptImages();
    _changeController.add(null);
  }

  @override
  Future<Receipt?> getReceiptById(String id) async {
    return _store[id];
  }

  @override
  Future<List<Receipt>> getAllReceipts() async {
    return _sortedReceipts(_store.values.toList(), ReceiptSortOrder.dateDesc);
  }

  @override
  Stream<List<Receipt>> watchAllReceipts() async* {
    yield _sortedReceipts(_store.values.toList(), ReceiptSortOrder.dateDesc);
    await for (final _ in _changeController.stream) {
      yield _sortedReceipts(_store.values.toList(), ReceiptSortOrder.dateDesc);
    }
  }

  @override
  Stream<List<Receipt>> watchCurrentMonthReceipts() {
    final now = _clock();
    return watchReceiptsByMonth(year: now.year, month: now.month);
  }

  @override
  Stream<List<Receipt>> watchReceiptsByMonth({
    required int year,
    required int month,
  }) async* {
    yield _receiptsForMonth(year: year, month: month);
    await for (final _ in _changeController.stream) {
      yield _receiptsForMonth(year: year, month: month);
    }
  }

  @override
  Future<List<Receipt>> queryReceipts(ReceiptFilter filter) async {
    final normalizedQuery = filter.searchQuery?.trim().toLowerCase() ?? '';
    final normalizedCategory = filter.category?.trim() ?? '';

    final startBoundary = filter.startDate != null
        ? DateTime(
            filter.startDate!.year,
            filter.startDate!.month,
            filter.startDate!.day,
          )
        : null;
    final endBoundary = filter.endDate != null
        ? DateTime(
            filter.endDate!.year,
            filter.endDate!.month,
            filter.endDate!.day,
            23,
            59,
            59,
            999,
          )
        : null;

    final filtered = _store.values.where((Receipt receipt) {
      if (normalizedQuery.isNotEmpty) {
        final merchantMatches = receipt.merchantName.toLowerCase().contains(
          normalizedQuery,
        );
        final categoryMatches = receipt.category.toLowerCase().contains(
          normalizedQuery,
        );
        if (!merchantMatches && !categoryMatches) {
          return false;
        }
      }

      if (normalizedCategory.isNotEmpty &&
          receipt.category.toLowerCase() != normalizedCategory.toLowerCase()) {
        return false;
      }

      if (startBoundary != null && receipt.date.isBefore(startBoundary)) {
        return false;
      }

      if (endBoundary != null && receipt.date.isAfter(endBoundary)) {
        return false;
      }

      if (filter.minAmountMinorUnits != null &&
          receipt.amountMinorUnits < filter.minAmountMinorUnits!) {
        return false;
      }

      if (filter.maxAmountMinorUnits != null &&
          receipt.amountMinorUnits > filter.maxAmountMinorUnits!) {
        return false;
      }

      return true;
    }).toList();

    return _sortedReceipts(filtered, filter.sortOrder);
  }

  @override
  Future<int> getMonthlyTotalMinorUnits({
    required int year,
    required int month,
  }) async {
    final monthlyReceipts = _receiptsForMonth(year: year, month: month);
    int sumMinorUnits = 0;
    for (final receipt in monthlyReceipts) {
      sumMinorUnits += receipt.amountMinorUnits;
    }
    return sumMinorUnits;
  }

  @override
  Future<double> getMonthlyTotal({
    required int year,
    required int month,
  }) async {
    final minorUnits = await getMonthlyTotalMinorUnits(
      year: year,
      month: month,
    );
    return Receipt.minorToMajorUnits(minorUnits);
  }

  @override
  Future<int> getMonthlyReceiptCount({
    required int year,
    required int month,
  }) async {
    return _receiptsForMonth(year: year, month: month).length;
  }

  @override
  Future<int> getTotalReceiptCount() async {
    return _store.length;
  }

  @override
  Future<MonthlyExpenseSummary> getMonthlySummary({
    required int year,
    required int month,
  }) async {
    final currentReceipts = _receiptsForMonth(year: year, month: month);

    int totalMinorUnits = 0;
    final categoryTotals = <String, int>{};

    for (final receipt in currentReceipts) {
      totalMinorUnits += receipt.amountMinorUnits;
      categoryTotals.update(
        receipt.category,
        (existing) => existing + receipt.amountMinorUnits,
        ifAbsent: () => receipt.amountMinorUnits,
      );
    }

    final int prevYear = month == 1 ? year - 1 : year;
    final int prevMonth = month == 1 ? 12 : month - 1;
    final prevReceipts = _receiptsForMonth(year: prevYear, month: prevMonth);

    int? previousMonthTotalMinorUnits;
    if (prevReceipts.isNotEmpty) {
      int prevSum = 0;
      for (final receipt in prevReceipts) {
        prevSum += receipt.amountMinorUnits;
      }
      previousMonthTotalMinorUnits = prevSum;
    }

    return MonthlyExpenseSummary(
      year: year,
      month: month,
      totalMinorUnits: totalMinorUnits,
      receiptCount: currentReceipts.length,
      previousMonthTotalMinorUnits: previousMonthTotalMinorUnits,
      categoryTotalsMinorUnits: categoryTotals,
    );
  }

  List<Receipt> _receiptsForMonth({required int year, required int month}) {
    final matching = _store.values
        .where((r) => r.date.year == year && r.date.month == month)
        .toList();
    return _sortedReceipts(matching, ReceiptSortOrder.dateDesc);
  }

  List<Receipt> _sortedReceipts(
    List<Receipt> receipts,
    ReceiptSortOrder sortOrder,
  ) {
    receipts.sort((a, b) {
      switch (sortOrder) {
        case ReceiptSortOrder.dateDesc:
          final dateCmp = b.date.compareTo(a.date);
          if (dateCmp != 0) return dateCmp;
          return b.createdAt.compareTo(a.createdAt);
        case ReceiptSortOrder.dateAsc:
          final dateCmp = a.date.compareTo(b.date);
          if (dateCmp != 0) return dateCmp;
          return a.createdAt.compareTo(b.createdAt);
        case ReceiptSortOrder.amountDesc:
          final amtCmp = b.amountMinorUnits.compareTo(a.amountMinorUnits);
          if (amtCmp != 0) return amtCmp;
          return b.date.compareTo(a.date);
        case ReceiptSortOrder.amountAsc:
          final amtCmp = a.amountMinorUnits.compareTo(b.amountMinorUnits);
          if (amtCmp != 0) return amtCmp;
          return b.date.compareTo(a.date);
        case ReceiptSortOrder.merchantAsc:
          final nameCmp = a.merchantName.toLowerCase().compareTo(
            b.merchantName.toLowerCase(),
          );
          if (nameCmp != 0) return nameCmp;
          return b.date.compareTo(a.date);
      }
    });
    return receipts;
  }
}
