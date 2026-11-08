import '../../domain/services/ad_service.dart';

/// Web/non-mobile implementation of [AdService] where native Google Mobile Ads
/// SDK is not supported.
class WebAdService implements AdService {
  const WebAdService();

  @override
  bool get isSupportedPlatform => false;

  @override
  Future<void> preloadRewardedAd(RewardedPlacement placement) async {}

  @override
  Future<AdRewardResult> showRewardedAd(RewardedPlacement placement) async {
    return AdRewardResult(
      outcome: AdRewardOutcome.notRequiredOnPlatform,
      placement: placement,
    );
  }

  @override
  void dispose() {}
}
