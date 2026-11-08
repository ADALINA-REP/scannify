import '../../domain/services/ad_service.dart';
import 'ad_service_factory_stub.dart'
    if (dart.library.io) 'ad_service_factory_io.dart'
    if (dart.library.js_interop) 'ad_service_factory_web.dart';

/// Platform-safe factory creating [AdService] (`MobileAdService` on Android/iOS,
/// `WebAdService` on Web) without exposing native AdMob imports to Web builds.
class AdServiceFactory {
  AdServiceFactory._();

  static AdService create() => createPlatformAdService();
}
