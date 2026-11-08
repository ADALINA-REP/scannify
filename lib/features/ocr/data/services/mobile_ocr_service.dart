import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/models/financial_analysis.dart';
import '../../domain/models/ocr_layout.dart';
import '../../domain/models/parsed_receipt_result.dart';
import '../../domain/services/financial_document_analyzer.dart';
import '../../domain/services/ocr_service.dart';
import '../../domain/services/receipt_parser.dart';
import 'image_preprocessor.dart';

/// Gateway abstraction over Google ML Kit [TextRecognizer] to allow
/// deterministic unit testing of [MobileOcrService].
abstract interface class TextRecognitionGateway {
  Future<String> recognizeTextFromFile(String filePath);
  Future<void> close();
}

/// Default production gateway invoking on-device Google ML Kit Latin text recognition.
///
/// Instead of the flat `RecognizedText.text`, it keeps each line's bounding box and
/// rebuilds table rows with [OcrLayoutReconstructor] so quantity / price / total
/// cells stay attached to their description.
class MlKitTextRecognitionGateway implements TextRecognitionGateway {
  MlKitTextRecognitionGateway({TextRecognizer? recognizer})
    : _recognizer =
          recognizer ?? TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _recognizer;
  static const OcrLayoutReconstructor _reconstructor = OcrLayoutReconstructor();

  @override
  Future<String> recognizeTextFromFile(String filePath) async {
    final inputImage = InputImage.fromFilePath(filePath);
    final recognizedText = await _recognizer.processImage(inputImage);

    final lines = <OcrTextLine>[
      for (final block in recognizedText.blocks)
        for (final line in block.lines)
          OcrTextLine(
            text: line.text,
            left: line.boundingBox.left,
            top: line.boundingBox.top,
            right: line.boundingBox.right,
            bottom: line.boundingBox.bottom,
          ),
    ];
    if (lines.isEmpty) return recognizedText.text;
    return _reconstructor.reconstruct(lines);
  }

  @override
  Future<void> close() async {
    await _recognizer.close();
  }
}

/// Native mobile (Android & iOS) implementation of [OcrService] powered by
/// on-device Google ML Kit (`google_mlkit_text_recognition`).
///
/// Runs 100% offline. Strategy (bounded to TWO recognition passes, no loops):
/// 1. Recognize the original image.
/// 2. If the result is weak (no total / low confidence / almost no text), preprocess
///    the image (shadow removal, contrast, deskew, sharpen) and recognize again,
///    keeping whichever pass scores better.
class MobileOcrService implements OcrService {
  MobileOcrService({
    required ReceiptParser parser,
    TextRecognitionGateway? gateway,
    FinancialDocumentAnalyzer? analyzer,
    ImagePreprocessor? preprocessor,
    Duration recognitionTimeout = const Duration(seconds: 30),
    bool? overridePlatformSupportForTest,
  }) : _parser = parser,
       _analyzer = analyzer ?? FinancialDocumentAnalyzer(parser: parser),
       _preprocessor = preprocessor ?? const ImagePreprocessor(),
       _timeout = recognitionTimeout,
       _gateway = gateway ?? MlKitTextRecognitionGateway(),
       _overridePlatformSupportForTest = overridePlatformSupportForTest;

  final ReceiptParser _parser;
  final FinancialDocumentAnalyzer _analyzer;
  final ImagePreprocessor _preprocessor;
  final Duration _timeout;
  final TextRecognitionGateway _gateway;
  final bool? _overridePlatformSupportForTest;

  String? _cacheKey;
  OcrScanResult? _cacheValue;

