import '../../domain/services/ocr_service.dart';
import '../../domain/services/receipt_parser.dart';

OcrService createPlatformOcrService(ReceiptParser parser) {
  throw UnsupportedError(
    'Cannot create OcrService without dart:io or dart:js_interop.',
  );
}
