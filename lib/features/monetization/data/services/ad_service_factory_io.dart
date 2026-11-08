import 'dart:io' show Platform;
import '../../domain/services/ad_service.dart';
import 'mobile_ad_service.dart';
import 'web_ad_service.dart';

AdService createPlatformAdService() {
  if (Platform.isAndroid || Platform.isIOS) {
    return MobileAdService();
  }
  return const WebAdService();
}
