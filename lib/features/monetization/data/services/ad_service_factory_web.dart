import '../../domain/services/ad_service.dart';
import 'web_ad_service.dart';

AdService createPlatformAdService() {
  return const WebAdService();
}
