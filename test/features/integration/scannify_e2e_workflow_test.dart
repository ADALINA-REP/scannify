import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:scannify/core/providers/core_providers.dart';
import 'package:scannify/features/export/data/services/export_file_dispatcher.dart';
import 'package:scannify/features/export/data/services/local_export_service.dart';
import 'package:scannify/features/export/domain/services/export_service.dart';
import 'package:scannify/features/export/presentation/screens/export_screen.dart';
import 'package:scannify/features/monetization/data/services/default_rewarded_ad_service.dart';
import 'package:scannify/features/monetization/data/services/local_premium_service.dart';
import 'package:scannify/features/monetization/data/services/local_quota_service.dart';
import 'package:scannify/features/monetization/domain/services/ad_service.dart';
import 'package:scannify/features/monetization/domain/services/premium_service.dart';
import 'package:scannify/features/ocr/domain/services/receipt_parser.dart';
import 'package:scannify/features/receipts/data/repositories/in_memory_receipt_repository.dart';
import 'package:scannify/features/receipts/domain/entities/receipt.dart';
import 'package:scannify/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ControllableAdService implements AdService {
  AdRewardOutcome nextOutcome = AdRewardOutcome.rewardEarned;
  int showCount = 0;

  @override
  bool get isSupportedPlatform => true;

  @override
  Future<void> preloadRewardedAd(RewardedPlacement placement) async {}

  @override
  Future<AdRewardResult> showRewardedAd(RewardedPlacement placement) async {
    showCount++;
    return AdRewardResult(
      outcome: nextOutcome,
      placement: placement,
      rewardEventId: nextOutcome == AdRewardOutcome.rewardEarned
          ? 'reward-evt-$showCount'
          : null,
      rewardType: 'reward',
      rewardAmount: 1,
      userMessage: nextOutcome == AdRewardOutcome.adUnavailable
          ? 'No ad inventory available right now.'
          : null,
    );
  }

  @override
  void dispose() {}
}

class _CapturingFileDispatcher extends ExportFileDispatcher {
  final List<GeneratedExportDocument> dispatchedDocuments =
      <GeneratedExportDocument>[];

  @override
  Future<void> dispatch(GeneratedExportDocument document) async {
    dispatchedDocuments.add(document);
  }
}

