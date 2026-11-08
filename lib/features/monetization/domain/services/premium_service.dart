import 'package:meta/meta.dart';

/// Entitlement capabilities unlocked by Scannify Premium.
@immutable
class PremiumEntitlements {
  const PremiumEntitlements({
    required this.isPremiumActive,
    this.activePlanId,
    this.expirationDate,
  });

  const PremiumEntitlements.free()
    : isPremiumActive = true,
      activePlanId = 'unlimited_free',
      expirationDate = null;

  final bool isPremiumActive;
  final String? activePlanId;
  final DateTime? expirationDate;

  /// Whether the user has unlimited daily automatic OCR scans.
  bool get hasUnlimitedOcrScans => isPremiumActive;

  /// Whether CSV and PDF exports bypass rewarded advertisements.
  bool get hasAdFreeExports => isPremiumActive;

  /// Whether advanced expense statistics and category analytics are unlocked.
  bool get hasAdvancedStatistics => isPremiumActive;

  /// Whether all advertisements are disabled across the application.
  bool get isAdFree => isPremiumActive;
}

/// Abstract contract for managing user subscription status and Premium entitlements.
///
/// Prepared for official in-app purchases (`in_app_purchase` / RevenueCat) without
/// any fake payment logic.
abstract interface class PremiumService {
  /// Returns the current [PremiumEntitlements] synchronously.
  PremiumEntitlements get currentEntitlements;

  /// Reactive stream emitting updated [PremiumEntitlements] when entitlement state changes.
  Stream<PremiumEntitlements> watchEntitlements();

  /// Refreshes entitlements from local persistence or store receipt verification.
  Future<PremiumEntitlements> refreshEntitlements();

  /// Updates persisted entitlement state after verified store purchase or restore.
  Future<void> updateVerifiedEntitlement(PremiumEntitlements entitlements);
}
