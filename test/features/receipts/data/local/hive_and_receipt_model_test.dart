import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:scannify/core/errors/app_exception.dart';
import 'package:scannify/core/logging/app_logger.dart';
import 'package:scannify/features/receipts/data/local/hive_registrar.dart';
import 'package:scannify/features/receipts/domain/entities/receipt.dart';
import 'package:scannify/features/receipts/domain/repositories/receipt_repository.dart';

void main() {
  group('Receipt Domain Model & Monetary Precision', () {
    test('Stores amounts internally as exact integer minor units (cents)', () {
      // Classic IEEE 754 floating-point trap: 0.1 + 0.2 = 0.30000000000000004
      final r1 = Receipt(
        id: 'r-1',
        date: DateTime(2026, 10, 1),
        amount: 0.10,
        merchantName: 'Cafe Un',
        category: ReceiptCategories.mealsAndDining,
        createdAt: DateTime(2026, 10, 1),
      );
      final r2 = Receipt(
        id: 'r-2',
        date: DateTime(2026, 10, 2),
        amount: 0.20,
        merchantName: 'Cafe Deux',
        category: ReceiptCategories.mealsAndDining,
        createdAt: DateTime(2026, 10, 2),
      );

      expect(r1.amountMinorUnits, 10);
      expect(r2.amountMinorUnits, 20);

      final sumMinorUnits = r1.amountMinorUnits + r2.amountMinorUnits;
      expect(sumMinorUnits, 30);
      expect(Receipt.minorToMajorUnits(sumMinorUnits), 0.30);
    });

    test('Validates domain invariants', () {
      final invalidReceipt = Receipt(
        id: 'r-invalid',
        date: DateTime(2026, 10, 1),
        amount: -5.00,
        merchantName: 'Test Merchant',
        category: ReceiptCategories.other,
        createdAt: DateTime(2026, 10, 1),
      );

      expect(
        () => invalidReceipt.validate(),
        throwsA(isA<ValidationException>()),
      );
    });

    test(
      'MonthlyExpenseSummary computes exact totals and percentage comparison',
      () {
        const summary = MonthlyExpenseSummary(
          year: 2026,
          month: 10,
          totalMinorUnits: 15000, // 150.00
          receiptCount: 4,
          previousMonthTotalMinorUnits: 12000, // 120.00
          categoryTotalsMinorUnits: <String, int>{
            ReceiptCategories.groceries: 10000,
            ReceiptCategories.mealsAndDining: 5000,
          },
        );

        expect(summary.totalAmount, 150.00);
        expect(summary.previousMonthTotalAmount, 120.00);
        expect(summary.percentageChangeFromPreviousMonth, 25.0);
      },
    );
  });

  group('HiveConfig & Schema Migration Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('scannify_hive_test_');
    });

    tearDown(() async {
      await HiveConfig.closeAll();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'Initializes Hive CE, persists Receipt entities, and survives reopen',
      () async {
        await HiveConfig.initialize(testDirectoryPath: tempDir.path);
        final box = HiveConfig.getReceiptsBox();

        final receipt = Receipt(
          id: 'uuid-1234',
          date: DateTime(2026, 10, 15),
          amount: 42.85,
          merchantName: 'Monoprix',
          imagePath: '/private/receipts/uuid-1234.jpg',
          category: ReceiptCategories.groceries,
          createdAt: DateTime(2026, 10, 15, 14, 30),
        );

        await box.put(receipt.id, receipt);
        await HiveConfig.closeAll();

        // Reopen from disk and verify persistence
        await HiveConfig.initialize(testDirectoryPath: tempDir.path);
        final reopenedBox = HiveConfig.getReceiptsBox();
        final loaded = reopenedBox.get('uuid-1234');

        expect(loaded, isNotNull);
        expect(loaded, equals(receipt));
        expect(loaded!.amountMinorUnits, 4285);
        expect(loaded.amount, 42.85);
        expect(loaded.imagePath, '/private/receipts/uuid-1234.jpg');
      },
    );

    test(
      'Migrates schema v1 records to v2 and normalizes empty fields',
      () async {
        Hive.init(tempDir.path);
        HiveConfig.registerAdapters();

        final metaBox = await Hive.openBox<dynamic>(HiveConfig.metadataBoxName);
        final receiptsBox = await Hive.openBox<Receipt>(
          HiveConfig.receiptsBoxName,
        );

        // Simulate a legacy v1 state with empty category & merchant name
        await metaBox.put(HiveConfig.schemaVersionKey, 1);
        await receiptsBox.put(
          'legacy-1',
          Receipt.fromMinorUnits(
            id: 'legacy-1',
            date: DateTime(2026, 9, 10),
            amountMinorUnits: 1990,
            merchantName: '   ',
            category: '',
            createdAt: DateTime(2026, 9, 10),
          ),
        );

        await HiveConfig.runMigrationsIfNeeded(
          metaBox: metaBox,
          receiptsBox: receiptsBox,
        );

        expect(
          metaBox.get(HiveConfig.schemaVersionKey),
          HiveConfig.currentSchemaVersion,
        );
        final migrated = receiptsBox.get('legacy-1')!;
        expect(migrated.merchantName, 'Unknown Merchant');
        expect(migrated.category, ReceiptCategories.other);
        expect(migrated.amountMinorUnits, 1990);
      },
    );
  });

  group('AppLogger Privacy Redaction', () {
    test(
      'Redacts SIRET numbers, amounts, and phone numbers from log messages',
      () {
        const rawLog =
            'Parsed SIRET 81234567800021 with total 145,80 € and tel 01 42 68 55 10';
        final sanitized = AppLogger.sanitize(rawLog);

        expect(sanitized.contains('81234567800021'), isFalse);
        expect(sanitized.contains('145,80 €'), isFalse);
        expect(sanitized.contains('01 42 68 55 10'), isFalse);
        expect(sanitized.contains('[REDACTED_ID]'), isTrue);
        expect(sanitized.contains('[REDACTED_AMOUNT]'), isTrue);
        expect(sanitized.contains('[REDACTED_PHONE]'), isTrue);
      },
    );
  });
}
