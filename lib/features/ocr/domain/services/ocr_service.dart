import '../models/financial_analysis.dart';
import '../models/parsed_receipt_result.dart';

/// Result returned by an [OcrService] scan operation.
class OcrScanResult {
  const OcrScanResult({
    required this.rawText,
    required this.parsedReceipt,
    required this.isAutomaticOcrSupported,
    this.analysis,
  });

  /// Raw text extracted from the receipt image (empty on Web manual fallback).
  final String rawText;

  /// Structured fields parsed from [rawText] with confidence scores.
  final ParsedReceiptResult parsedReceipt;

  /// Whether automatic OCR is supported on the current runtime platform.
  final bool isAutomaticOcrSupported;

  /// Full financial interpretation (HT/VAT/TTC, identifiers, items, validation
  /// issues), or `null` when unavailable (manual-entry fallback).
  final FinancialAnalysis? analysis;
}

/// Abstract contract for receipt optical character recognition.
///
/// Native implementations (`MobileOcrService`) use Google ML Kit on Android and iOS,
/// whereas `WebOcrService` disables native OCR and provides a seamless manual-entry
/// fallback so Web compilation never imports native-only plugins.
abstract interface class OcrService {
  /// Whether automatic on-device OCR is supported on the active platform.
  bool get isSupported;

  /// Extracts text and parses structured fields from the image at [imagePath].
  Future<OcrScanResult> processImage(String imagePath);

  /// Releases any underlying native OCR recognizer resources.
  Future<void> dispose();
}