  @override
  bool get isSupported {
    if (_overridePlatformSupportForTest != null) {
      return _overridePlatformSupportForTest;
    }
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  @override
  Future<OcrScanResult> processImage(String imagePath) async {
    if (!isSupported) {
      return OcrScanResult(
        rawText: '',
        parsedReceipt: _parser.parse(''),
        isAutomaticOcrSupported: false,
      );
    }

    if (imagePath.trim().isEmpty) {
      throw const OcrException(
        message: 'Receipt image path cannot be empty.',
        code: 'EMPTY_IMAGE_PATH',
      );
    }

    final file = File(imagePath);
    if (!await file.exists()) {
      throw const OcrException(
        message: 'Receipt image file could not be found on device.',
        code: 'IMAGE_FILE_MISSING',
      );
    }

    // Reuse the previous result for the very same file (no duplicate processing).
    final stat = await file.stat();
    final key =
        '$imagePath|${stat.size}|${stat.modified.millisecondsSinceEpoch}';
    if (_cacheKey == key && _cacheValue != null) return _cacheValue!;

    try {
      var best = await _runPass(imagePath);

      if (best.isWeak) {
        final prepared = await _preprocessor.prepareFile(imagePath);
        if (prepared != null) {
          try {
            final second = await _runPass(prepared.path);
            if (second.error == null && second.score > best.score) {
              best = second;
              AppLogger.info(
                'MobileOcrService',
                'Preprocessed pass improved the result '
                    '(skew corrected: ${prepared.skewDegrees.toStringAsFixed(1)}°).',
              );
            }
          } finally {
            await prepared.dispose();
          }
        }
      }

      if (best.error != null) {
        throw best.error is OcrException
            ? best.error as OcrException
            : OcrException(
                message: 'Failed to analyze the receipt image on device.',
                code: 'MLKIT_FAILURE',
                cause: best.error,
              );
      }

      final parsed = best.parsed!;
      AppLogger.info(
        'MobileOcrService',
        'Local OCR completed (overall confidence: ${(parsed.overallConfidence * 100).toStringAsFixed(0)}%).',
      );

      final result = OcrScanResult(
        rawText: best.text,
        parsedReceipt: parsed,
        isAutomaticOcrSupported: true,
        analysis: best.analysis,
      );
      _cacheKey = key;
      _cacheValue = result;
      return result;
    } on OcrException {
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error(
        'MobileOcrService',
        'Local ML Kit text recognition failed.',
        e,
        stackTrace,
      );
      throw OcrException(
        message: 'Failed to analyze the receipt image on device.',
        code: 'MLKIT_FAILURE',
        cause: e,
      );
    }
  }

  Future<_Pass> _runPass(String path) async {
    try {
      final text = await _gateway
          .recognizeTextFromFile(path)
          .timeout(
            _timeout,
            onTimeout: () => throw const OcrException(
              message: 'Text recognition timed out.',
              code: 'OCR_TIMEOUT',
            ),
          );
      final parsed = _parser.parse(text);
      final analysis = _analyzer.analyze(text, parsed: parsed);
      return _Pass(text: text, parsed: parsed, analysis: analysis);
    } catch (e) {
      return _Pass.failed(e);
    }
  }

  @override
  Future<void> dispose() async {
    try {
      await _gateway.close();
    } catch (e) {
      AppLogger.warning(
        'MobileOcrService',
        'Failed to close ML Kit recognizer cleanly.',
        e,
      );
    }
  }
}

class _Pass {
  _Pass({required this.text, required this.parsed, required this.analysis})
    : error = null;

  _Pass.failed(this.error) : text = '', parsed = null, analysis = null;

  final String text;
  final ParsedReceiptResult? parsed;
  final FinancialAnalysis? analysis;
  final Object? error;

  bool get isWeak {
    if (error != null || parsed == null) return true;
    return text.trim().length < 15 ||
        !parsed!.totalAmountMinorUnits.isPresent ||
        parsed!.overallConfidence < 0.75 ||
        (analysis?.hasErrors ?? false);
  }

  /// Higher is better; used to pick between the original and preprocessed pass.
  double get score {
    if (parsed == null) return -1;
    return parsed!.overallConfidence +
        (parsed!.totalAmountMinorUnits.isPresent ? 0.2 : 0) -
        ((analysis?.hasErrors ?? false) ? 0.2 : 0);
  }
}
