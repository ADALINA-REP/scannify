import '../logging/app_logger.dart';

/// Native mobile (Android & iOS) implementation.
///
/// Advertisements are disabled for a 100% free, private user experience.
Future<bool> initializePlatformAdMob() async {
  AppLogger.info(
    'AdMobInitializer',
    'Advertisements disabled: 100% ad-free, private experience enabled.',
  );
  return false;
}
