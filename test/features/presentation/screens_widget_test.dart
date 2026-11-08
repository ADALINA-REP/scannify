import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:scannify/core/providers/core_providers.dart';
import 'package:scannify/features/ocr/domain/services/ocr_service.dart';
import 'package:scannify/features/ocr/domain/services/receipt_parser.dart';
import 'package:scannify/features/ocr/presentation/screens/receipt_validation_screen.dart';
import 'package:scannify/features/receipts/data/repositories/in_memory_receipt_repository.dart';
import 'package:scannify/features/receipts/domain/entities/receipt.dart';
import 'package:scannify/features/receipts/presentation/screens/receipt_details_screen.dart';
import 'package:scannify/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences sharedPreferences;
  late AppBootstrapState bootstrapState;
  late InMemoryReceiptRepository repository;

  setUpAll(() async {
    await initializeDateFormatting();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sharedPreferences = await SharedPreferences.getInstance();
    repository = InMemoryReceiptRepository();
    bootstrapState = AppBootstrapState(
      sharedPreferences: sharedPreferences,
      isHiveInitialized: true,
      isAdMobInitialized: false,
    );
  });

  group('Phase 4 — User Interfaces & Navigation Shell', () {
    testWidgets(
      'AppShellScreen renders Dashboard, navigates to History, Export, and Settings',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: <Override>[
              appBootstrapStateProvider.overrideWithValue(bootstrapState),
              receiptRepositoryProvider.overrideWithValue(repository),
            ],
            child: const ScannifyApp(),
          ),
        );
        await tester.pumpAndSettle();

        // Dashboard Empty State is shown initially (scroll down if needed)
        await tester.scrollUntilVisible(
          find.text('No receipts this month'),
          200,
        );
        expect(find.text('No receipts this month'), findsOneWidget);
        expect(find.text('Scan Receipt'), findsWidgets);

        // Navigate to History tab
        await tester.tap(find.text('History'));
        await tester.pumpAndSettle();
        expect(find.text('No matching receipts'), findsOneWidget);

        // Navigate to Export tab
        await tester.tap(find.text('Export'));
        await tester.pumpAndSettle();
        expect(find.text('Reporting Period'), findsOneWidget);
        expect(find.text('PDF Report'), findsOneWidget);
        expect(find.text('CSV Spreadsheet'), findsOneWidget);

        // Navigate to Settings tab
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Daily Quota'), findsOneWidget);
        expect(find.text('Appearance'), findsOneWidget);
      },
    );

    testWidgets(
      'ReceiptValidationScreen displays OCR confidence banner and saves edited receipt',
      (WidgetTester tester) async {
        const parser = ReceiptParser();
        final parsed = parser.parse(
          'BOULANGERIE PAUL\n24/10/2026\nTOTAL TTC 18,40 €',
        );
        final scanResult = OcrScanResult(
          rawText: 'BOULANGERIE PAUL\n24/10/2026\nTOTAL TTC 18,40 €',
          parsedReceipt: parsed,
          isAutomaticOcrSupported: true,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: <Override>[
              appBootstrapStateProvider.overrideWithValue(bootstrapState),
              receiptRepositoryProvider.overrideWithValue(repository),
            ],
            child: MaterialApp(
              home: ReceiptValidationScreen(ocrScanResult: scanResult),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify prefilled OCR values
        expect(find.text('BOULANGERIE PAUL'), findsOneWidget);
        expect(find.text('18.40'), findsOneWidget);

        // Scroll to and tap Save Receipt
        await tester.scrollUntilVisible(
          find.text('Save Receipt'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Save Receipt'));
        await tester.pumpAndSettle();

        expect(repository.entries.length, 1);
        final saved = repository.entries.values.first;
        expect(saved.merchantName, 'BOULANGERIE PAUL');
        expect(saved.amountMinorUnits, 1840);
        expect(saved.category, ReceiptCategories.mealsAndDining);
      },
    );

    testWidgets(
      'ReceiptDetailsScreen displays receipt metadata and deletes with confirmation',
      (WidgetTester tester) async {
        final receipt = Receipt(
          id: 'detail-test-1',
          date: DateTime(2026, 10, 20),
          amount: 65.00,
          merchantName: 'FNAC Champs-Élysées',
          category: ReceiptCategories.officeSupplies,
          createdAt: DateTime(2026, 10, 20, 10, 0),
        );
        await repository.saveReceipt(receipt);

        await tester.pumpWidget(
          ProviderScope(
            overrides: <Override>[
              appBootstrapStateProvider.overrideWithValue(bootstrapState),
              receiptRepositoryProvider.overrideWithValue(repository),
            ],
            child: const MaterialApp(
              home: ReceiptDetailsScreen(receiptId: 'detail-test-1'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('FNAC Champs-Élysées'), findsOneWidget);
        expect(find.text('Office Supplies'), findsWidgets);

        // Tap Delete button and confirm in ConfirmationDialog
        await tester.scrollUntilVisible(
          find.text('Delete'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        expect(find.text('Delete this receipt?'), findsOneWidget);
        await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
        await tester.pumpAndSettle();

        expect(await repository.getReceiptById('detail-test-1'), isNull);
      },
    );
  });
}
