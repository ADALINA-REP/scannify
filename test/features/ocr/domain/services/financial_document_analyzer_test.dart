import 'package:flutter_test/flutter_test.dart';
import 'package:scannify/features/ocr/domain/models/financial_analysis.dart';
import 'package:scannify/features/ocr/domain/services/financial_document_analyzer.dart';
import 'package:scannify/features/ocr/domain/services/receipt_parser.dart';

void main() {
  final parser = ReceiptParser(referenceClock: DateTime(2026, 11, 6));
  final analyzer = FinancialDocumentAnalyzer(parser: parser);

  bool has(FinancialAnalysis a, String code) =>
      a.issues.any((i) => i.code == code);

  group('number formats', () {
    test('European and international amount formats are not confused', () {
      final samples = <String, int>{
        'TOTAL TTC 1 250,50 €': 125050,
        'TOTAL TTC 1.250,50 €': 125050,
        'TOTAL TTC 1250.50 EUR': 125050,
        'TOTAL TTC 1,250.50 USD': 125050,
        'TOTAL TTC 12,50 €': 1250,
      };
      for (final e in samples.entries) {
        final a = analyzer.analyze('ACME SAS\n${e.key}');
        expect(a.totalTtcMinor.value, e.value, reason: e.key);
      }
    });
  });

  group('financial validation', () {
    test('flags HT + VAT != TTC as an error without altering any value', () {
      const text = '''
SARL TEST CONSEIL
Facture n° F-100
Date : 14/10/2026
Total HT 100,00 €
TVA 20% 20,00 €
Total TTC 130,00 €
''';
      final a = analyzer.analyze(text);
      expect(has(a, 'totals_mismatch'), isTrue);
      expect(a.hasErrors, isTrue);
      expect(a.needsUserReview, isTrue);
      // Values are reported exactly as read, never "corrected".
      expect(a.subtotalHtMinor.value, 10000);
      expect(a.vatAmountMinor.value, 2000);
      expect(a.totalTtcMinor.value, 13000);
    });

    test('consistent totals produce no mismatch', () {
      const text = '''
SARL TEST CONSEIL
Date : 14/10/2026
Total HT 100,00 €
TVA 20% 20,00 €
Total TTC 120,00 €
''';
      final a = analyzer.analyze(text);
      expect(has(a, 'totals_mismatch'), isFalse);
      expect(has(a, 'vat_rate_mismatch'), isFalse);
      expect(a.hasErrors, isFalse);
    });

    test('warns when the VAT amount does not match the stated rate', () {
      const text = '''
SARL TEST CONSEIL
Date : 14/10/2026
Total HT 100,00 €
TVA 20% 10,00 €
Total TTC 110,00 €
''';
      final a = analyzer.analyze(text);
      expect(has(a, 'vat_rate_mismatch'), isTrue);
      expect(has(a, 'totals_mismatch'), isFalse);
    });

    test('derives HT from TTC - VAT but flags it as inferred', () {
      const text = '''
STATION SERVICE
Date : 15/10/2026
Montant TTC 75,41 €
TVA 20% 12,57 €
''';
      final a = analyzer.analyze(text);
      expect(a.subtotalHtMinor.value, 6284);
      expect(a.subtotalHtMinor.isInferred, isTrue);
      expect(
        a.toJson()['inferred_fields'],
        contains('financial_summary.subtotal_ht'),
      );
    });

    test('line item arithmetic mismatch is reported on the line', () {
      const text = '''
SARL TEST CONSEIL
Date : 14/10/2026
Description Qty Unit Price Total
Dev web 2 \$100.00 \$150.00
TOTAL \$150.00
''';
      final a = analyzer.analyze(text);
      expect(a.items, hasLength(1));
      expect(has(a, 'item_total_mismatch'), isTrue);
    });

    test('due date earlier than the invoice date raises a warning', () {
      const text = '''
SARL TEST
Facture n° F-1
Date : 20/10/2026
Date d'échéance : 05/10/2026
Total TTC 50,00 €
''';
      final a = analyzer.analyze(text);
      expect(a.dueDate.value, DateTime(2026, 10, 5));
      expect(a.invoiceDate.value, DateTime(2026, 10, 20));
      expect(has(a, 'due_before_invoice_date'), isTrue);
    });

    test('ambiguous day/month dates require user review', () {
      final a = analyzer.analyze(
        'SARL TEST\nDate : 04/05/2026\nTotal TTC 50,00 €',
      );
      expect(has(a, 'ambiguous_date'), isTrue);
      expect(a.needsUserReview, isTrue);
    });

    test('empty OCR output is reported, not hidden', () {
      final a = analyzer.analyze('   \n  ');
      expect(has(a, 'no_text_detected'), isTrue);
      expect(a.needsUserReview, isTrue);
      expect(a.totalTtcMinor.isPresent, isFalse);
    });

    test('missing total is an error', () {
      final a = analyzer.analyze('SARL TEST\nDate : 14/10/2026');
      expect(has(a, 'missing_total'), isTrue);
      expect(a.hasErrors, isTrue);
    });

    test('mixed currencies raise a warning', () {
      final a = analyzer.analyze(
        'ACME\nDate : 14/10/2026\nItem 10,00 €\nTotal \$25.00',
      );
      expect(has(a, 'mixed_currency'), isTrue);
    });
  });

  group('identifiers', () {
    test('valid SIRET / SIREN / VAT number get high confidence', () {
      final a = analyzer.analyze('''
DUPONT CONSEIL SARL
SIRET : 123 456 782 00010
N° TVA : FR11 123456782
Total TTC 10,00 €
''');
      expect(a.supplierSiret.value, '12345678200010');
      expect(a.supplierSiret.confidence, greaterThanOrEqualTo(0.95));
      expect(a.supplierVatNumber.value, 'FR11123456782');
      expect(a.supplierVatNumber.confidence, greaterThanOrEqualTo(0.95));
      expect(a.supplierSiren.value, '123456782');
      expect(
        a.supplierSiren.isInferred,
        isTrue,
      ); // derived from SIRET, not read
    });

    test('checksum failures lower confidence and warn', () {
      final a = analyzer.analyze('''
DUPONT CONSEIL SARL
SIRET : 123 456 782 00011
N° TVA : FR99 123456782
Total TTC 10,00 €
''');
      expect(a.supplierSiret.confidence, lessThan(0.7));
      expect(has(a, 'invalid_siret'), isTrue);
      expect(has(a, 'invalid_vat_number'), isTrue);
    });

    test('document type detection tolerates OCR noise', () {
      expect(
        analyzer.analyze('INVO|CE\nTOTAL \$10.00').documentType.value,
        FinancialDocumentType.invoice,
      );
      expect(
        analyzer.analyze('DEVIS n° 12\nTotal TTC 10,00 €').documentType.value,
        FinancialDocumentType.quote,
      );
      expect(
        analyzer.analyze('AVOIR n° 3\nTotal TTC 10,00 €').documentType.value,
        FinancialDocumentType.creditNote,
      );
      expect(
        analyzer
            .analyze('MONOPRIX\nTicket de caisse\nTOTAL 3,00 €')
            .documentType
            .value,
        FinancialDocumentType.receipt,
      );
    });
  });

  group('structured JSON & confidence', () {
    test('toJson matches the strict schema and never invents data', () {
      final a = analyzer.analyze('''
FACTURE
DUPONT CONSEIL SARL
Facture n° FAC-2026-001
Date : 14/10/2026
Total TTC 120,00 €
''');
      final json = a.toJson();
      expect(FinancialSchemaValidator.validate(json), isEmpty);
      expect(json['document_type'], 'invoice');
      expect((json['invoice'] as Map)['invoice_number'], 'FAC-2026-001');
      expect((json['invoice'] as Map)['due_date'], isNull);
      expect((json['financial_summary'] as Map)['subtotal_ht'], isNull);
      expect((json['customer'] as Map)['name'], isNull);
      expect((json['financial_summary'] as Map)['total_ttc'], 120.0);
    });

    test('schema validator rejects malformed payloads', () {
      expect(
        FinancialSchemaValidator.validate(<String, dynamic>{}),
        isNotEmpty,
      );
      final bad = analyzer.analyze('X\nTotal TTC 1,00 €').toJson()
        ..['financial_summary'] = <String, dynamic>{'total_ttc': 'abc'};
      expect(FinancialSchemaValidator.validate(bad), isNotEmpty);
      final badConf = analyzer.analyze('X\nTotal TTC 1,00 €').toJson()
        ..['confidence'] = <String, dynamic>{'supplier': 1.7};
      expect(FinancialSchemaValidator.validate(badConf), isNotEmpty);
    });

    test('confidence thresholds are configurable', () {
      const strict = ConfidenceThresholds(high: 0.99, medium: 0.9);
      expect(strict.levelOf(0.95), ConfidenceLevel.medium);
      expect(ConfidenceThresholds.standard.levelOf(0.95), ConfidenceLevel.high);
      expect(
        ConfidenceThresholds.standard.levelOf(0.80),
        ConfidenceLevel.medium,
      );
      expect(ConfidenceThresholds.standard.levelOf(0.60), ConfidenceLevel.low);
      expect(
        ConfidenceThresholds.standard.levelOf(0.99, isPresent: false),
        ConfidenceLevel.missing,
      );
    });
  });
}
