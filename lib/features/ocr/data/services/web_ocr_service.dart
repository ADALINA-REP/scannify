import '../../../../core/logging/app_logger.dart';
import '../../domain/services/ocr_service.dart';
import '../../domain/services/receipt_parser.dart';

/// Web implementation of [OcrService].
///
/// Disables automatic native ML Kit OCR on Web and provides a clean manual-entry
/// fallback workflow without importing native-only plugins.
class WebOcrService implements OcrService {
  const WebOcrService({required ReceiptParser parser}) : _parser = parser;

  final ReceiptParser _parser;

  @override
  bool get isSupported => false;

  @override
  Future<OcrScanResult> processImage(String imagePath) async {
    AppLogger.info(
      'WebOcrService',
      'Automatic OCR disabled on Web; routing to manual receipt validation form.',
    );

    return OcrScanResult(
      rawText: '',
      parsedReceipt: _parser.parse(''),
      isAutomaticOcrSupported: false,
    );
  }

  @override
  Future<void> dispose() async {}
}
