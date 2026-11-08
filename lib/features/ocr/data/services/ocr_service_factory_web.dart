import '../../domain/services/ocr_service.dart';
import '../../domain/services/receipt_parser.dart';
import 'web_ocr_service.dart';

OcrService createPlatformOcrService(ReceiptParser parser) {
  return WebOcrService(parser: parser);
}
