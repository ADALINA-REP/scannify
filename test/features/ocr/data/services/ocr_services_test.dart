import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:scannify/core/errors/app_exception.dart';
import 'package:scannify/features/ocr/data/services/mobile_ocr_service.dart';
import 'package:scannify/features/ocr/data/services/web_ocr_service.dart';
import 'package:scannify/features/ocr/domain/services/receipt_parser.dart';

class _FakeTextRecognitionGateway implements TextRecognitionGateway {
  _FakeTextRecognitionGateway({
    this.responseText = '',
    this.shouldThrow = false,
  });

  final String responseText;
  final bool shouldThrow;
  bool isClosed = false;

  @override
  Future<String> recognizeTextFromFile(String filePath) async {
    if (shouldThrow) {
      throw Exception('Simulated native ML Kit failure');
    }
    return responseText;
  }

  @override
  Future<void> close() async {
    isClosed = true;
  }
}

void main() {
  late ReceiptParser parser;
  late Directory tempDir;

  setUp(() async {
    parser = ReceiptParser(referenceClock: DateTime(2026, 11, 4));
    tempDir = await Directory.systemTemp.createTemp('scannify_ocr_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('MobileOcrService & WebOcrService Tests', () {
    test(
      'MobileOcrService extracts and parses receipt text from valid image file',
      () async {
        final sampleFile = File('${tempDir.path}/sample_receipt.jpg');
        await sampleFile.writeAsBytes(<int>[0xFF, 0xD8, 0xFF, 0xE0]);

        final fakeGateway = _FakeTextRecognitionGateway(
          responseText: 'MONOPRIX\n24/10/2026\nTOTAL TTC 34,90 €',
        );

        final mobileOcr = MobileOcrService(
          parser: parser,
          gateway: fakeGateway,
          overridePlatformSupportForTest: true,
        );

        final scanResult = await mobileOcr.processImage(sampleFile.path);
        expect(scanResult.isAutomaticOcrSupported, isTrue);
        expect(scanResult.parsedReceipt.merchantName.value, 'MONOPRIX');
        expect(scanResult.parsedReceipt.totalAmountMinorUnits.value, 3490);
        expect(scanResult.parsedReceipt.date.value, DateTime(2026, 10, 24));

        await mobileOcr.dispose();
        expect(fakeGateway.isClosed, isTrue);
      },
    );

    test(
      'MobileOcrService throws OcrException when image file is missing or ML Kit fails',
      () async {
        final mobileOcr = MobileOcrService(
          parser: parser,
          gateway: _FakeTextRecognitionGateway(shouldThrow: true),
          overridePlatformSupportForTest: true,
        );

        await expectLater(
          () => mobileOcr.processImage('${tempDir.path}/non_existent.jpg'),
          throwsA(
            isA<OcrException>().having(
              (e) => e.code,
              'code',
              'IMAGE_FILE_MISSING',
            ),
          ),
        );

        final validFile = File('${tempDir.path}/existing.jpg');
        await validFile.writeAsBytes(<int>[1, 2, 3]);

        await expectLater(
          () => mobileOcr.processImage(validFile.path),
          throwsA(
            isA<OcrException>().having((e) => e.code, 'code', 'MLKIT_FAILURE'),
          ),
        );
      },
    );

    test(
      'WebOcrService disables automatic OCR and returns manual-entry fallback',
      () async {
        final webOcr = WebOcrService(parser: parser);
        expect(webOcr.isSupported, isFalse);

        final result = await webOcr.processImage('web_img://sample.jpg');
        expect(result.isAutomaticOcrSupported, isFalse);
        expect(result.rawText, isEmpty);
        expect(result.parsedReceipt.hasUncertainFields, isTrue);
      },
    );
  });
}
