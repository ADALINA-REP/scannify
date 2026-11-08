import '../../domain/services/ocr_service.dart';
import '../../domain/services/receipt_parser.dart';
import 'ocr_service_factory_stub.dart'
    if (dart.library.io) 'ocr_service_factory_io.dart'
    if (dart.library.js_interop) 'ocr_service_factory_web.dart';

/// Factory creating the appropriate [OcrService] for the active platform
/// (`MobileOcrService` on Android/iOS, `WebOcrService` on Web) without
/// exposing native ML Kit imports to the Web compiler.
class OcrServiceFactory {
  OcrServiceFactory._();

  static OcrService create({required ReceiptParser parser}) {
    return createPlatformOcrService(parser);
  }
}
