import '../../domain/services/ad_service.dart';
import '../../domain/services/premium_service.dart';
import '../../domain/services/quota_service.dart';

/// Default implementation of [RewardedAdService] coordinating [AdService],
/// [QuotaService], and [PremiumService].
class DefaultRewardedAdService implements RewardedAdService {
  DefaultRewardedAdService({
    required AdService adService,
    required QuotaService quotaService,
    required PremiumService premiumService,
  }) : _adService = adService,
       _quotaService = quotaService,
       _premiumService = premiumService;

  final AdService _adService;
  final QuotaService _quotaService;
  final PremiumService _premiumService;

  @override
  Future<void> warmupAds() async {
    if (!_adService.isSupportedPlatform) return;
    if (_premiumService.currentEntitlements.isAdFree) return;

    await Future.wait(<Future<void>>[
      _adService.preloadRewardedAd(RewardedPlacement.extraScan),
      _adService.preloadRewardedAd(RewardedPlacement.exportDocument),
    ]);
  }

  @override
  Future<AdRewardResult> unlockAdditionalScanWithAd() async {
    if (_premiumService.currentEntitlements.hasUnlimitedOcrScans) {
      return const AdRewardResult(
        outcome: AdRewardOutcome.notRequiredOnPlatform,
        placement: RewardedPlacement.extraScan,
      );
    }

    final result = await _adService.showRewardedAd(RewardedPlacement.extraScan);

    // Strictly grant the additional scan ONLY after official reward confirmation.
    if (result.outcome == AdRewardOutcome.rewardEarned &&
        result.rewardEventId != null) {
      await _quotaService.grantRewardedScan(
        rewardEventId: result.rewardEventId!,
      );
    }

    return result;
  }

  @override
  Future<AdRewardResult> unlockExportWithAd() async {
    if (_premiumService.currentEntitlements.hasAdFreeExports ||
        !_adService.isSupportedPlatform) {
      return const AdRewardResult(
        outcome: AdRewardOutcome.notRequiredOnPlatform,
        placement: RewardedPlacement.exportDocument,
      );
    }

    return _adService.showRewardedAd(RewardedPlacement.exportDocument);
  }
}
