import 'package:flutter_test/flutter_test.dart';
import 'package:scannify/features/ocr/domain/models/ocr_layout.dart';

OcrTextLine _l(String t, double x, double y, {double w = 80, double h = 20}) =>
    OcrTextLine(text: t, left: x, top: y, right: x + w, bottom: y + h);

void main() {
  const reconstructor = OcrLayoutReconstructor();

  test(
    're-attaches table columns (emitted column-by-column by ML Kit) to rows',
    () {
      // ML Kit emits blocks column by column: SERVICE col, QTY col, PRICE col, TOTAL col.
      final lines = <OcrTextLine>[
        _l('SERVICE', 50, 100),
        _l('Consultation', 50, 140, w: 120),
        _l('Web Development', 50, 180, w: 150),
        _l('QTY', 300, 101, w: 40),
        _l('1', 310, 141, w: 10),
        _l('2', 310, 181, w: 10),
        _l('PRICE', 400, 100, w: 60),
        _l('\$5.00', 400, 142, w: 50),
        _l('\$10.00', 400, 182, w: 60),
        _l('TOTAL', 500, 100, w: 60),
        _l('\$5.00', 500, 141, w: 50),
        _l('\$20.00', 500, 183, w: 60),
      ];

      final text = reconstructor.reconstruct(lines).split('\n');
      expect(text, <String>[
        'SERVICE QTY PRICE TOTAL',
        'Consultation 1 \$5.00 \$5.00',
        'Web Development 2 \$10.00 \$20.00',
      ]);
    },
  );

  test('does not merge side-by-side TEXT blocks (From / Billed to)', () {
    final lines = <OcrTextLine>[
      _l('Billed to:', 50, 40),
      _l('Daniel Gallego', 50, 70, w: 130),
      _l('From:', 400, 41, w: 50),
      _l('Olivia Wilson', 400, 71, w: 120),
    ];
    expect(reconstructor.reconstruct(lines).split('\n'), <String>[
      'Billed to:',
      'Daniel Gallego',
      'From:',
      'Olivia Wilson',
    ]);
  });

  test('keeps a label with its amount cell (TOTAL ... \$95.00)', () {
    final lines = <OcrTextLine>[
      _l('TOTAL', 400, 500, w: 60),
      _l('\$95.00', 520, 502, w: 60),
    ];
    expect(reconstructor.reconstruct(lines), 'TOTAL \$95.00');
  });

  test('falls back to plain text when geometry is missing', () {
    const lines = <OcrTextLine>[
      OcrTextLine(text: 'A', left: 0, top: 0, right: 0, bottom: 0),
      OcrTextLine(text: 'B', left: 0, top: 0, right: 0, bottom: 0),
    ];
    expect(reconstructor.reconstruct(lines), 'A\nB');
  });

  test('empty input yields empty text', () {
    expect(reconstructor.reconstruct(const <OcrTextLine>[]), '');
  });

  test('isNumericCell recognises quantities, prices and percentages', () {
    for (final s in <String>[
      '1',
      '\$5.00',
      '12,50 €',
      '1 250,50 €',
      '20 %',
      '£1,200.00',
    ]) {
      expect(OcrLayoutReconstructor.isNumericCell(s), isTrue, reason: s);
    }
    for (final s in <String>[
      'Total',
      'Consultation',
      'TVA 20%',
      'Paris 75001',
    ]) {
      expect(OcrLayoutReconstructor.isNumericCell(s), isFalse, reason: s);
    }
  });
}
