import '../logging/app_logger.dart';

/// Web no-op implementation of AdMob initialization.
///
/// Guarantees that `google_mobile_ads` is never initialized or invoked on Web.
Future<bool> initializePlatformAdMob() async {
  AppLogger.info(
    'AdMobInitializer',
    'Web platform detected: Google Mobile Ads initialization skipped.',
  );
  return false;
}
