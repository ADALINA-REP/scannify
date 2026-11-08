import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:scannify/features/export/data/services/export_file_dispatcher.dart';
import 'package:scannify/features/export/data/services/local_export_service.dart';
import 'package:scannify/features/export/domain/services/export_service.dart';
import 'package:scannify/features/monetization/domain/services/ad_service.dart';
import 'package:scannify/features/receipts/domain/entities/receipt.dart';

class _FakeRewardedAdService implements RewardedAdService {
  AdRewardResult nextExportResult = const AdRewardResult(
    outcome: AdRewardOutcome.rewardEarned,
    placement: RewardedPlacement.exportDocument,
    rewardEventId: 'export-reward-1',
  );

  @override
  Future<void> warmupAds() async {}

  @override
  Future<AdRewardResult> unlockAdditionalScanWithAd() async {
    throw UnimplementedError();
  }

  @override
  Future<AdRewardResult> unlockExportWithAd() async {
    return nextExportResult;
  }
}

class _FakeExportFileDispatcher extends ExportFileDispatcher {
  GeneratedExportDocument? lastDispatchedDocument;

  @override
  Future<void> dispatch(GeneratedExportDocument document) async {
    lastDispatchedDocument = document;
  }
}

void main() {
  late _FakeRewardedAdService fakeRewardedAdService;
  late _FakeExportFileDispatcher fakeDispatcher;
  late LocalExportService exportService;
  late List<Receipt> sampleReceipts;

  setUp(() {
    fakeRewardedAdService = _FakeRewardedAdService();
    fakeDispatcher = _FakeExportFileDispatcher();
    exportService = LocalExportService(
      rewardedAdService: fakeRewardedAdService,
      fileDispatcher: fakeDispatcher,
      clock: () => DateTime(2026, 10, 31, 16, 30),
    );

    sampleReceipts = <Receipt>[
      Receipt(
        id: '1',
        date: DateTime(2026, 10, 5),
        amount: 14.50,
        merchantName: 'Boulangerie "L\'Épi d\'Or", Paris',
        category: ReceiptCategories.mealsAndDining,
        createdAt: DateTime(2026, 10, 5),
      ),
      Receipt(
        id: '2',
        date: DateTime(2026, 10, 12),
        amount: 85.50,
        merchantName: '=HYPERLINK("http://malicious")',
        category: ReceiptCategories.officeSupplies,
        createdAt: DateTime(2026, 10, 12),
      ),
    ];
  });

  group('LocalExportService — CSV, PDF, and Rewarded Export Gate', () {
    test(
      'Generates UTF-8 CSV with BOM, proper quote/comma escaping, and formula sanitization',
      () async {
        final doc = await exportService.generateCsv(
          ExportRequest(
            receipts: sampleReceipts,
            format: ExportFormat.csv,
            periodLabel: 'October 2026',
          ),
        );

        expect(doc.format, ExportFormat.csv);
        expect(doc.totalMinorUnits, 10000); // 14.50 + 85.50 = 100.00
        expect(doc.totalAmount, 100.00);
        expect(doc.receiptCount, 2);
        expect(doc.fileName, 'scannify_export_october_2026_2026-10-31.csv');

        // Verify UTF-8 BOM bytes (0xEF, 0xBB, 0xBF) for Excel compatibility
        expect(doc.bytes.sublist(0, 3), <int>[0xEF, 0xBB, 0xBF]);
        final decoded = utf8.decode(doc.bytes);
        expect(decoded.startsWith('Date,Merchant,Category,Amount'), isTrue);
        // Verify CSV escaping of quotes and commas
        expect(
          decoded.contains('"Boulangerie ""L\'Épi d\'Or"", Paris"'),
          isTrue,
        );
        // Verify spreadsheet formula injection sanitization
        expect(decoded.contains("'=HYPERLINK"), isTrue);
        expect(decoded.contains('14.50'), isTrue);
        expect(decoded.contains('85.50'), isTrue);
      },
    );

    test(
      'Generates professional branded PDF report with valid %PDF header',
      () async {
        final doc = await exportService.generatePdf(
          ExportRequest(
            receipts: sampleReceipts,
            format: ExportFormat.pdf,
            periodLabel: 'October 2026',
            reportTitle: 'Monthly Expense Statement',
          ),
        );

        expect(doc.format, ExportFormat.pdf);
        expect(doc.totalMinorUnits, 10000);
        expect(doc.receiptCount, 2);
        expect(doc.fileName, 'scannify_export_october_2026_2026-10-31.pdf');
        expect(doc.bytes.lengthInBytes, greaterThan(1000));

        final asciiHeader = ascii.decode(doc.bytes.sublist(0, 5));
        expect(asciiHeader, '%PDF-');
      },
    );

    test(
      'Strictly blocks file generation when rewarded advertisement is dismissed or unavailable',
      () async {
        fakeRewardedAdService.nextExportResult = const AdRewardResult(
          outcome: AdRewardOutcome.dismissedWithoutReward,
          placement: RewardedPlacement.exportDocument,
          userMessage: 'Watch the full video to unlock your export.',
        );

        final blockedResult = await exportService.executeRewardedExport(
          ExportRequest(
            receipts: sampleReceipts,
            format: ExportFormat.pdf,
            periodLabel: 'October 2026',
          ),
        );

        expect(blockedResult.isSuccess, isFalse);
        expect(blockedResult.document, isNull);
        expect(fakeDispatcher.lastDispatchedDocument, isNull);

        // Now confirm reward -> file is generated and dispatched
        fakeRewardedAdService.nextExportResult = const AdRewardResult(
          outcome: AdRewardOutcome.rewardEarned,
          placement: RewardedPlacement.exportDocument,
          rewardEventId: 'reward-ok-99',
        );

        final grantedResult = await exportService.executeRewardedExport(
          ExportRequest(
            receipts: sampleReceipts,
            format: ExportFormat.pdf,
            periodLabel: 'October 2026',
          ),
        );

        expect(grantedResult.isSuccess, isTrue);
        expect(grantedResult.document, isNotNull);
        expect(
          fakeDispatcher.lastDispatchedDocument,
          equals(grantedResult.document),
        );
      },
    );
  });
}
