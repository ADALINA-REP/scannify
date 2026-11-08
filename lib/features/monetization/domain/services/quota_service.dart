import 'package:meta/meta.dart';

/// Immutable snapshot of the user's daily OCR scan quota state.
@immutable
class QuotaStatus {
  const QuotaStatus({
    required this.dailyFreeLimit,
    required this.freeScansConsumed,
    required this.bonusScansAvailable,
    required this.lastResetDateKey,
    required this.isUnlimitedPremium,
  });

  /// Default daily free scan allowance (`3`).
  final int dailyFreeLimit;

  /// Number of free daily scans consumed today (`0` to [dailyFreeLimit]).
  final int freeScansConsumed;

  /// Additional scans unlocked via rewarded video ads that have not yet been used.
  final int bonusScansAvailable;

  /// Local calendar date key (`YYYY-MM-DD`) of the last midnight reset.
  final String lastResetDateKey;

  /// Whether the user has unlimited scans via Scannify Premium.
  final bool isUnlimitedPremium;

  /// Remaining free daily scans (`0` to [dailyFreeLimit]).
  int get remainingFreeScans =>
      (dailyFreeLimit - freeScansConsumed).clamp(0, dailyFreeLimit);

  /// Total scans currently available (free remaining + rewarded bonus scans).
  int get totalAvailableScans => remainingFreeScans + bonusScansAvailable;

  /// Whether the user can immediately perform an automatic OCR scan without
  /// watching a rewarded advertisement.
  bool get canScanImmediately => isUnlimitedPremium || totalAvailableScans > 0;

  /// Whether the user has exhausted their daily free quota and has no bonus scans left.
  bool get requiresRewardedAdForNextScan =>
      !isUnlimitedPremium && totalAvailableScans <= 0;
}

/// Abstract service managing daily free OCR scan quotas and rewarded scan unlocks.
abstract interface class QuotaService {
  static const int defaultDailyFreeScanLimit = 3;

  /// Standard prompt displayed when daily free scans reach zero.
  static const String quotaExhaustedMessage =
      "You've used your 3 free scans for today. Watch a short video to unlock one additional scan.";

  /// Returns the current [QuotaStatus], automatically applying local midnight reset if needed.
  Future<QuotaStatus> getQuotaStatus();

  /// Reactive stream of [QuotaStatus] updates.
  Stream<QuotaStatus> watchQuotaStatus();

  /// Executes [ocrOperation] under quota protection:
  /// - Prevents concurrent/duplicate click executions.
  /// - Verifies that a scan quota (or Premium entitlement) is available.
  /// - Consumes exactly 1 scan ONLY if [ocrOperation] succeeds without throwing a technical error.
  Future<T> executeQuotaProtectedScan<T>(Future<T> Function() ocrOperation);

  /// Grants 1 bonus scan after a verified AdMob `onUserEarnedReward` callback.
  ///
  /// Uses [rewardEventId] to prevent duplicate rewards from the same ad session.
  Future<QuotaStatus> grantRewardedScan({required String rewardEventId});
}
