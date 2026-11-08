import 'package:flutter_test/flutter_test.dart';
import 'package:scannify/core/errors/app_exception.dart';
import 'package:scannify/features/monetization/data/services/default_rewarded_ad_service.dart';
import 'package:scannify/features/monetization/data/services/local_premium_service.dart';
import 'package:scannify/features/monetization/data/services/local_quota_service.dart';
import 'package:scannify/features/monetization/domain/services/ad_service.dart';
import 'package:scannify/features/monetization/domain/services/premium_service.dart';
import 'package:scannify/features/monetization/domain/services/quota_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAdService implements AdService {
  _MockAdService();

  @override
  final bool isSupportedPlatform = true;

  AdRewardResult? nextResult;
  int showCallCount = 0;

  @override
  Future<void> preloadRewardedAd(RewardedPlacement placement) async {}

  @override
  Future<AdRewardResult> showRewardedAd(RewardedPlacement placement) async {
    showCallCount++;
    return nextResult ??
        AdRewardResult(
          outcome: AdRewardOutcome.rewardEarned,
          placement: placement,
          rewardEventId: 'reward-event-$showCallCount',
          rewardType: 'scan',
          rewardAmount: 1,
        );
  }

  @override
  void dispose() {}
}

void main() {
  late SharedPreferences prefs;
  late DateTime simulatedNow;
  late LocalPremiumService premiumService;
  late LocalQuotaService quotaService;
  late _MockAdService mockAdService;
  late DefaultRewardedAdService rewardedAdService;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    simulatedNow = DateTime(2026, 10, 20, 14, 0);

    premiumService = LocalPremiumService(
      sharedPreferences: prefs,
      clock: () => simulatedNow,
    );
    quotaService = LocalQuotaService(
      sharedPreferences: prefs,
      premiumService: premiumService,
      clock: () => simulatedNow,
    );
    mockAdService = _MockAdService();
    rewardedAdService = DefaultRewardedAdService(
      adService: mockAdService,
      quotaService: quotaService,
      premiumService: premiumService,
    );
  });

  tearDown(() {
    quotaService.dispose();
    premiumService.dispose();
  });

  group('LocalQuotaService — 3 Free Daily Scans, Midnight Reset & Error Safety', () {
    test(
      'Provides 3 daily free scans and blocks the 4th scan until rewarded ad or midnight reset',
      () async {
        final initial = await quotaService.getQuotaStatus();
        expect(initial.remainingFreeScans, 3);
        expect(initial.canScanImmediately, isTrue);

        // Consume all 3 free scans
        for (int i = 1; i <= 3; i++) {
          await quotaService.executeQuotaProtectedScan<String>(
            () async => 'scan-$i',
          );
        }

        final afterThree = await quotaService.getQuotaStatus();
        expect(afterThree.remainingFreeScans, 0);
        expect(afterThree.totalAvailableScans, 0);
        expect(afterThree.requiresRewardedAdForNextScan, isTrue);

        // 4th scan must fail with QUOTA_EXHAUSTED and exact required message
        await expectLater(
          () => quotaService.executeQuotaProtectedScan<String>(
            () async => 'scan-4',
          ),
          throwsA(
            isA<MonetizationException>()
                .having((e) => e.code, 'code', 'QUOTA_EXHAUSTED')
                .having(
                  (e) => e.message,
                  'message',
                  QuotaService.quotaExhaustedMessage,
                ),
          ),
        );
      },
    );

    test(
      'Does NOT consume scan quota when OCR fails due to a technical error',
      () async {
        await expectLater(
          () => quotaService.executeQuotaProtectedScan<void>(() async {
            throw const OcrException(message: 'Simulated camera/MLKit failure');
          }),
          throwsA(isA<OcrException>()),
        );

        final status = await quotaService.getQuotaStatus();
        expect(status.freeScansConsumed, 0);
        expect(status.remainingFreeScans, 3);
      },
    );

    test('Resets quota to 3 free scans at local midnight', () async {
      for (int i = 0; i < 3; i++) {
        await quotaService.executeQuotaProtectedScan<void>(() async {});
      }
      expect((await quotaService.getQuotaStatus()).remainingFreeScans, 0);

      // Advance clock past local midnight to 2026-10-21 00:01
      simulatedNow = DateTime(2026, 10, 21, 0, 1);

      final nextDayStatus = await quotaService.getQuotaStatus();
      expect(nextDayStatus.remainingFreeScans, 3);
      expect(nextDayStatus.freeScansConsumed, 0);
      expect(nextDayStatus.lastResetDateKey, '2026-10-21');
    });

    test(
      'Grants 1 bonus scan only upon confirmed rewarded ad and prevents duplicate reward IDs',
      () async {
        for (int i = 0; i < 3; i++) {
          await quotaService.executeQuotaProtectedScan<void>(() async {});
        }
        expect(
          (await quotaService.getQuotaStatus()).canScanImmediately,
          isFalse,
        );

        // User dismisses ad early -> no bonus scan granted
        mockAdService.nextResult = const AdRewardResult(
          outcome: AdRewardOutcome.dismissedWithoutReward,
          placement: RewardedPlacement.extraScan,
        );
        final dismissedResult = await rewardedAdService
            .unlockAdditionalScanWithAd();
        expect(dismissedResult.isRewardGranted, isFalse);
        expect((await quotaService.getQuotaStatus()).bonusScansAvailable, 0);

        // User completes ad -> onUserEarnedReward grants 1 bonus scan
        mockAdService.nextResult = const AdRewardResult(
          outcome: AdRewardOutcome.rewardEarned,
          placement: RewardedPlacement.extraScan,
          rewardEventId: 'unique-reward-101',
        );
        final earnedResult = await rewardedAdService
            .unlockAdditionalScanWithAd();
        expect(earnedResult.isRewardGranted, isTrue);
        expect((await quotaService.getQuotaStatus()).bonusScansAvailable, 1);

        // Replay of the same rewardEventId is ignored (duplicate prevention)
        await quotaService.grantRewardedScan(
          rewardEventId: 'unique-reward-101',
        );
        expect((await quotaService.getQuotaStatus()).bonusScansAvailable, 1);

        // Consuming the bonus scan succeeds and decrements bonusScansAvailable back to 0
        await quotaService.executeQuotaProtectedScan<void>(() async {});
        expect((await quotaService.getQuotaStatus()).bonusScansAvailable, 0);
      },
    );

    test(
      'Premium entitlement unlocks unlimited scans and ad-free exports',
      () async {
        await premiumService.updateVerifiedEntitlement(
          PremiumEntitlements(
            isPremiumActive: true,
            activePlanId: 'scannify_pro_monthly',
            expirationDate: DateTime(2026, 12, 31),
          ),
        );

        final status = await quotaService.getQuotaStatus();
        expect(status.isUnlimitedPremium, isTrue);
        expect(status.canScanImmediately, isTrue);

        final exportAdResult = await rewardedAdService.unlockExportWithAd();
        expect(exportAdResult.outcome, AdRewardOutcome.notRequiredOnPlatform);
        expect(mockAdService.showCallCount, 0);
      },
    );
  });
}
