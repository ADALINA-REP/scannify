import 'package:meta/meta.dart';

/// Placement context for a rewarded video advertisement.
enum RewardedPlacement { extraScan, exportDocument }

/// Outcome of presenting a rewarded video advertisement to the user.
enum AdRewardOutcome {
  /// User watched the video and the official `onUserEarnedReward` callback fired.
  rewardEarned,

  /// User closed the advertisement before earning the reward.
  dismissedWithoutReward,

  /// No ad inventory was available or the network/SDK could not load an ad.
  adUnavailable,

  /// A concurrent ad request is already active.
  requestAlreadyInProgress,

  /// Platform does not support native AdMob (e.g. Web) or user has Premium ad-free entitlement.
  notRequiredOnPlatform,
}

/// Result returned after attempting to show a rewarded advertisement.
@immutable
class AdRewardResult {
  const AdRewardResult({
    required this.outcome,
    required this.placement,
    this.rewardEventId,
    this.rewardType,
    this.rewardAmount,
    this.userMessage,
  });

  final AdRewardOutcome outcome;
  final RewardedPlacement placement;

  /// Unique single-use identifier generated only when `onUserEarnedReward` fires.
  final String? rewardEventId;
  final String? rewardType;
  final int? rewardAmount;

  /// Clear human-readable explanation when an ad is unavailable or dismissed.
  final String? userMessage;

  /// Whether the user is authorized to receive the unlocked action.
  bool get isRewardGranted =>
      outcome == AdRewardOutcome.rewardEarned ||
      outcome == AdRewardOutcome.notRequiredOnPlatform;
}

/// Low-level contract for loading and presenting AdMob Rewarded Ads.
abstract interface class AdService {
  /// Whether rewarded advertisements are supported on the active runtime platform.
  bool get isSupportedPlatform;

  /// Preloads a rewarded ad for [placement] in the background if supported.
  Future<void> preloadRewardedAd(RewardedPlacement placement);

  /// Shows a rewarded ad for [placement] and resolves only after the ad lifecycle
  /// completes, granting `rewardEarned` strictly inside `onUserEarnedReward`.
  Future<AdRewardResult> showRewardedAd(RewardedPlacement placement);

  /// Disposes any cached ad objects.
  void dispose();
}

/// High-level orchestrator combining [AdService], [QuotaService], and [PremiumService]
/// to handle rewarded scan unlocks and rewarded CSV/PDF export unlocks.
abstract interface class RewardedAdService {
  /// Preloads rewarded ads for faster presentation on supported platforms.
  Future<void> warmupAds();

  /// Presents a rewarded video to unlock 1 additional daily OCR scan, and
  /// credits [QuotaService] strictly upon official reward confirmation.
  Future<AdRewardResult> unlockAdditionalScanWithAd();

  /// Presents a rewarded video required before generating a CSV or PDF export
  /// on supported mobile platforms (unless the user has Scannify Premium).
  Future<AdRewardResult> unlockExportWithAd();
}
