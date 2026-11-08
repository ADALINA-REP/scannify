import 'admob_config.dart';
import 'admob_initializer_stub.dart'
    if (dart.library.io) 'admob_initializer_io.dart'
    if (dart.library.js_interop) 'admob_initializer_web.dart';

/// Platform-safe facade for initializing Google Mobile Ads only on Android and iOS.
class AdMobInitializer {
  AdMobInitializer._();

  static bool _isInitialized = false;

  /// Whether Google Mobile Ads has been successfully initialized on this device.
  static bool get isInitialized => _isInitialized;

  /// Conditionally initializes Google Mobile Ads on Android and iOS only.
  ///
  /// Safely returns `false` on Web without importing or calling native AdMob APIs.
  static Future<bool> initialize() async {
    if (_isInitialized) return true;
    if (!AdMobConfig.isAdMobSupportedPlatform) {
      _isInitialized = false;
      return false;
    }

    _isInitialized = await initializePlatformAdMob();
    return _isInitialized;
  }
}
