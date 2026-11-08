import '../../domain/services/ad_service.dart';

AdService createPlatformAdService() {
  throw UnsupportedError(
    'Cannot create AdService without dart:io or dart:js_interop.',
  );
}
