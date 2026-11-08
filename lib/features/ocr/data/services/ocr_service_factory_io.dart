import 'dart:io' show Platform;
import '../../domain/services/ocr_service.dart';
import '../../domain/services/receipt_parser.dart';
import 'mobile_ocr_service.dart';
import 'web_ocr_service.dart';

OcrService createPlatformOcrService(ReceiptParser parser) {
  if (Platform.isAndroid || Platform.isIOS) {
    return MobileOcrService(parser: parser);
  }
  return WebOcrService(parser: parser);
}
