import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/core_providers.dart';
import '../../domain/entities/receipt.dart';
import '../../domain/repositories/receipt_repository.dart';

/// Holds the active [ReceiptFilter] on the Receipt History screen.
final receiptHistoryFilterProvider = StateProvider<ReceiptFilter>((ref) {
  return const ReceiptFilter(sortOrder: ReceiptSortOrder.dateDesc);
});

/// Reactive list of receipts matching [receiptHistoryFilterProvider].
final filteredReceiptsProvider = FutureProvider<List<Receipt>>((ref) async {
  // Re-evaluate whenever underlying receipt store emits changes.
  ref.watch(allReceiptsStreamProvider);
  final filter = ref.watch(receiptHistoryFilterProvider);
  final repository = ref.watch(receiptRepositoryProvider);
  return repository.queryReceipts(filter);
});
