import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:scannify/core/errors/app_exception.dart';
import 'package:scannify/core/storage/receipt_image_storage_io.dart';
import 'package:scannify/features/receipts/data/local/hive_registrar.dart';
import 'package:scannify/features/receipts/data/repositories/local_receipt_repository.dart';
import 'package:scannify/features/receipts/domain/entities/receipt.dart';
import 'package:scannify/features/receipts/domain/repositories/receipt_repository.dart';

void main() {
  late Directory tempDir;
  late LocalFileReceiptImageStorageService imageStorage;
  late LocalReceiptRepository repository;
  late DateTime currentClock;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('scannify_repo_test_');
    await HiveConfig.initialize(testDirectoryPath: tempDir.path);
    imageStorage = LocalFileReceiptImageStorageService(
      customBaseDirectory: tempDir,
    );
    currentClock = DateTime(2026, 10, 20, 12, 0);
    repository = LocalReceiptRepository(
      box: HiveConfig.getReceiptsBox(),
      imageStorageService: imageStorage,
      clock: () => currentClock,
    );
  });

  tearDown(() async {
    await HiveConfig.closeAll();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('LocalReceiptRepository — CRUD, Streams, and Image Storage Cleanup', () {
    test(
      'Saves, updates, reads, and deletes receipts while cleaning up image files',
      () async {
        final savedImagePath = await imageStorage.saveReceiptImage(
          receiptId: 'rec-1',
          bytes: Uint8List.fromList(<int>[1, 2, 3, 4, 5]),
        );
        expect(await imageStorage.imageExists(savedImagePath), isTrue);

        final receipt = Receipt(
          id: 'rec-1',
          date: DateTime(2026, 10, 15),
          amount: 28.50,
          merchantName: 'Boulangerie Paul',
          imagePath: savedImagePath,
          category: ReceiptCategories.mealsAndDining,
          createdAt: DateTime(2026, 10, 15, 9, 0),
        );

        await repository.saveReceipt(receipt);
        final fetched = await repository.getReceiptById('rec-1');
        expect(fetched, equals(receipt));

        // Update with a new image and verify the old image is deleted automatically
        final secondImagePath = await imageStorage.saveReceiptImage(
          receiptId: 'rec-1-v2',
          bytes: Uint8List.fromList(<int>[9, 8, 7, 6]),
        );
        final updatedReceipt = receipt.copyWith(
          amount: 32.00,
          imagePath: secondImagePath,
        );
        await repository.updateReceipt(updatedReceipt);

        expect(await imageStorage.imageExists(savedImagePath), isFalse);
        expect(await imageStorage.imageExists(secondImagePath), isTrue);

        final afterUpdate = await repository.getReceiptById('rec-1');
        expect(afterUpdate!.amountMinorUnits, 3200);
        expect(afterUpdate.updatedAt, equals(currentClock));

        // Delete receipt and verify second image is also deleted from disk
        await repository.deleteReceipt('rec-1');
        expect(await repository.getReceiptById('rec-1'), isNull);
        expect(await imageStorage.imageExists(secondImagePath), isFalse);
      },
    );

    test(
      'Cleans up orphaned images not referenced by active receipts',
      () async {
        final activePath = await imageStorage.saveReceiptImage(
          receiptId: 'active-1',
          bytes: Uint8List.fromList(<int>[10, 20, 30]),
        );
        final orphanPath = await imageStorage.saveReceiptImage(
          receiptId: 'orphan-1',
          bytes: Uint8List.fromList(<int>[40, 50, 60]),
        );

        final removed = await imageStorage.cleanupOrphanedImages(<String>{
          activePath,
        });
        expect(removed, 1);
        expect(await imageStorage.imageExists(activePath), isTrue);
        expect(await imageStorage.imageExists(orphanPath), isFalse);
      },
    );

    test('Rejects oversized images exceeding 15 MB', () async {
      final oversized = Uint8List(15 * 1024 * 1024 + 10);
      expect(
        () => imageStorage.saveReceiptImage(
          receiptId: 'oversized',
          bytes: oversized,
        ),
        throwsA(isA<StorageException>()),
      );
    });
  });

  group('LocalReceiptRepository — Dynamic Filtering & Monthly Aggregations', () {
    setUp(() async {
      final sampleReceipts = <Receipt>[
        Receipt(
          id: 'r-sep-1',
          date: DateTime(2026, 9, 18),
          amount: 100.00,
          merchantName: 'Carrefour',
          category: ReceiptCategories.groceries,
          createdAt: DateTime(2026, 9, 18),
        ),
        Receipt(
          id: 'r-oct-1',
          date: DateTime(2026, 10, 5),
          amount: 45.20,
          merchantName: 'Carrefour City',
          category: ReceiptCategories.groceries,
          createdAt: DateTime(2026, 10, 5),
        ),
        Receipt(
          id: 'r-oct-2',
          date: DateTime(2026, 10, 12),
          amount: 79.80,
          merchantName: 'TotalEnergies',
          category: ReceiptCategories.transportAndFuel,
          createdAt: DateTime(2026, 10, 12),
        ),
        Receipt(
          id: 'r-oct-3',
          date: DateTime(2026, 10, 19),
          amount: 25.00,
          merchantName: 'Bistrot Romain',
          category: ReceiptCategories.mealsAndDining,
          createdAt: DateTime(2026, 10, 19),
        ),
      ];

      for (final r in sampleReceipts) {
        await repository.saveReceipt(r);
      }
    });

    test(
      'Computes exact monthly totals, counts, and previous-month comparison',
      () async {
        final octMinorTotal = await repository.getMonthlyTotalMinorUnits(
          year: 2026,
          month: 10,
        );
        expect(octMinorTotal, 15000); // 45.20 + 79.80 + 25.00 = 150.00

        final octSummary = await repository.getMonthlySummary(
          year: 2026,
          month: 10,
        );
        expect(octSummary.totalMinorUnits, 15000);
        expect(octSummary.totalAmount, 150.00);
        expect(octSummary.receiptCount, 3);
        expect(octSummary.previousMonthTotalMinorUnits, 10000);
        expect(octSummary.percentageChangeFromPreviousMonth, 50.0);
        expect(
          octSummary.categoryTotalsMinorUnits[ReceiptCategories.groceries],
          4520,
        );
        expect(
          octSummary.categoryTotalsMinorUnits[ReceiptCategories
              .transportAndFuel],
          7980,
        );
      },
    );

    test(
      'Filters receipts by search query, category, date range, and sort order',
      () async {
        final carrefourResults = await repository.queryReceipts(
          const ReceiptFilter(
            searchQuery: 'carrefour',
            sortOrder: ReceiptSortOrder.amountAsc,
          ),
        );
        expect(carrefourResults.length, 2);
        expect(carrefourResults.first.id, 'r-oct-1');
        expect(carrefourResults.last.id, 'r-sep-1');

        final octoberFiltered = await repository.queryReceipts(
          ReceiptFilter(
            startDate: DateTime(2026, 10, 1),
            endDate: DateTime(2026, 10, 31),
            minAmountMinorUnits: 4000,
            sortOrder: ReceiptSortOrder.amountDesc,
          ),
        );
        expect(octoberFiltered.map((r) => r.id).toList(), <String>[
          'r-oct-2',
          'r-oct-1',
        ]);
      },
    );

    test(
      'Emits reactive updates on watchCurrentMonthReceipts stream',
      () async {
        final firstEmission = await repository
            .watchCurrentMonthReceipts()
            .first;
        expect(firstEmission.length, 3);
      },
    );
  });
}
