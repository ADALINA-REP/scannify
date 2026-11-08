import 'package:flutter_test/flutter_test.dart';
import 'package:scannify/features/ocr/domain/services/receipt_parser.dart';
import 'package:scannify/features/receipts/domain/entities/receipt.dart';

void main() {
  late ReceiptParser parser;

  setUp(() {
    parser = ReceiptParser(referenceClock: DateTime(2026, 11, 4));
  });

  group('ReceiptParser — Total Amount Extraction', () {
    test('Supports all required European and international amount formats', () {
      final samples = <String, int>{
        'TOTAL TTC 12,50 €': 1250,
        'TOTAL 12.50 €': 1250,
        'NET A PAYER 12,50EUR': 1250,
        'MONTANT TOTAL EUR 12.50': 1250,
        'NET À PAYER 1 250,50 €': 125050,
        'À PAYER 1250.50': 125050,
      };

      for (final entry in samples.entries) {
        final result = parser.parse('BOULANGERIE PAUL\n${entry.key}');
        expect(
          result.totalAmountMinorUnits.value,
          entry.value,
          reason: 'Failed to parse amount from: "${entry.key}"',
        );
        expect(
          result.totalAmountMinorUnits.confidence,
          greaterThanOrEqualTo(0.90),
        );
      }
    });

    test(
      'Prioritizes TOTAL TTC / NET À PAYER over SOUS-TOTAL, TVA, ESPECES, and RENDU',
      () {
        const rawReceipt = '''
BIENVENUE
CARREFOUR CITY
14 RUE DE RIVOLI
75001 PARIS
TEL: 01 42 68 55 10
SIRET: 45123678900014
--------------------------------
PAIN BIO                  2,40 €
HUILE OLIVE               8,10 €
FROMAGE COMTE             6,00 €
--------------------------------
SOUS-TOTAL               16,50 €
REMISE FIDELITE          -1,50 €
TOTAL HT                 13,55 €
DONT TVA 5.5%             0,75 €
DONT TVA 20.0%            0,70 €
TOTAL TTC                15,00 €
ESPECES                  20,00 €
RENDU MONNAIE             5,00 €
MERCI DE VOTRE VISITE
LE 24/10/2026 18:42
''';

        final result = parser.parse(rawReceipt);

        expect(result.merchantName.value, 'CARREFOUR CITY');
        expect(result.merchantName.isHighConfidence, isTrue);
        expect(result.totalAmountMinorUnits.value, 1500);
        expect(result.totalAmount, 15.00);
        expect(result.totalAmountMinorUnits.isHighConfidence, isTrue);
        expect(result.date.value, DateTime(2026, 10, 24));
        expect(result.date.isHighConfidence, isTrue);
        expect(result.suggestedCategory.value, ReceiptCategories.groceries);
      },
    );

    test(
      'Extracts total when TOTAL TTC label and amount are on consecutive lines',
      () {
        const rawReceipt = '''
FNAC PARIS SAINT-LAZARE
DATE: 15.09.2026
CLAVIER MECANIQUE
TOTAL TTC
129,99 €
TVA 20% 21,66 €
''';

        final result = parser.parse(rawReceipt);
        expect(result.merchantName.value, 'FNAC PARIS SAINT-LAZARE');
        expect(result.totalAmountMinorUnits.value, 12999);
        expect(result.date.value, DateTime(2026, 9, 15));
        expect(
          result.suggestedCategory.value,
          ReceiptCategories.officeSupplies,
        );
      },
    );
  });

  group('ReceiptParser — Date Formats & Ambiguity Handling', () {
    test('Supports DD/MM/YYYY, DD-MM-YYYY, DD.MM.YYYY, and YYYY-MM-DD', () {
      expect(
        parser.parse('MERCHANT A\nDate: 28/02/2026\nTOTAL 10,00 €').date.value,
        DateTime(2026, 2, 28),
      );
      expect(
        parser.parse('MERCHANT B\nDate: 28-02-2026\nTOTAL 10,00 €').date.value,
        DateTime(2026, 2, 28),
      );
      expect(
        parser.parse('MERCHANT C\nDate: 28.02.2026\nTOTAL 10,00 €').date.value,
        DateTime(2026, 2, 28),
      );
      expect(
        parser.parse('MERCHANT D\nDate: 2026-02-28\nTOTAL 10,00 €').date.value,
        DateTime(2026, 2, 28),
      );
    });

    test(
      'Supports French textual dates (e.g. "14 mars 2026", "1er avril 2026")',
      () {
        const receipt1 = '''
LE BISTROT PARISIEN
Paris le 14 mars 2026
Menu Midi
NET À PAYER 24,50 €
''';
        final result1 = parser.parse(receipt1);
        expect(result1.date.value, DateTime(2026, 3, 14));
        expect(result1.date.isAmbiguous, isFalse);
        expect(
          result1.suggestedCategory.value,
          ReceiptCategories.mealsAndDining,
        );

        const receipt2 = '''
PHARMACIE CENTRALE
1er avril 2026
MONTANT TOTAL 18,20 €
''';
        final result2 = parser.parse(receipt2);
        expect(result2.date.value, DateTime(2026, 4, 1));
        expect(result2.suggestedCategory.value, ReceiptCategories.healthcare);
      },
    );

    test(
      'Flags ambiguous numeric dates (e.g. 04/05/2026) for user verification',
      () {
        const ambiguousReceipt = '''
TOTALENERGIES STATION
04/05/2026 09:15
GAZOLE 45.00L
MONTANT TOTAL 78,30 €
''';
        final result = parser.parse(ambiguousReceipt);
        // Defaults to European DD/MM/YYYY (May 4, 2026) on EUR receipt
        expect(result.date.value, DateTime(2026, 5, 4));
        expect(result.date.isAmbiguous, isTrue);
        expect(result.date.isUncertain, isTrue);
        expect(result.hasUncertainFields, isTrue);
        expect(
          result.suggestedCategory.value,
          ReceiptCategories.transportAndFuel,
        );
      },
    );

    test(
      'Parses US MM/DD/YYYY receipts when USD currency or day > 12 in second position',
      () {
        const usReceipt = '''
STARBUCKS COFFEE
03/24/2026
LATTE GRANDE
TOTAL DUE \$6.45
''';
        final result = parser.parse(usReceipt);
        expect(result.merchantName.value, 'STARBUCKS COFFEE');
        expect(result.date.value, DateTime(2026, 3, 24));
        expect(result.date.isAmbiguous, isFalse);
        expect(result.totalAmountMinorUnits.value, 645);
      },
    );
  });

  group('ReceiptParser — Merchant Name Filtering', () {
    test(
      'Skips administrative headers, phone numbers, SIRET, and addresses',
      () {
        const rawReceipt = '''
*** TICKET DE CAISSE ***
DUPLICATA
SAS MAISON KAYSER
85 BOULEVARD MALESHERBES
75008 PARIS
TÉL : 01.45.22.10.11
SIRET 812 345 678 00021
TVA FR 12 812345678
www.maison-kayser.com
20/10/2026
TRADITION                 1,35 €
CROISSANT                 1,65 €
NET A PAYER               3,00 €
''';

        final result = parser.parse(rawReceipt);
        expect(result.merchantName.value, 'SAS MAISON KAYSER');
        expect(result.totalAmountMinorUnits.value, 300);
        expect(result.date.value, DateTime(2026, 10, 20));
      },
    );

    test('Handles empty or noisy OCR input gracefully without crashing', () {
      final result = parser.parse('   \n  *** \n --- ');
      expect(result.merchantName.isPresent, isFalse);
      expect(result.date.isPresent, isFalse);
      expect(result.totalAmountMinorUnits.isPresent, isFalse);
      expect(result.hasUncertainFields, isTrue);
      expect(result.overallConfidence, lessThan(0.2));
    });
  });

  group('ReceiptParser — Real-world Invoice Extraction (User Scenario)', () {
    test(
      'Correctly extracts total, date, currency, and avoids recipient as merchant',
      () {
        const userInvoice = '''
Billed to:
Estelle Darcy
+123-456-7890
123 Anywhere St., Any City, ST 12345

Invoice No. 12345
30 July 2025

Item Quantity Unit Price Total
White Basic Tank Top 2 \$80 \$160
Denim Jacket 1 \$320 \$320
Total \$480
''';

        final result = parser.parse(userInvoice);

        // 1. Total amount must be 480.00 ($480)
        expect(result.totalAmountMinorUnits.value, 48000);
        expect(result.totalAmount, 480.00);
        expect(result.totalAmountMinorUnits.isHighConfidence, isTrue);

        // 2. Date must be 30 July 2025
        expect(result.date.value, DateTime(2025, 7, 30));
        expect(result.date.isHighConfidence, isTrue);

        // 3. Merchant must NOT be "Billed to:" or client name "Estelle Darcy"
        expect(result.merchantName.value, isNot(equals('Billed to:')));
        expect(result.merchantName.value, isNot(equals('Estelle Darcy')));
        expect(result.merchantName.isPresent, isFalse);

        // 4. Detected currency must be USD ($)
        expect(result.detectedCurrencySymbol, equals(r'$'));
        expect(result.detectedCurrencyCode, equals('USD'));

        // 5. Suggested category for apparel is other
        expect(result.suggestedCategory.value, equals(ReceiptCategories.other));
      },
    );

    test(
      'Correctly parses vendor when explicit From: prefix or brand header is present',
      () {
        const invoiceWithVendor = '''
From: Atelier Parisien SAS
45 Rue de Courcelles, 75008 Paris
Billed to:
Estelle Darcy
+123-456-7890
123 Anywhere St., Any City, ST 12345

Invoice No. 12345
30 July 2025

Item Quantity Unit Price Total
White Basic Tank Top 2 \$80 \$160
Total \$160
''';

        final result = parser.parse(invoiceWithVendor);
        expect(result.merchantName.value, equals('Atelier Parisien SAS'));
        expect(result.merchantName.isHighConfidence, isTrue);
        expect(result.totalAmountMinorUnits.value, equals(16000));
        expect(result.date.value, equals(DateTime(2025, 7, 30)));
      },
    );

    test(
      'Extracts integer amounts with currency symbols and no decimal places',
      () {
        final samples = <String, int>{
          'Total \$80': 8000,
          'TOTAL 160 \$': 16000,
          'Total: 320 €': 32000,
          'NET A PAYER: 480 EUR': 48000,
          'Amount Due: \$ 1250': 125000,
        };

        for (final entry in samples.entries) {
          final result = parser.parse('STORE\n${entry.key}');
          expect(
            result.totalAmountMinorUnits.value,
            entry.value,
            reason: 'Failed on ${entry.key}',
          );
        }
      },
    );
  });

  group('ReceiptParser — Real-world Invoice Extraction (User Scenario)', () {
    test(
      'Correctly extracts total, date, currency, and avoids recipient as merchant',
      () {
        const userInvoice = '''
Billed to:
Estelle Darcy
+123-456-7890
123 Anywhere St., Any City, ST 12345

Invoice No. 12345
30 July 2025

Item Quantity Unit Price Total
White Basic Tank Top 2 \$80 \$160
Denim Jacket 1 \$320 \$320
Total \$480
''';

        final result = parser.parse(userInvoice);

        // 1. Total amount must be 480.00 ($480)
        expect(result.totalAmountMinorUnits.value, 48000);
        expect(result.totalAmount, 480.00);
        expect(result.totalAmountMinorUnits.isHighConfidence, isTrue);

        // 2. Date must be 30 July 2025
        expect(result.date.value, DateTime(2025, 7, 30));
        expect(result.date.isHighConfidence, isTrue);

        // 3. Merchant must NOT be "Billed to:" or client name "Estelle Darcy"
        expect(result.merchantName.value, isNot(equals('Billed to:')));
        expect(result.merchantName.value, isNot(equals('Estelle Darcy')));
        expect(result.merchantName.isPresent, isFalse);

        // 4. Detected currency must be USD ($)
        expect(result.detectedCurrencySymbol, equals(r'$'));
        expect(result.detectedCurrencyCode, equals('USD'));

        // 5. Suggested category for apparel is other
        expect(result.suggestedCategory.value, equals(ReceiptCategories.other));
      },
    );

    test(
      'Correctly parses vendor when explicit From: prefix or brand header is present',
      () {
        const invoiceWithVendor = '''
From: Atelier Parisien SAS
45 Rue de Courcelles, 75008 Paris
Billed to:
Estelle Darcy
+123-456-7890
123 Anywhere St., Any City, ST 12345

Invoice No. 12345
30 July 2025

Item Quantity Unit Price Total
White Basic Tank Top 2 \$80 \$160
Total \$160
''';

        final result = parser.parse(invoiceWithVendor);
        expect(result.merchantName.value, equals('Atelier Parisien SAS'));
        expect(result.merchantName.isHighConfidence, isTrue);
        expect(result.totalAmountMinorUnits.value, equals(16000));
        expect(result.date.value, equals(DateTime(2025, 7, 30)));
      },
    );

    test('Parses multi-column invoice layout with table and From: section', () {
      const rawText = '''
INVO|CE
Date: September 15. 2020
From:
Olivia Wilson
123 Anywhere St., Any City
hello@reallygreatsite.com

Billed to:
Daniel Gallego
123 Anywhere St., Any City
hello@reallygreatsite.com

SERVICE
Consultation
Web Development
Business Consulting
Business Consultation
Graphic Design

QTY
1
2
1
2
1

PRICE
\$5.00
\$10.00
\$8.00
\$25.00
\$12.00

TOTAL
\$5.00
\$20.00
\$8.00
\$50.00
\$12.00
\$95.00

Payment method: Cash
Note: Thank you for shopping with us!
''';

      final result = parser.parse(rawText);

      // 1. Merchant must be Olivia Wilson (not INVO|CE and not client Daniel Gallego)
      expect(result.merchantName.value, equals('Olivia Wilson'));
      expect(result.merchantName.isHighConfidence, isTrue);

      // 2. Date must be 15 September 2020 even with dot separator in "September 15. 2020"
      expect(result.date.value, equals(DateTime(2020, 9, 15)));
      expect(result.date.isHighConfidence, isTrue);

      // 3. Amount must be the summary column total ($95.00), not the first item row ($5.00)
      expect(result.totalAmountMinorUnits.value, equals(9500));
      expect(result.totalAmount, equals(95.00));
      expect(result.totalAmountMinorUnits.isHighConfidence, isTrue);

      // 4. Category must be Professional Services
      expect(
        result.suggestedCategory.value,
        equals(ReceiptCategories.professionalServices),
      );
      expect(result.suggestedCategory.isHighConfidence, isTrue);
    });

    test(
      'Parses noisy textual dates with various separators and OCR artifacts',
      () {
        final samples = <String, DateTime>{
          'Date: September 15. 2020': DateTime(2020, 9, 15),
          'Date: September 15, 2020': DateTime(2020, 9, 15),
          'Date: Sep 15 2020': DateTime(2020, 9, 15),
          'Date: 15-Sep-2020': DateTime(2020, 9, 15),
          'Date: 15 Sept. 2020': DateTime(2020, 9, 15),
          'Date: September 15th, 2020': DateTime(2020, 9, 15),
          'Date: September 15, 202O': DateTime(2020, 9, 15),
          'Date: 15/09/2020': DateTime(2020, 9, 15),
          'Facture du 14 mars 2026': DateTime(2026, 3, 14),
        };

        for (final entry in samples.entries) {
          final result = parser.parse('STORE\n${entry.key}\nTOTAL 100 \$');
          expect(
            result.date.value,
            entry.value,
            reason: 'Failed on "${entry.key}"',
          );
        }
      },
    );
  });
}
