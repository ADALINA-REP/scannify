import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:scannify/core/errors/app_exception.dart';
import 'package:scannify/features/ocr/data/services/mobile_ocr_service.dart';
import 'package:scannify/features/ocr/domain/services/receipt_parser.dart';

class _ScriptedGateway implements TextRecognitionGateway {
  _ScriptedGateway({
    required this.original,
    required this.preprocessed,
    this.delay,
  });

  final String original;
  final String preprocessed;
  final Duration? delay;
  final List<String> paths = <String>[];

  @override
  Future<String> recognizeTextFromFile(String filePath) async {
    paths.add(filePath);
    if (delay != null) await Future<void>.delayed(delay!);
    return filePath.contains('scannify_ocr_') ? preprocessed : original;
  }

  @override
  Future<void> close() async {}
}

void main() {
  late Directory tmp;
  late ReceiptParser parser;
  late File image;

  setUp(() async {
    parser = ReceiptParser(referenceClock: DateTime(2026, 11, 6));
    tmp = await Directory.systemTemp.createTemp('scannify_retry_test_');
    image = File('${tmp.path}/doc.png');
    final im = img.Image(width: 400, height: 300);
    img.fill(im, color: img.ColorRgb8(230, 230, 230));
    img.fillRect(
      im,
      x1: 40,
      y1: 40,
      x2: 300,
      y2: 60,
      color: img.ColorRgb8(20, 20, 20),
    );
    await image.writeAsBytes(img.encodePng(im));
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test(
    'weak first pass triggers exactly one preprocessed retry and the better pass wins',
    () async {
      final gateway = _ScriptedGateway(
        original: 'x',
        preprocessed: 'MONOPRIX\n24/10/2026\nTOTAL TTC 34,90 €',
      );
      final service = MobileOcrService(
        parser: parser,
        gateway: gateway,
        overridePlatformSupportForTest: true,
      );

      final result = await service.processImage(image.path);

      expect(gateway.paths, hasLength(2)); // bounded: original + one retry
      expect(gateway.paths.first, image.path);
      expect(result.parsedReceipt.totalAmountMinorUnits.value, 3490);
      expect(result.analysis, isNotNull);
      expect(result.analysis!.supplierName.value, 'MONOPRIX');

      // Privacy: the temporary preprocessed copy must be deleted.
      expect(File(gateway.paths.last).existsSync(), isFalse);
    },
  );

  test('a good first pass does not trigger any retry', () async {
    final gateway = _ScriptedGateway(
      original: 'MONOPRIX\n24/10/2026\nTOTAL TTC 34,90 €',
      preprocessed: 'never used',
    );
    final service = MobileOcrService(
      parser: parser,
      gateway: gateway,
      overridePlatformSupportForTest: true,
    );
    await service.processImage(image.path);
    expect(gateway.paths, hasLength(1));
  });

  test('the same file is not processed twice (result cache)', () async {
    final gateway = _ScriptedGateway(
      original: 'MONOPRIX\n24/10/2026\nTOTAL TTC 34,90 €',
      preprocessed: '',
    );
    final service = MobileOcrService(
      parser: parser,
      gateway: gateway,
      overridePlatformSupportForTest: true,
    );
    final a = await service.processImage(image.path);
    final b = await service.processImage(image.path);
    expect(identical(a, b), isTrue);
    expect(gateway.paths, hasLength(1));
  });

  test('slow recognition surfaces OCR_TIMEOUT instead of hanging', () async {
    final gateway = _ScriptedGateway(
      original: 'x',
      preprocessed: 'y',
      delay: const Duration(milliseconds: 400),
    );
    final service = MobileOcrService(
      parser: parser,
      gateway: gateway,
      recognitionTimeout: const Duration(milliseconds: 50),
      overridePlatformSupportForTest: true,
    );
    await expectLater(
      () => service.processImage(image.path),
      throwsA(isA<OcrException>().having((e) => e.code, 'code', 'OCR_TIMEOUT')),
    );
  });

  test(
    'empty OCR text yields a no_text_detected analysis for the UI',
    () async {
      final gateway = _ScriptedGateway(original: '', preprocessed: '');
      final service = MobileOcrService(
        parser: parser,
        gateway: gateway,
        overridePlatformSupportForTest: true,
      );
      final result = await service.processImage(image.path);
      expect(
        result.analysis!.issues.any((i) => i.code == 'no_text_detected'),
        isTrue,
      );
      expect(gateway.paths.length, lessThanOrEqualTo(2));
    },
  );
}