void main() {
  late SharedPreferences sharedPreferences;
  late AppBootstrapState bootstrapState;
  late InMemoryReceiptRepository repository;
  late LocalPremiumService premiumService;
  late LocalQuotaService quotaService;
  late _ControllableAdService adService;
  late DefaultRewardedAdService rewardedAdService;
  late _CapturingFileDispatcher fileDispatcher;
  late LocalExportService exportService;

  setUpAll(() async {
    await initializeDateFormatting();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sharedPreferences = await SharedPreferences.getInstance();
    repository = InMemoryReceiptRepository();
    premiumService = LocalPremiumService(sharedPreferences: sharedPreferences);
    quotaService = LocalQuotaService(
      sharedPreferences: sharedPreferences,
      premiumService: premiumService,
    );
    adService = _ControllableAdService();
    rewardedAdService = DefaultRewardedAdService(
      adService: adService,
      quotaService: quotaService,
      premiumService: premiumService,
    );
    fileDispatcher = _CapturingFileDispatcher();
    exportService = LocalExportService(
      rewardedAdService: rewardedAdService,
      fileDispatcher: fileDispatcher,
    );
    bootstrapState = AppBootstrapState(
      sharedPreferences: sharedPreferences,
      isHiveInitialized: true,
      isAdMobInitialized: true,
    );
  });

  group('Phase 5 — End-to-End Integration & Monetization Workflows', () {
    test(
      'Complete OCR -> Validation -> Quota -> Rewarded Ad Unlock -> Monthly Summary workflow',
      () async {
        const parser = ReceiptParser();

        // 1. Parse 3 French & international receipts and consume 3 daily free scans
        final receiptsRaw = <String>[
          'CARREFOUR CITY\n12/10/2026\nTOTAL TTC 42,80 €',
          'SNCF VOYAGEURS\n13/10/2026\nMONTANT TOTAL 89.00 EUR',
          'RESTAURANT LE BISTROT\n14/10/2026\nNET A PAYER 31,50 €',
        ];

        for (var i = 0; i < receiptsRaw.length; i++) {
          final statusBefore = await quotaService.getQuotaStatus();
          expect(statusBefore.canScanImmediately, isTrue);

          final parsed = await quotaService.executeQuotaProtectedScan(
            () async => parser.parse(receiptsRaw[i]),
          );
          expect(parsed.totalAmountMinorUnits.value, isNotNull);

          await repository.saveReceipt(
            Receipt.fromMinorUnits(
              id: 'e2e-$i',
              date: parsed.date.value ?? DateTime(2026, 10, 12 + i),
              amountMinorUnits: parsed.totalAmountMinorUnits.value!,
              merchantName: parsed.merchantName.value ?? 'Merchant $i',
              category:
                  parsed.suggestedCategory.value ?? ReceiptCategories.other,
              createdAt: DateTime(2026, 10, 12 + i),
            ),
          );
        }

        // Verify monthly expense calculations in integer minor units
        // 4280 + 8900 + 3150 = 16330 minor units (163.30 EUR)
        final summary = await repository.getMonthlySummary(
          year: 2026,
          month: 10,
        );
        expect(summary.totalMinorUnits, 16330);
        expect(summary.receiptCount, 3);

        // 2. Daily quota is now 0/3 exhausted
        final exhaustedStatus = await quotaService.getQuotaStatus();
        expect(exhaustedStatus.remainingFreeScans, 0);
        expect(exhaustedStatus.canScanImmediately, isFalse);

        // 3. Unavailable ad does NOT grant scan
        adService.nextOutcome = AdRewardOutcome.adUnavailable;
        final failedAdResult = await rewardedAdService
            .unlockAdditionalScanWithAd();
        expect(failedAdResult.isRewardGranted, isFalse);
        expect(
          (await quotaService.getQuotaStatus()).canScanImmediately,
          isFalse,
        );

        // 4. Watching a completed rewarded video grants +1 bonus scan
        adService.nextOutcome = AdRewardOutcome.rewardEarned;
        final rewardedResult = await rewardedAdService
            .unlockAdditionalScanWithAd();
        expect(rewardedResult.isRewardGranted, isTrue);

        final unlockedStatus = await quotaService.getQuotaStatus();
        expect(unlockedStatus.canScanImmediately, isTrue);
        expect(unlockedStatus.bonusScansAvailable, 1);
      },
    );

    testWidgets(
      'ExportScreen enforces Rewarded Ad gate for free users and bypasses ads for Premium users',
      (WidgetTester tester) async {
        final now = DateTime.now();
        await repository.saveReceipt(
          Receipt.fromMinorUnits(
            id: 'exp-1',
            date: DateTime(now.year, now.month, 1),
            amountMinorUnits: 4990,
            merchantName: 'Adobe Creative Cloud',
            category: ReceiptCategories.softwareAndTech,
            createdAt: now,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: <Override>[
              appBootstrapStateProvider.overrideWithValue(bootstrapState),
              receiptRepositoryProvider.overrideWithValue(repository),
              premiumServiceProvider.overrideWithValue(premiumService),
              quotaServiceProvider.overrideWithValue(quotaService),
              adServiceProvider.overrideWithValue(adService),
              rewardedAdServiceProvider.overrideWithValue(rewardedAdService),
              exportServiceProvider.overrideWithValue(exportService),
            ],
            child: const ScannifyApp(),
          ),
        );
        await tester.pumpAndSettle();

        // Dashboard shows the €49.90 receipt
        final homeScrollable = find.byType(Scrollable).first;
        await tester.scrollUntilVisible(
          find.text('Adobe Creative Cloud'),
          150,
          scrollable: homeScrollable,
        );
        expect(find.text('Adobe Creative Cloud'), findsOneWidget);

        // Navigate to Export tab
        await tester.tap(find.text('Export'));
        await tester.pumpAndSettle();

        // Select CSV Spreadsheet format and tap Export CSV Report
        final exportScrollable = find
            .descendant(
              of: find.byType(ExportScreen),
              matching: find.byType(Scrollable),
            )
            .first;

        await tester.tap(find.text('CSV Spreadsheet'));
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('Export CSV Report'),
          200,
          scrollable: exportScrollable,
        );
        await tester.tap(find.text('Export CSV Report'));
        await tester.pumpAndSettle();

        // RewardedAdDialog is shown for free mobile user
        expect(find.text('Unlock Report Export'), findsOneWidget);
        expect(find.text('Watch Video'), findsOneWidget);

        // Confirm Watch Video -> triggers rewarded ad -> generates & shares CSV
        await tester.tap(find.text('Watch Video'));
        await tester.pumpAndSettle();

        expect(adService.showCount, 1);
        expect(fileDispatcher.dispatchedDocuments.length, 1);
        expect(
          fileDispatcher.dispatchedDocuments.first.format,
          ExportFormat.csv,
        );

        // Activate Premium -> exporting bypasses RewardedAdDialog completely
        await premiumService.updateVerifiedEntitlement(
          PremiumEntitlements(
            isPremiumActive: true,
            activePlanId: 'scannify_pro_annual',
            expirationDate: now.add(const Duration(days: 365)),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Export CSV Report'));
        await tester.pumpAndSettle();

        expect(adService.showCount, 1); // No additional ad shown for Premium!
        expect(fileDispatcher.dispatchedDocuments.length, 2);
      },
    );
  });
}
