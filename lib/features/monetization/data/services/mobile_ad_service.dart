import '../../domain/services/ad_service.dart';

/// Ad-free mobile implementation of [AdService].
class MobileAdService implements AdService {
  MobileAdService();

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
