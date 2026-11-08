// Benchmark corpus: hand-written OCR *text* fixtures that mimic what ML Kit returns
// for typical French / English financial documents.
//
// IMPORTANT: these are synthetic text samples, not photographs. They measure the
// parsing / interpretation layers only. Real-device image accuracy (blur, glare,
// perspective) must be measured separately with real photos.

class CorpusSample {
  const CorpusSample({
    required this.name,
    required this.text,
    this.merchant,
    this.date,
    this.totalMinor,
    this.invoiceNumber,
    this.dueDate,
    this.htMinor,
    this.vatMinor,
    this.currency,
    this.payment,
    this.itemCount,
  });

  final String name;
  final String text;
  final String? merchant;
  final DateTime? date;
  final int? totalMinor;
  final String? invoiceNumber;
  final DateTime? dueDate;
  final int? htMinor;
  final int? vatMinor;
  final String? currency;
  final String? payment;
  final int? itemCount;
}

final List<CorpusSample> ocrCorpus = <CorpusSample>[
  CorpusSample(
    name: 'FR professional invoice (HT/TVA/TTC, SIRET, due date)',
    text: '''
FACTURE
DUPONT CONSEIL SARL
12 rue de la Paix
75002 PARIS
SIRET : 123 456 782 00010
N° TVA : FR11 123456782
Facture n° FAC-2026-001
Date : 05/11/2026
Date d'échéance : 30/11/2026
Client : Société Martin
Désignation Qté Prix unitaire Total
Prestation de conseil 2 400,00 € 800,00 €
Audit technique 1 200,00 € 200,00 €
Total HT 1 000,00 €
TVA 20% 200,00 €
Total TTC 1 200,00 €
Mode de paiement : Virement bancaire
''',
    merchant: 'DUPONT CONSEIL SARL',
    date: DateTime(2026, 11, 5),
    totalMinor: 120000,
    invoiceNumber: 'FAC-2026-001',
    dueDate: DateTime(2026, 11, 30),
    htMinor: 100000,
    vatMinor: 20000,
    currency: 'EUR',
    payment: 'bank_transfer',
    itemCount: 2,
  ),
  CorpusSample(
    name: 'EN freelance invoice (table rows, From/Billed to)',
    text: '''
INVO|CE
Date: September 15, 2020
From:
Olivia Wilson
123 Anywhere St., Any City
hello@reallygreatsite.com
Billed to:
Daniel Gallego
123 Anywhere St., Any City
hello@reallygreatsite.com
SERVICE QTY PRICE TOTAL
Consultation 1 \$5.00 \$5.00
Web Development 2 \$10.00 \$20.00
Business Consulting 1 \$8.00 \$8.00
Business Consultation 2 \$25.00 \$50.00
Graphic Design 1 \$12.00 \$12.00
TOTAL \$95.00
Payment method: Cash
Note: Thank you for shopping with us!
''',
    merchant: 'Olivia Wilson',
    date: DateTime(2020, 9, 15),
    totalMinor: 9500,
    currency: 'USD',
    payment: 'cash',
    itemCount: 5,
  ),
  CorpusSample(
    name: 'UK invoice (subtotal, VAT, GBP, due date)',
    text: '''
INVOICE
Acme Web Studio Ltd
INVOICE NO: INV-0042
Invoice Date: 12 October 2026
Payment due: 11 November 2026
Description Qty Unit Price Amount
Website design 1 £1,200.00 £1,200.00
Hosting 12 £10.00 £120.00
Subtotal £1,320.00
VAT 20% £264.00
Total £1,584.00
Payment method: Bank transfer
''',
    merchant: 'Acme Web Studio Ltd',
    date: DateTime(2026, 10, 12),
    totalMinor: 158400,
    invoiceNumber: 'INV-0042',
    dueDate: DateTime(2026, 11, 11),
    htMinor: 132000,
    vatMinor: 26400,
    currency: 'GBP',
    payment: 'bank_transfer',
    itemCount: 2,
  ),
  CorpusSample(
    name: 'FR invoice with three VAT lines',
    text: '''
FACTURE N° 2026-0156
ATELIER MARTIN SAS
Date de facture : 02/11/2026
Total HT 500,00 €
TVA 5,5% 11,00 €
TVA 20% 60,00 €
Total TVA 71,00 €
Total TTC 571,00 €
''',
    merchant: 'ATELIER MARTIN SAS',
    date: DateTime(2026, 11, 2),
    totalMinor: 57100,
    invoiceNumber: '2026-0156',
    htMinor: 50000,
    vatMinor: 7100,
    currency: 'EUR',
  ),
  CorpusSample(
    name: 'Supermarket receipt (VAT breakdown, discount)',
    text: '''
BIENVENUE
CARREFOUR CITY
14 RUE DE RIVOLI
75001 PARIS
TEL: 01 42 68 55 10
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
''',
    merchant: 'CARREFOUR CITY',
    date: DateTime(2026, 10, 24),
    totalMinor: 1500,
    htMinor: 1355,
    vatMinor: 145,
    currency: 'EUR',
    payment: 'cash',
    itemCount: 3,
  ),
  CorpusSample(
    name: 'Restaurant receipt (two VAT rates, card)',
    text: '''
BRASSERIE LE PARISIEN
8 BOULEVARD SAINT-GERMAIN
75005 PARIS
TEL: 01 43 25 10 10
TABLE 12   COUVERTS 2
03/11/2026 20:45
2 x MENU DU JOUR       32,00
1 x BOUTEILLE VIN      24,00
1 x CAFE                2,50
TOTAL HT               51,36
TVA 10%                 3,14
TVA 20%                 4,00
TOTAL TTC              58,50 €
CB VISA                58,50
''',
    merchant: 'BRASSERIE LE PARISIEN',
    date: DateTime(2026, 11, 3),
    totalMinor: 5850,
    htMinor: 5136,
    vatMinor: 714,
    currency: 'EUR',
    payment: 'card',
    itemCount: 3,
  ),
  CorpusSample(
    name: 'Fuel receipt',
    text: '''
TOTALENERGIES ACCESS
STATION A6 AUTOROUTE DU SOLEIL
69000 LYON
15/10/2026 07:32
POMPE 04
GAZOLE   42,15 L  x 1,789 €/L
MONTANT TTC  75,41 €
TVA 20%  12,57 €
CB SANS CONTACT  75,41 €
''',
    merchant: 'TOTALENERGIES ACCESS',
    date: DateTime(2026, 10, 15),
    totalMinor: 7541,
    vatMinor: 1257,
    currency: 'EUR',
    payment: 'card',
  ),
  CorpusSample(
    name: 'Receipt with missing merchant and date',
    text: '''
2 x CAFE  3,00
TOTAL  3,00
''',
    totalMinor: 300,
  ),
  CorpusSample(
    name: 'Thermal ticket with number',
    text: '''
MARCHE U EXPRESS
Ticket n° 000458
28/10/2026 18:03
LAIT 1L        1,19
BAGUETTE       0,95
TOTAL TTC      2,14 €
CARTE BANCAIRE 2,14
''',
    merchant: 'MARCHE U EXPRESS',
    date: DateTime(2026, 10, 28),
    totalMinor: 214,
    invoiceNumber: '000458',
    currency: 'EUR',
    payment: 'card',
    itemCount: 2,
  ),
];
