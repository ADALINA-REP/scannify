import 'package:flutter/foundation.dart';

/// Centralized AdMob configuration with strict separation between official
/// Google test ad unit IDs (used in debug/profile builds) and production ad
/// unit IDs (injected via `--dart-define` for release builds).
abstract final class AdMobConfig {
  /// Official Google AdMob test Rewarded Ad Unit ID for Android.
  static const String androidTestRewardedAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';

  /// Official Google AdMob test Rewarded Ad Unit ID for iOS.
  static const String iosTestRewardedAdUnitId =
      'ca-app-pub-3940256099942544/1712485313';

  /// Production Android Rewarded Ad Unit ID for unlocking an extra OCR scan.
  static const String _androidProdScanRewardedId = String.fromEnvironment(
    'ADMOB_ANDROID_SCAN_REWARDED_ID',
    defaultValue: androidTestRewardedAdUnitId,
  );

  /// Production iOS Rewarded Ad Unit ID for unlocking an extra OCR scan.
  static const String _iosProdScanRewardedId = String.fromEnvironment(
    'ADMOB_IOS_SCAN_REWARDED_ID',
    defaultValue: iosTestRewardedAdUnitId,
  );

  /// Production Android Rewarded Ad Unit ID for unlocking CSV/PDF export.
  static const String _androidProdExportRewardedId = String.fromEnvironment(
    'ADMOB_ANDROID_EXPORT_REWARDED_ID',
    defaultValue: androidTestRewardedAdUnitId,
  );

  /// Production iOS Rewarded Ad Unit ID for unlocking CSV/PDF export.
  static const String _iosProdExportRewardedId = String.fromEnvironment(
    'ADMOB_IOS_EXPORT_REWARDED_ID',
    defaultValue: iosTestRewardedAdUnitId,
  );

  /// Whether Google Mobile Ads is supported on the active runtime platform.
  ///
  /// Permanently disabled for 100% ad-free experience.
  static bool get isAdMobSupportedPlatform => false;

  /// Resolves the Rewarded Ad Unit ID for unlocking an extra daily scan.
  static String? get scanRewardedAdUnitId {
    if (!isAdMobSupportedPlatform) return null;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return kReleaseMode
          ? _androidProdScanRewardedId
          : androidTestRewardedAdUnitId;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return kReleaseMode ? _iosProdScanRewardedId : iosTestRewardedAdUnitId;
    }
    return null;
  }

  /// Resolves the Rewarded Ad Unit ID for unlocking CSV/PDF export.
  static String? get exportRewardedAdUnitId {
    if (!isAdMobSupportedPlatform) return null;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return kReleaseMode
          ? _androidProdExportRewardedId
          : androidTestRewardedAdUnitId;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return kReleaseMode ? _iosProdExportRewardedId : iosTestRewardedAdUnitId;
    }
    return null;
  }
}
