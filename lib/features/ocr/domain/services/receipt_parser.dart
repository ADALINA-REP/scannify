import '../../../receipts/domain/entities/receipt.dart';
import '../models/parsed_receipt_result.dart';

/// Modular Regex and heuristic text-analysis engine for extracting structured
/// receipt fields (Total Amount, Date, Merchant Name, and Suggested Category)
/// from raw OCR text.
///
/// Designed to run 100% locally on-device with zero network dependencies.
class ReceiptParser {
  const ReceiptParser({DateTime? referenceClock})
    : _referenceClock = referenceClock;

  final DateTime? _referenceClock;

  DateTime get _now => _referenceClock ?? DateTime.now();

  // ---------------------------------------------------------------------------
  // A. TOTAL AMOUNT REGEXES & RULES
  // ---------------------------------------------------------------------------

  /// Tier 1: Explicit final total labels (French & International).
  static final RegExp _tier1TotalLabelRegex = RegExp(
    r'\b(?:TOTAL\s+T\.?T\.?C\.?|NET\s+[AÀ]\s+PAYER|TOTAL\s+[AÀ]\s+PAYER|MONTANT\s+TOTAL(?:\s+T\.?T\.?C\.?)?|MONTANT\s+T\.?T\.?C\.?|TOTAL\s+NET|TOTAL\s+EUR(?:OS)?|GRAND\s+TOTAL|AMOUNT\s+DUE|TOTAL\s+DUE|BALANCE\s+DUE|TOTAL\s+AMOUNT|INVOICE\s+TOTAL|TOTAL\s+INVOICE|FINAL\s+TOTAL|TOTAL\s+PAYABLE|AMOUNT\s+PAYABLE|TOTAL\s+PRICE)\b',
    caseSensitive: false,
  );

  /// Tier 2: Standard total or payable labels.
  static final RegExp _tier2TotalLabelRegex = RegExp(
    r'(?:^|\s)(?:[AÀ]\s+PAYER|SOMME\s+[AÀ]\s+PAYER|TOTAL\s+PAY[EÉ]|TOTAL(?:\s*\([A-Z$€£]+\))?|TOTAL)(?:\s*[:\-=]|\s|$)',
    caseSensitive: false,
  );

  /// Tier 3: Subtotal or payment labels used as fallback when no final TOTAL line is legible.
  static final RegExp _tier3PaymentOrSubtotalLabelRegex = RegExp(
    r'\b(?:SOUS[\s-]?TOTAL|SUB[\s-]?TOTAL|MONTANT\s+CB|PAIEMENT\s+CB|CARTE\s+BANCAIRE|TOTAL\s+CB|PAIEMENT)\b',
    caseSensitive: false,
  );

  /// Table column headers that should NEVER be mistaken for a final total label line.
  /// (e.g. `Item Quantity Unit Price Total`, `Service Qty Price Total`, or `Articles Qté Prix Total`).
  static final RegExp _tableHeaderLineRegex = RegExp(
    r'\b(?:ITEM|ITEMS|DESCRIPTION|D[EÉ]SIGNATION|ARTICLES?|PRODUITS?|SERVICES?|PRESTATIONS?|QTY|QUANTIT[EÉ]|QUANTITY|QTE|QT[EÉ]|Q\.?TY|OTY|UNIT\s+PRICE|PRIX\s+UNITAIRE|P\.?U\.?|PRICE|PRIX|RATE|TARIF|TAUX|HOURS?|HEURES?|UNIT[EÉ]?S?)\b',
    caseSensitive: false,
  );

  /// Client, recipient, or billing addresses that must NEVER be selected as Merchant Name.
  static final RegExp _clientOrRecipientPrefixRegex = RegExp(
    r'^(?:BILLED?\s+TO|BILL\s+TO|INVOICE\s+TO|INVOICED\s+TO|SHIP\s+TO|SHIPPED\s+TO|SOLD\s+TO|DELIVER\s+TO|DELIVERED\s+TO|FACTUR[EÉ]\s+[AÀ]|LIVR[EÉ]\s+[AÀ]|DESTINATAIRE|CLIENT|CUSTOMER|ADRESSE\s+DE\s+FACTURATION|ADRESSE\s+DE\s+LIVRAISON|BILLING\s+ADDRESS|SHIPPING\s+ADDRESS|ATTN|ATTENTION)(?:\s*[:\-#]|\s|$)',
    caseSensitive: false,
  );

  /// Invoice metadata prefixes that must NEVER be selected as Merchant Name.
  static final RegExp _invoiceMetadataPrefixRegex = RegExp(
    r'^(?:INVOICE(?:\s+NO\.?|\s+NUMBER|\s+#)?|FACTURE(?:\s+N[°ºo]?|\s+NUM[EÉ]RO)?|ORDER(?:\s+NO\.?|\s+#)?|COMMANDE\s+N[°ºo]?|ACCOUNT\s+NO\.?|DEVIS\s+N[°ºo]?|RECEIPT\s+NO\.?)(?:\s*[:\-#]|\s|\d|$)',
    caseSensitive: false,
  );

  /// Explicit vendor/seller prefixes (e.g. `From:`, `Sold by:`, `Fournisseur:`, `Émetteur:`).
  static final RegExp _vendorPrefixRegex = RegExp(
    r'^(?:FROM|SOLD\s+BY|VENDOR|SUPPLIER|FOURNISSEUR|[EÉ]METTEUR|DE|PAR|ISSUED\s+BY)(?:\s*[:\-#]|\s|$)',
    caseSensitive: false,
  );

  /// Strictly excluded lines that contain non-final monetary figures (tax breakdowns, change, etc.).
  static final RegExp _excludedAmountLineRegex = RegExp(
    r'\b(?:DONT\s+T\.?V\.?A\.?|MONTANT\s+T\.?V\.?A\.?|TOTAL\s+T\.?V\.?A\.?|T\.?V\.?A\.?\s*\d|TAUX\s+T\.?V\.?A\.?|TOTAL\s+H\.?T\.?|MONTANT\s+H\.?T\.?|HORS\s+TAXES?|NET\s+H\.?T\.?|RENDU|MONNAIE|ESP[EÈ]CES|VERS[EÉ]|MONTANT\s+RE[CÇ]U|CHANGE\s+DUE|CASH\s+TENDERED|REMISE|R[EÉ]DUCTION|ESCOMPTE|ACOMPTE|AVOIR|AVANTAGE|FID[EÉ]LIT[EÉ]|TOTAL\s+ARTICLES|NB\s+ARTICLES|NOMBRE\s+D.ARTICLES|POIDS|QUANTIT[EÉ])\b',
    caseSensitive: false,
  );

  /// Detects standalone VAT/TVA header or breakdown lines.
  static final RegExp _vatOnlyLineRegex = RegExp(
    r'^\s*(?:T\.?V\.?A\.?|VAT|TAX|H\.?T\.?)\b',
    caseSensitive: false,
  );

  /// Currency prefixed amount: e.g. `$80`, `$160`, `$320`, `$ 1,250.50`, `€12.50`, `EUR 480`.
  static final RegExp _currencyPrefixedAmountRegex = RegExp(
    r'(?<prefix>[$€£¥₹]|EUR|USD|GBP|CHF|CAD|AUD)\s*(?<number>(?:\d{1,3}(?:[\s\u00A0\u202F,.]\d{3})+|\d+)(?:[.,]\d{1,2})?)',
    caseSensitive: false,
  );

  /// Currency suffixed amount: e.g. `80$`, `160$`, `12,50 €`, `12.50 €`, `480 EUR`, `480 TTC`.
  static final RegExp _currencySuffixedAmountRegex = RegExp(
    r'(?<number>(?:\d{1,3}(?:[\s\u00A0\u202F,.]\d{3})+|\d+)(?:[.,]\d{1,2})?)\s*(?<suffix>[$€£¥₹]|EUR|EUROS?|USD|GBP|CHF|CAD|AUD|TTC)',
    caseSensitive: false,
  );

  /// Standard amount with 1 or 2 decimal digits: e.g. `12.50`, `12,50`, `1 250,50`, `1250.00`, `12.5`.
  static final RegExp _decimalAmountRegex = RegExp(
    r'(?<!\d)(?<number>(?:\d{1,3}(?:[\s\u00A0\u202F,]\d{3})+|\d+)[.,]\d{1,2})(?!\d)',
  );

  /// Integer amount on a line that contains a total or payment label: e.g. `TOTAL 480` or `TOTAL: 480`.
  static final RegExp _totalLineIntegerAmountRegex = RegExp(
    r'(?<!\d)(?<number>\d{1,6})(?!\d)',
  );

  // ---------------------------------------------------------------------------
  // B. DATE REGEXES & RULES
  // ---------------------------------------------------------------------------

  /// Numeric date in `DD/MM/YYYY`, `DD-MM-YYYY`, `DD.MM.YYYY`, or 2-digit year `DD/MM/YY`.
  static final RegExp _dmyNumericRegex = RegExp(
    r'(?<!\d)(?<p1>\d{1,2})\s*[\/\-.]\s*(?<p2>\d{1,2})\s*[\/\-.]\s*(?<year>\d{4}|\d{2})(?!\d)',
  );

  /// ISO-style numeric date in `YYYY-MM-DD`, `YYYY/MM/DD`, or `YYYY.MM.DD`.
  static final RegExp _ymdNumericRegex = RegExp(
    r'(?<!\d)(?<year>20\d{2})\s*[\/\-.]\s*(?<month>0?[1-9]|1[0-2])\s*[\/\-.]\s*(?<day>0?[1-9]|[12]\d|3[01])(?!\d)',
  );

  /// French and English textual date format: e.g. `14 mars 2026`, `1er avril 2026`, `15-Sep-2020`.
  static final RegExp _textualDayFirstDateRegex = RegExp(
    r'\b(?<day>0?[1-9]|[12]\d|3[01])(?:er|st|nd|rd|th)?'
    r'[\s.,/\-_]+'
    r'(?<month>janvier|janv?\.?|jan\.?|f[eé]vrier|f[eé]vr?\.?|february|feb\.?|mars|mar\.?|march|avril|avr?\.?|april|apr\.?|mai|may|juin|june|jun\.?|juillet|juil?\.?|july|jul\.?|ao[uû]t|august|aug\.?|septembre|sept?\.?|sep\.?|september|octobre|oct\.?|october|novembre|nov\.?|november|d[eé]cembre|d[eé]c\.?|december)'
    r'[\s.,/\-_]+'
    r'(?<year>(?:20|19)?[0-9oO]{2})\b',
    caseSensitive: false,
  );

  /// English month-first textual date: e.g. `March 14, 2026`, `September 15, 2020`, `Sep. 15. 2020`.
  static final RegExp _textualMonthFirstDateRegex = RegExp(
    r'\b(?<month>january|janv?\.?|jan\.?|february|feb\.?|march|mar\.?|april|apr\.?|may|june|jun\.?|july|jul\.?|august|aug\.?|september|sept?\.?|sep\.?|october|oct\.?|november|nov\.?|december|dec\.?)'
    r'[\s.,/\-_]+'
    r'(?<day>0?[1-9]|[12]\d|3[01])(?:st|nd|rd|th)?'
    r'[\s.,/\-_]+'
    r'(?<year>(?:20|19)?[0-9oO]{2})\b',
    caseSensitive: false,
  );

  static const Map<String, int> _monthNameMap = <String, int>{
    'janvier': 1,
    'janv': 1,
    'jan': 1,
    'january': 1,
    'fevrier': 2,
    'février': 2,
    'fevr': 2,
    'févr': 2,
    'fev': 2,
    'fév': 2,
    'february': 2,
    'feb': 2,
    'mars': 3,
    'mar': 3,
    'march': 3,
    'avril': 4,
    'avr': 4,
    'april': 4,
    'apr': 4,
    'mai': 5,
    'may': 5,
    'juin': 6,
    'june': 6,
    'jun': 6,
    'juillet': 7,
    'juil': 7,
    'july': 7,
    'jul': 7,
    'aout': 8,
    'août': 8,
    'august': 8,
    'aug': 8,
    'septembre': 9,
    'sept': 9,
    'sep': 9,
    'september': 9,
    'octobre': 10,
    'oct': 10,
    'october': 10,
    'novembre': 11,
    'nov': 11,
    'november': 11,
    'decembre': 12,
    'décembre': 12,
    'dec': 12,
    'déc': 12,
    'december': 12,
  };

  // ---------------------------------------------------------------------------
  // C. MERCHANT NAME REGEXES & RULES
  // ---------------------------------------------------------------------------

  /// Administrative, greeting, or payment headers that must NOT be selected as Merchant Name.
  static final RegExp _excludedMerchantHeaderRegex = RegExp(
    r'^(?:TICKET(?:\s+DE\s+CAISSE|\s+CLIENT)?|DUPLICATA|FACTURE(?:\s+CLIENT)?|RE[CÇ]U(?:\s+CB|\s+CLIENT)?|JUSTIFICATIF|BON\s+DE\s+COMMANDE|NOTE\s+DE\s+RESTAURANT|ADDITION|BIENVENUE.*|BONJOUR.*|MERCI.*|[AÀ]\s+BIENT[OÔ]T.*|CONSERVEZ\s+CE\s+TICKET.*|EXEMPLAIRE\s+(?:CLIENT|COMMER[CÇ]ANT)|CARTE\s+BANCAIRE|CB\s+SANS\s+CONTACT|SANS\s+CONTACT|PAIEMENT\s+PAR\s+CARTE|TICKET\s+CB|CAISSE\b.*|SERVEUR\b.*|TABLE\b.*|CLIENT\b.*|COMMANDE\b.*|DATE\b.*|HEURE\b.*|TOTAL\b.*)$',
    caseSensitive: false,
  );

  /// Tax, registration, legal identifier patterns (SIRET, SIREN, RCS, TVA, APE, NAF).
  static final RegExp _taxOrLegalIdLineRegex = RegExp(
    r'\b(?:SIRET|SIREN|R\.?C\.?S\.?|T\.?V\.?A\.?\s*(?:INTRA|FR)?|N[°ºo]?\s*TVA|CODE\s+APE|APE|NAF|CAPITAL\s+DE|FR\s*\d{2}\s*\d{9})\b',
    caseSensitive: false,
  );

  /// Phone number patterns (French `01 23 45 67 89`, `+33...`, international, or `TEL:` labels).
  static final RegExp _phoneLineRegex = RegExp(
    r'(?:\b(?:T[EÉ]L(?:[EÉ]PHONE)?|FAX|MOBILE|CONTACT)\b|(?:(?:\+33|0033|0)\s*[1-9](?:[\s.\-]*\d{2}){4})|(?:\+\d{1,3}[\s.\-]?\(?\d{2,4}\)?[\s.\-]?\d{3,4}[\s.\-]?\d{3,4}))',
    caseSensitive: false,
  );

  /// Street addresses and French postal codes (`75001 PARIS`, `12 RUE DE LA PAIX`, etc.).
  static final RegExp _addressLineRegex = RegExp(
    r'(?:\b\d{5}\s+[A-ZÀ-Ÿ]{2,}\b|\b(?:\d{1,4}\s*(?:BIS|TER)?\s+)?(?:RUE|AVENUE|AV\.|BOULEVARD|BD\.?|BVD|PLACE|CHEMIN|IMPASSE|ALL[EÉ]E|ROUTE|QUAI|COURS|PASSAGE|ZA|ZAC|ZI|ZONE\s+INDUSTRIELLE|CENTRE\s+COMMERCIAL|CEDEX)\b)',
    caseSensitive: false,
  );

  /// Website URLs or email addresses.
  static final RegExp _urlOrEmailRegex = RegExp(
    r'(?:https?:\/\/|www\.|[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}|\b[a-z0-9-]+\.(?:fr|com|net|org|eu|io)\b)',
    caseSensitive: false,
  );

  /// Common corporate legal suffixes that boost confidence when part of a merchant title.
  static final RegExp _corporateEntityBoostRegex = RegExp(
    r'\b(?:SAS|SASU|SARL|EURL|SA|SNC|GMBH|INC|LTD|LLC|CORP)\b',
    caseSensitive: false,
  );

  // ---------------------------------------------------------------------------
  // PUBLIC PARSING ENTRYPOINT
  // ---------------------------------------------------------------------------

  /// Parses raw OCR text into a [ParsedReceiptResult] with per-field confidence scores.
  ParsedReceiptResult parse(String rawOcrText) {
    final normalizedText = rawOcrText
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');

    final rawLines = normalizedText.split('\n');
    final nonEmptyLines = <_IndexedLine>[];

    for (int i = 0; i < rawLines.length; i++) {
      final trimmed = rawLines[i].trim();
      if (trimmed.isNotEmpty) {
        nonEmptyLines.add(_IndexedLine(index: i, text: trimmed));
      }
    }

    if (nonEmptyLines.isEmpty) {
      return ParsedReceiptResult(
        merchantName: const ParsedField<String>.empty(),
        date: const ParsedField<DateTime>.empty(),
        totalAmountMinorUnits: const ParsedField<int>.empty(),
        suggestedCategory: const ParsedField<String>(
          value: ReceiptCategories.other,
          confidence: 0.30,
        ),
        rawText: rawOcrText,
      );
    }

    final detectedCurrency = _detectCurrency(normalizedText);
    final totalField = _extractTotalAmount(nonEmptyLines);
    final dateField = _extractDate(nonEmptyLines, normalizedText);
    final merchantField = _extractMerchantName(nonEmptyLines);
    final categoryField = _suggestCategory(
      merchantName: merchantField.value,
      fullText: normalizedText,
    );

    return ParsedReceiptResult(
      merchantName: merchantField,
      date: dateField,
      totalAmountMinorUnits: totalField,
      suggestedCategory: categoryField,
      rawText: rawOcrText,
      detectedCurrencyCode: detectedCurrency.$2,
      detectedCurrencySymbol: detectedCurrency.$1,
    );
  }

  static (String? symbol, String? code) _detectCurrency(String fullText) {
    if (fullText.contains(r'$') ||
        RegExp(r'\bUSD\b', caseSensitive: false).hasMatch(fullText)) {
      return (r'$', 'USD');
    }
    if (fullText.contains('€') ||
        RegExp(r'\bEUR(?:OS?)?\b', caseSensitive: false).hasMatch(fullText)) {
      return ('€', 'EUR');
    }
    if (fullText.contains('£') ||
        RegExp(r'\bGBP\b', caseSensitive: false).hasMatch(fullText)) {
      return ('£', 'GBP');
    }
    if (RegExp(r'\bCHF\b', caseSensitive: false).hasMatch(fullText)) {
      return ('CHF', 'CHF');
    }
    if (fullText.contains('¥') ||
        RegExp(r'\bJPY\b', caseSensitive: false).hasMatch(fullText)) {
      return ('¥', 'JPY');
    }
    if (RegExp(r'\bCAD\b', caseSensitive: false).hasMatch(fullText)) {
      return (r'CA$', 'CAD');
    }
    if (RegExp(r'\b(?:MAD|DH|درهم)\b', caseSensitive: false).hasMatch(fullText)) {
      return ('DH', 'MAD');
    }
    if (RegExp(r'\b(?:SAR|ريال)\b', caseSensitive: false).hasMatch(fullText)) {
      return ('SAR', 'SAR');
    }
    if (RegExp(r'\b(?:AED)\b', caseSensitive: false).hasMatch(fullText)) {
      return ('AED', 'AED');
    }
    if (RegExp(r'\b(?:DZD|DA|دينار)\b', caseSensitive: false).hasMatch(fullText)) {
      return ('DA', 'DZD');
    }
    if (RegExp(r'\b(?:TND|DT)\b', caseSensitive: false).hasMatch(fullText)) {
      return ('DT', 'TND');
    }
    if (RegExp(r'\b(?:EGP|جنيه)\b', caseSensitive: false).hasMatch(fullText)) {
      return (r'E£', 'EGP');
    }
    if (RegExp(r'\b(?:BRL|R\$)\b', caseSensitive: false).hasMatch(fullText)) {
      return (r'R$', 'BRL');
    }
    if (RegExp(r'\b(?:AUD|AU\$)\b', caseSensitive: false).hasMatch(fullText)) {
      return (r'AU$', 'AUD');
    }
    if (RegExp(r'\b(?:INR|₹)\b', caseSensitive: false).hasMatch(fullText)) {
      return ('₹', 'INR');
    }
    if (RegExp(r'\b(?:TRY|TL|₺)\b', caseSensitive: false).hasMatch(fullText)) {
      return ('₺', 'TRY');
    }
    if (RegExp(r'\b(?:PLN|zł)\b', caseSensitive: false).hasMatch(fullText)) {
      return ('zł', 'PLN');
    }
    if (RegExp(r'\b(?:SEK)\b', caseSensitive: false).hasMatch(fullText)) {
      return ('kr', 'SEK');
    }
    return (null, null);
  }

  // ---------------------------------------------------------------------------
  // 1. TOTAL AMOUNT EXTRACTION
  // ---------------------------------------------------------------------------

  ParsedField<int> _extractTotalAmount(List<_IndexedLine> lines) {
    final candidates = <_AmountCandidate>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final text = line.text;

      final isTableHeader = _tableHeaderLineRegex.hasMatch(text);
      final isExcluded =
          _excludedAmountLineRegex.hasMatch(text) ||
          _vatOnlyLineRegex.hasMatch(text);

      final isTier1 =
          !isTableHeader && !isExcluded && _tier1TotalLabelRegex.hasMatch(text);
      final isTier2 =
          !isTableHeader &&
          !isExcluded &&
          !isTier1 &&
          _tier2TotalLabelRegex.hasMatch(text);
      final isTier3 =
          !isTableHeader &&
          !isTier1 &&
          !isTier2 &&
          _tier3PaymentOrSubtotalLabelRegex.hasMatch(text);

      final lineAmounts = _extractAmountsFromSingleLine(
        text,
        isTotalLine: isTier1 || isTier2,
      );

      if (lineAmounts.isNotEmpty && !isExcluded && !isTableHeader) {
        // When multiple amounts exist on a single total line, the rightmost
        // amount is almost universally the final TTC column.
        final chosenAmount = lineAmounts.last;
        double score = 0.45;

        if (isTier1) {
          score = chosenAmount.hasExplicitCurrency ? 0.98 : 0.95;
        } else if (isTier2) {
          score = chosenAmount.hasExplicitCurrency ? 0.93 : 0.90;
        } else if (isTier3) {
          score = chosenAmount.hasExplicitCurrency ? 0.78 : 0.72;
        } else {
          // Regular item line or unlabeled bottom line.
          final relativePosition = (i + 1) / lines.length;
          final positionBonus = relativePosition >= 0.5 ? 0.12 : 0.0;
          final currencyBonus = chosenAmount.hasExplicitCurrency ? 0.10 : 0.0;
          score = (0.42 + positionBonus + currencyBonus).clamp(0.35, 0.68);
        }

        candidates.add(
          _AmountCandidate(
            minorUnits: chosenAmount.minorUnits,
            confidence: score,
            tier: isTier1
                ? 1
                : isTier2
                ? 2
                : isTier3
                ? 3
                : 4,
            rawMatch: chosenAmount.rawMatch,
            lineIndex: line.index,
          ),
        );
      } else if ((isTier1 || isTier2) && i + 1 < lines.length) {
        // Multi-line OCR layout fallback:
        // We must check if line `i` is a TABLE COLUMN HEADER (followed by multiple rows of amounts)
        // or a genuine 2-line receipt total (followed by a single amount).
        final nextLine = lines[i + 1];
        if (!_excludedAmountLineRegex.hasMatch(nextLine.text) &&
            !_vatOnlyLineRegex.hasMatch(nextLine.text) &&
            !_tableHeaderLineRegex.hasMatch(nextLine.text)) {
          final nextLineAmounts = _extractAmountsFromSingleLine(
            nextLine.text,
            isTotalLine: true,
          );
          if (nextLineAmounts.isNotEmpty) {
            // Check if line `i + 2` also contains an amount (indicating a vertical table column of items!)
            bool isColumnOfAmounts = false;
            int lastColumnAmountMinor = nextLineAmounts.last.minorUnits;
            String lastColumnRawMatch = nextLineAmounts.last.rawMatch;
            int lastColumnLineIndex = nextLine.index;
            bool lastHasCurrency = nextLineAmounts.last.hasExplicitCurrency;

            if (i + 2 < lines.length) {
              final lineAfterNextAmounts = _extractAmountsFromSingleLine(
                lines[i + 2].text,
                isTotalLine: false,
              );
              if (lineAfterNextAmounts.isNotEmpty) {
                isColumnOfAmounts = true;
                // Follow the column down to find the column's bottom/summary total!
                for (int k = i + 2; k < lines.length; k++) {
                  final kText = lines[k].text;
                  if (_excludedAmountLineRegex.hasMatch(kText) ||
                      _vatOnlyLineRegex.hasMatch(kText) ||
                      _tableHeaderLineRegex.hasMatch(kText)) {
                    break;
                  }
                  final kAmounts = _extractAmountsFromSingleLine(
                    kText,
                    isTotalLine: true,
                  );
                  if (kAmounts.isEmpty) {
                    break;
                  }
                  lastColumnAmountMinor = kAmounts.last.minorUnits;
                  lastColumnRawMatch = kAmounts.last.rawMatch;
                  lastColumnLineIndex = lines[k].index;
                  lastHasCurrency = kAmounts.last.hasExplicitCurrency;
                }
              }
            }

            if (isColumnOfAmounts) {
              // In a table column under TOTAL, the grand total is at the BOTTOM of the column!
              candidates.add(
                _AmountCandidate(
                  minorUnits: lastColumnAmountMinor,
                  confidence: lastHasCurrency ? 0.94 : 0.90,
                  tier: isTier1 ? 1 : 2,
                  rawMatch: '${line.text} column total $lastColumnRawMatch',
                  lineIndex: lastColumnLineIndex,
                ),
              );
            } else {
              // Standard 2-line receipt total (e.g. "TOTAL TTC \n 48,90 €")
              final chosen = nextLineAmounts.last;
              final baseScore = isTier1 ? 0.94 : 0.88;
              candidates.add(
                _AmountCandidate(
                  minorUnits: chosen.minorUnits,
                  confidence: chosen.hasExplicitCurrency
                      ? baseScore + 0.02
                      : baseScore,
                  tier: isTier1 ? 1 : 2,
                  rawMatch: '${line.text} ${chosen.rawMatch}',
                  lineIndex: nextLine.index,
                ),
              );
            }
          }
        }
      }
    }

    if (candidates.isEmpty) {
      return const ParsedField<int>.empty();
    }

    // Sort candidates by:
    // 1. Best tier (1 -> 4)
    // 2. Highest confidence
    // 3. For equal tier, prefer the lower line on the receipt (totals appear near the bottom)
    // 4. Larger amount as final tie-breaker
    candidates.sort((a, b) {
      final tierCmp = a.tier.compareTo(b.tier);
      if (tierCmp != 0) return tierCmp;

      final confCmp = b.confidence.compareTo(a.confidence);
      if (confCmp != 0) return confCmp;

      if (a.tier <= 2) {
        final lineCmp = b.lineIndex.compareTo(a.lineIndex);
        if (lineCmp != 0) return lineCmp;
      }

      return b.minorUnits.compareTo(a.minorUnits);
    });

    final best = candidates.first;
    return ParsedField<int>(
      value: best.minorUnits,
      confidence: best.confidence,
      rawMatch: best.rawMatch,
      lineIndex: best.lineIndex,
    );
  }

  List<_LineAmountMatch> _extractAmountsFromSingleLine(
    String lineText, {
    bool isTotalLine = false,
  }) {
    final results = <_LineAmountMatch>[];

    // Mask out dates, times, units, invoice numbers, and phone numbers
    final maskedLine = lineText
        .replaceAll(_dmyNumericRegex, ' [DATE] ')
        .replaceAll(_ymdNumericRegex, ' [DATE] ')
        .replaceAll(_textualDayFirstDateRegex, ' [DATE] ')
        .replaceAll(_textualMonthFirstDateRegex, ' [DATE] ')
        .replaceAll(RegExp(r'\b\d{1,2}[:hH]\d{2}(?::\d{2})?\b'), ' [TIME] ')
        .replaceAll(_invoiceMetadataPrefixRegex, ' [INVOICE] ')
        .replaceAll(
          RegExp(r'\b\d+[.,]\d+\s*(?:%|kg|g|l|ml|km)\b', caseSensitive: false),
          ' [UNIT] ',
        );

    final matchedSpans = <(int start, int end)>[];

    bool overlaps(int start, int end) {
      return matchedSpans.any((s) => !(end <= s.$1 || start >= s.$2));
    }

    // 1. Currency prefixed amounts ($80, $160, €18.40)
    for (final match in _currencyPrefixedAmountRegex.allMatches(maskedLine)) {
      if (overlaps(match.start, match.end)) continue;
      final rawNumber = match.namedGroup('number');
      if (rawNumber == null) continue;
      final minorUnits = _parseRawAmountToMinorUnits(rawNumber);
      if (minorUnits != null && minorUnits > 0 && minorUnits <= 100000000) {
        matchedSpans.add((match.start, match.end));
        results.add(
          _LineAmountMatch(
            minorUnits: minorUnits,
            hasExplicitCurrency: true,
            rawMatch: match.group(0)!.trim(),
            startOffset: match.start,
          ),
        );
      }
    }

    // 2. Currency suffixed amounts (80$, 12,50 €, 480 EUR)
    for (final match in _currencySuffixedAmountRegex.allMatches(maskedLine)) {
      if (overlaps(match.start, match.end)) continue;
      final rawNumber = match.namedGroup('number');
      if (rawNumber == null) continue;
      final minorUnits = _parseRawAmountToMinorUnits(rawNumber);
      if (minorUnits != null && minorUnits > 0 && minorUnits <= 100000000) {
        matchedSpans.add((match.start, match.end));
        results.add(
          _LineAmountMatch(
            minorUnits: minorUnits,
            hasExplicitCurrency: true,
            rawMatch: match.group(0)!.trim(),
            startOffset: match.start,
          ),
        );
      }
    }

    // 3. Plain decimal numbers (12.50, 12,50, 1250.00)
    for (final match in _decimalAmountRegex.allMatches(maskedLine)) {
      if (overlaps(match.start, match.end)) continue;
      final rawNumber = match.namedGroup('number');
      if (rawNumber == null) continue;
      final minorUnits = _parseRawAmountToMinorUnits(rawNumber);
      if (minorUnits != null && minorUnits > 0 && minorUnits <= 100000000) {
        matchedSpans.add((match.start, match.end));
        results.add(
          _LineAmountMatch(
            minorUnits: minorUnits,
            hasExplicitCurrency: false,
            rawMatch: match.group(0)!.trim(),
            startOffset: match.start,
          ),
        );
      }
    }

    // 4. If this line has an explicit Total keyword, also capture plain integers (e.g. `TOTAL 480`)
    if (isTotalLine) {
      for (final match in _totalLineIntegerAmountRegex.allMatches(maskedLine)) {
        if (overlaps(match.start, match.end)) continue;
        final rawNumber = match.namedGroup('number');
        if (rawNumber == null) continue;
        final minorUnits = _parseRawAmountToMinorUnits(rawNumber);
        if (minorUnits != null && minorUnits > 0 && minorUnits <= 100000000) {
          matchedSpans.add((match.start, match.end));
          results.add(
            _LineAmountMatch(
              minorUnits: minorUnits,
              hasExplicitCurrency: false,
              rawMatch: match.group(0)!.trim(),
              startOffset: match.start,
            ),
          );
        }
      }
    }

    results.sort((a, b) => a.startOffset.compareTo(b.startOffset));
    return results;
  }

  int? _parseRawAmountToMinorUnits(String rawNumber) {
    final cleaned = rawNumber.replaceAll(RegExp(r'[\s\u00A0\u202F]'), '');
    if (cleaned.isEmpty) return null;

    final lastSepIndex = cleaned.lastIndexOf(RegExp(r'[.,]'));
    if (lastSepIndex < 0) {
      // Integer amount like 80, 160, 320, 480
      final val = int.tryParse(cleaned);
      if (val == null || val <= 0 || val > 1000000) return null;
      return val * 100;
    }

    final afterSep = cleaned.substring(lastSepIndex + 1);
    final beforeSep = cleaned.substring(0, lastSepIndex);

    // If 1 or 2 digits after separator, it's a decimal (e.g. `12.50`, `12,5`, `1,250.50`)
    if (afterSep.length == 1 || afterSep.length == 2) {
      final intCleaned = beforeSep.replaceAll(RegExp(r'[.,]'), '');
      final majorUnits = int.tryParse(intCleaned);
      if (majorUnits == null) return null;
      final minorDigits = afterSep.length == 1 ? '${afterSep}0' : afterSep;
      final minorUnits = int.tryParse(minorDigits);
      if (minorUnits == null) return null;
      return (majorUnits * 100) + minorUnits;
    }

    // If 3 digits after separator and no other separator, thousand separator like `1,250` or `1.250`
    if (afterSep.length == 3 && !beforeSep.contains(RegExp(r'[.,]'))) {
      final intVal = int.tryParse('$beforeSep$afterSep');
      if (intVal != null && intVal > 0) return intVal * 100;
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // 2. RECEIPT DATE EXTRACTION
  // ---------------------------------------------------------------------------

  /// Labels introducing a payment due date (not the document date).
  static final RegExp dueDateLabelRegex = RegExp(
    r"(?:DUE\s+DATE|DATE\s+D['’]?\s*[EÉ]CH[EÉ]ANCE|[EÉ]CH[EÉ]ANCE|PAYABLE\s+(?:AVANT|LE|AU)|[AÀ]\s+R[EÈ]GLER\s+(?:AVANT|LE)|PAY(?:MENT)?\s+(?:DUE|BY)|DUE\s+(?:ON|BY)|DATE\s+LIMITE|R[EÈ]GLEMENT\s+(?:AVANT|LE|[AÀ]))",
    caseSensitive: false,
  );

  Set<int> _dueDateLineIndexes(List<_IndexedLine> lines) {
    final result = <int>{};
    for (int i = 0; i < lines.length; i++) {
      if (!dueDateLabelRegex.hasMatch(lines[i].text)) continue;
      result.add(lines[i].index);
      // Label-only line: the date sits on the next non-empty line.
      final text = lines[i].text;
      final hasDate =
          _dmyNumericRegex.hasMatch(text) ||
          _ymdNumericRegex.hasMatch(text) ||
          _textualDayFirstDateRegex.hasMatch(text) ||
          _textualMonthFirstDateRegex.hasMatch(text);
      if (!hasDate && i + 1 < lines.length) result.add(lines[i + 1].index);
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // PUBLIC HELPERS (used by FinancialDocumentAnalyzer)
  // ---------------------------------------------------------------------------

  static List<_IndexedLine> _indexLines(String text) {
    final raw = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n');
    final out = <_IndexedLine>[];
    for (int i = 0; i < raw.length; i++) {
      final t = raw[i].trim();
      if (t.isNotEmpty) out.add(_IndexedLine(index: i, text: t));
    }
    return out;
  }

  /// Extracts the best date from arbitrary [text] (ignoring due-date lines when possible).
  ParsedField<DateTime> extractDateFromText(String text) =>
      _extractDate(_indexLines(text), text);

  /// Extracts the best date found only on lines carrying a due-date label
  /// (or on the line following a label-only line).
  ParsedField<DateTime> extractDueDateFromText(String text) {
    final lines = _indexLines(text);
    final due = _dueDateLineIndexes(lines);
    if (due.isEmpty) return const ParsedField<DateTime>.empty();
    final dueText = lines
        .where((l) => due.contains(l.index))
        .map((l) => l.text.replaceAll(dueDateLabelRegex, ' '))
        .join('\n');
    return _extractDate(_indexLines(dueText), text, allowFuture: true);
  }

  /// Monetary amounts on a single [line], in minor units, left to right.
  /// Percentages (`20 %`) are removed first so VAT rates are not read as amounts.
  List<int> extractAmountsMinorUnits(String line, {bool isTotalLine = false}) {
    final stripped = line.replaceAll(RegExp(r'\d+(?:[.,]\d+)?\s*%'), ' ');
    return _extractAmountsFromSingleLine(
      stripped,
      isTotalLine: isTotalLine,
    ).map((m) => m.minorUnits).toList();
  }

  /// Parses one numeric token (`1 250,50`, `1.250,50`, `12.5`, `80`) into minor units.
  int? parseAmountMinorUnits(String token) => _parseRawAmountToMinorUnits(
    token
        .replaceAll(RegExp(r'[$€£¥]|EUR|USD|GBP|CHF', caseSensitive: false), '')
        .trim(),
  );

  ParsedField<DateTime> _extractDate(
    List<_IndexedLine> lines,
    String fullText, {
    bool allowFuture = false,
  }) {
    final candidates = <_DateCandidate>[];
    final preferUsOrder =
        (fullText.contains(r'$') ||
            RegExp(r'\bUSD\b', caseSensitive: false).hasMatch(fullText)) &&
        !fullText.contains('€') &&
        !RegExp(r'\bEUR\b', caseSensitive: false).hasMatch(fullText);

    for (final line in lines) {
      final text = line.text;

      // Skip SIRET/TVA/Phone-only lines to avoid false numeric matches
      if (_taxOrLegalIdLineRegex.hasMatch(text)) continue;

      final hasDateKeyword = RegExp(
        r'\b(?:DATE|LE|DU|TICKET\s+DU|EMIS\s+LE)\b',
        caseSensitive: false,
      ).hasMatch(text);
      final keywordBonus = hasDateKeyword ? 0.04 : 0.0;

      // 1. ISO Format: YYYY-MM-DD / YYYY/MM/DD / YYYY.MM.DD
      for (final match in _ymdNumericRegex.allMatches(text)) {
        final year = int.parse(match.namedGroup('year')!);
        final month = int.parse(match.namedGroup('month')!);
        final day = int.parse(match.namedGroup('day')!);
        final built = _buildValidDate(
          year,
          month,
          day,
          allowFuture: allowFuture,
        );
        if (built != null) {
          candidates.add(
            _DateCandidate(
              date: built,
              confidence: (0.95 + keywordBonus).clamp(0.0, 0.99),
              rawMatch: match.group(0)!,
              lineIndex: line.index,
              isAmbiguous: false,
            ),
          );
        }
      }

      // 2. French/International textual date: `14 mars 2026`, `5 janv. 2026`, `15-Sep-2020`
      for (final match in _textualDayFirstDateRegex.allMatches(text)) {
        final day = int.tryParse(match.namedGroup('day') ?? '');
        if (day == null) continue;
        final rawMonth = (match.namedGroup('month') ?? '')
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-zà-ÿ]'), '');
        final sanitizedYear = (match.namedGroup('year') ?? '').replaceAll(
          RegExp(r'[oO]'),
          '0',
        );
        final parsedYear = int.tryParse(sanitizedYear);
        if (parsedYear == null) continue;
        final year = _normalizeYear(parsedYear);
        final month = _monthNameMap[rawMonth];
        if (month != null) {
          final built = _buildValidDate(
            year,
            month,
            day,
            allowFuture: allowFuture,
          );
          if (built != null) {
            candidates.add(
              _DateCandidate(
                date: built,
                confidence: (0.96 + keywordBonus).clamp(0.0, 0.99),
                rawMatch: match.group(0)!,
                lineIndex: line.index,
                isAmbiguous: false,
              ),
            );
          }
        }
      }

      // 3. English month-first textual date: `September 15, 2020`, `March 14, 2026`
      for (final match in _textualMonthFirstDateRegex.allMatches(text)) {
        final day = int.tryParse(match.namedGroup('day') ?? '');
        if (day == null) continue;
        final rawMonth = (match.namedGroup('month') ?? '')
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-zà-ÿ]'), '');
        final sanitizedYear = (match.namedGroup('year') ?? '').replaceAll(
          RegExp(r'[oO]'),
          '0',
        );
        final parsedYear = int.tryParse(sanitizedYear);
        if (parsedYear == null) continue;
        final year = _normalizeYear(parsedYear);
        final month = _monthNameMap[rawMonth];
        if (month != null) {
          final built = _buildValidDate(
            year,
            month,
            day,
            allowFuture: allowFuture,
          );
          if (built != null) {
            candidates.add(
              _DateCandidate(
                date: built,
                confidence: (0.96 + keywordBonus).clamp(0.0, 0.99),
                rawMatch: match.group(0)!,
                lineIndex: line.index,
                isAmbiguous: false,
              ),
            );
          }
        }
      }

      // 4. Numeric DD/MM/YYYY, DD-MM-YYYY, DD.MM.YYYY (or MM/DD/YYYY when US or second part > 12)
      for (final match in _dmyNumericRegex.allMatches(text)) {
        final rawYear = match.namedGroup('year')!;
        final p1 = int.parse(match.namedGroup('p1')!);
        final p2 = int.parse(match.namedGroup('p2')!);
        final year = _normalizeYear(int.parse(rawYear));
        final isFourDigitYear = rawYear.length == 4;

        int? day;
        int? month;
        bool isAmbiguous = false;
        double baseConfidence = isFourDigitYear ? 0.93 : 0.85;

        if (p1 > 12 && p1 <= 31 && p2 >= 1 && p2 <= 12) {
          // Unambiguously DD/MM/YYYY (e.g. 24/03/2026)
          day = p1;
          month = p2;
          baseConfidence = isFourDigitYear ? 0.96 : 0.89;
        } else if (p2 > 12 && p2 <= 31 && p1 >= 1 && p1 <= 12) {
          // Unambiguously MM/DD/YYYY (e.g. 03/24/2026)
          month = p1;
          day = p2;
          baseConfidence = isFourDigitYear ? 0.91 : 0.84;
        } else if (p1 >= 1 && p1 <= 12 && p2 >= 1 && p2 <= 12) {
          if (p1 == p2) {
            // Identical day and month (e.g. 05/05/2026) -> unambiguous!
            day = p1;
            month = p2;
            isAmbiguous = false;
            baseConfidence = isFourDigitYear ? 0.95 : 0.88;
          } else {
            // Both parts are <= 12 and distinct (e.g. 04/05/2026).
            // Prioritize European DD/MM/YYYY unless receipt is explicitly USD-only,
            // and mark as ambiguous so validation UI highlights it.
            isAmbiguous = true;
            if (preferUsOrder) {
              month = p1;
              day = p2;
            } else {
              day = p1;
              month = p2;
            }
            baseConfidence = isFourDigitYear ? 0.78 : 0.72;
          }
        }

        if (day != null && month != null) {
          final built = _buildValidDate(
            year,
            month,
            day,
            allowFuture: allowFuture,
          );
          if (built != null) {
            candidates.add(
              _DateCandidate(
                date: built,
                confidence: (baseConfidence + keywordBonus).clamp(0.0, 0.99),
                rawMatch: match.group(0)!,
                lineIndex: line.index,
                isAmbiguous: isAmbiguous,
              ),
            );
          }
        }
      }
    }

    // Payment due dates ("Date d'échéance", "Due date") must not be mistaken for
    // the document date unless nothing else is available.
    final dueIdx = _dueDateLineIndexes(lines);
    if (dueIdx.isNotEmpty) {
      final nonDue = candidates
          .where((c) => !dueIdx.contains(c.lineIndex))
          .toList();
      if (nonDue.isNotEmpty) {
        candidates
          ..clear()
          ..addAll(nonDue);
      }
    }

    if (candidates.isEmpty) {
      return const ParsedField<DateTime>.empty();
    }

    candidates.sort((a, b) => b.confidence.compareTo(a.confidence));
    final best = candidates.first;

    return ParsedField<DateTime>(
      value: best.date,
      confidence: best.confidence,
      rawMatch: best.rawMatch,
      lineIndex: best.lineIndex,
      isAmbiguous: best.isAmbiguous,
    );
  }

  int _normalizeYear(int rawYear) {
    if (rawYear < 100) {
      return 2000 + rawYear;
    }
    return rawYear;
  }

  DateTime? _buildValidDate(
    int year,
    int month,
    int day, {
    bool allowFuture = false,
  }) {
    final maxAllowedYear = _now.year + 1;
    if (year < 2000 || year > maxAllowedYear) return null;
    if (month < 1 || month > 12) return null;
    if (day < 1 || day > 31) return null;

    final candidate = DateTime(year, month, day);
    // Reject overflow dates such as Feb 30 (`DateTime(2026, 2, 30)` rolls over to March)
    if (candidate.year != year ||
        candidate.month != month ||
        candidate.day != day) {
      return null;
    }

    // Reject dates more than 7 days in the future relative to reference clock
    // (payment due dates are legitimately in the future, hence `allowFuture`).
    if (!allowFuture && candidate.isAfter(_now.add(const Duration(days: 7)))) {
      return null;
    }

    return candidate;
  }

  // ---------------------------------------------------------------------------
  // 3. MERCHANT NAME EXTRACTION
  // ---------------------------------------------------------------------------

  ParsedField<String> _extractMerchantName(List<_IndexedLine> lines) {
    final candidates = <_MerchantCandidate>[];

    // Inspect the top lines where merchant names appear on receipts/invoices.
    final searchLimit = lines.length < 10 ? lines.length : 10;
    int skipRecipientLinesRemaining = 0;

    for (int i = 0; i < searchLimit; i++) {
      final line = lines[i];
      final text = line.text;

      // Check for explicit Vendor / Supplier prefixes (e.g., "From: Zara", "Fournisseur: ACME")
      // Case A: Inline vendor prefix anywhere in the text (e.g. "From: Olivia Wilson")
      final vendorInlineMatch = RegExp(
        r'\b(?:FROM|SOLD\s+BY|VENDOR|SUPPLIER|FOURNISSEUR|[EÉ]METTEUR|ISSUED\s+BY)\s*[:\-#]\s*(?<name>[A-Za-zÀ-ÿ0-9\s.&_-]{2,})',
        caseSensitive: false,
      ).firstMatch(text);

      if (vendorInlineMatch != null) {
        final extracted = vendorInlineMatch.namedGroup('name')?.trim();
        if (extracted != null &&
            extracted.length >= 2 &&
            !_isExcludedMerchantLine(extracted)) {
          candidates.add(
            _MerchantCandidate(
              name: _formatMerchantName(extracted),
              confidence: 0.96,
              rawMatch: text,
              lineIndex: line.index,
            ),
          );
          continue;
        }
      }

      // Case B: Standalone vendor prefix line (e.g. Line i: "From:", Line i+1: "Olivia Wilson")
      final vendorPrefixMatch = _vendorPrefixRegex.firstMatch(text);
      if (vendorPrefixMatch != null) {
        final stripped = text.substring(vendorPrefixMatch.end).trim();
        if (stripped.length >= 2 && !_isExcludedMerchantLine(stripped)) {
          candidates.add(
            _MerchantCandidate(
              name: _formatMerchantName(stripped),
              confidence: 0.96,
              rawMatch: text,
              lineIndex: line.index,
            ),
          );
          continue;
        } else if (i + 1 < lines.length) {
          final nextLineText = _cleanMerchantCandidateLine(lines[i + 1].text);
          if (nextLineText.length >= 2 &&
              !_isExcludedMerchantLine(nextLineText)) {
            candidates.add(
              _MerchantCandidate(
                name: _formatMerchantName(nextLineText),
                confidence: 0.95,
                rawMatch: '${line.text} $nextLineText',
                lineIndex: lines[i + 1].index,
              ),
            );
            i++;
            continue;
          }
        }
      }

      // Check if this line introduces a client/recipient block (e.g. "Billed to:", "Facturé à:")
      if (_clientOrRecipientPrefixRegex.hasMatch(text)) {
        // Skip this line and up to 3 subsequent recipient details (name, phone, address)
        skipRecipientLinesRemaining = 3;
        continue;
      }

      if (skipRecipientLinesRemaining > 0) {
        skipRecipientLinesRemaining--;
        continue;
      }

      final cleaned = _cleanMerchantCandidateLine(text);
      if (cleaned.length < 2) continue;

      if (_isExcludedMerchantLine(cleaned)) continue;

      final letterCount = RegExp(r'[A-Za-zÀ-ÿ]').allMatches(cleaned).length;
      final digitCount = RegExp(r'\d').allMatches(cleaned).length;

      // Require at least 2 letters and more letters than digits
      if (letterCount < 2 || digitCount > letterCount) continue;

      // Position score: Line 0 gets highest base confidence
      double score;
      if (i == 0) {
        score = 0.92;
      } else if (i == 1) {
        score = 0.85;
      } else if (i == 2) {
        score = 0.78;
      } else {
        score = (0.70 - ((i - 2) * 0.06)).clamp(0.45, 0.70);
      }

      // Boost if corporate entity suffix or all-uppercase brand title
      if (_corporateEntityBoostRegex.hasMatch(cleaned)) {
        score += 0.04;
      }
      if (cleaned == cleaned.toUpperCase() && letterCount >= 4) {
        score += 0.02;
      }
      // Slight penalty if digits are mixed in (unless part of brand like "CARREFOUR CITY")
      if (digitCount > 2) {
        score -= 0.12;
      }

      candidates.add(
        _MerchantCandidate(
          name: _formatMerchantName(cleaned),
          confidence: score.clamp(0.35, 0.97),
          rawMatch: line.text,
          lineIndex: line.index,
        ),
      );
    }

    if (candidates.isEmpty) {
      return const ParsedField<String>.empty();
    }

    candidates.sort((a, b) => b.confidence.compareTo(a.confidence));
    final best = candidates.first;

    return ParsedField<String>(
      value: best.name,
      confidence: best.confidence,
      rawMatch: best.rawMatch,
      lineIndex: best.lineIndex,
    );
  }

  String _cleanMerchantCandidateLine(String raw) {
    // Strip decorative receipt borders (`***`, `===`, `---`)
    return raw
        .replaceAll(RegExp(r'^[\*\=\-\_\#\~\+\s]+|[\*\=\-\_\#\~\+\s]+$'), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }

  /// Determines if a line is a general document type title (e.g. `INVOICE`, `INVO|CE`, `FACTURE`, `RECEIPT`)
  /// rather than a legitimate merchant or company name.
  static bool _isDocumentTypeHeader(String line) {
    if (_excludedMerchantHeaderRegex.hasMatch(line)) return true;

    // Normalize OCR artifacts: replace pipes with I, 0 with O, 1 with I, remove punctuation & spaces
    final normalized = line
        .replaceAll('|', 'I')
        .replaceAll('0', 'O')
        .replaceAll('1', 'I')
        .replaceAll(RegExp(r'[^A-Za-z]'), '')
        .toUpperCase();

    const excludedTitles = <String>{
      'INVOICE',
      'TAXINVOICE',
      'COMMERCIALINVOICE',
      'SALESINVOICE',
      'VATINVOICE',
      'PROFORMAINVOICE',
      'PROFORMA',
      'FACTURE',
      'FACTUREPROFORMA',
      'FACTUREDAVOIR',
      'FACTURETTE',
      'FACTUREACQUITTEE',
      'RECEIPT',
      'SALESRECEIPT',
      'CASHRECEIPT',
      'OFFICIALRECEIPT',
      'RECU',
      'TICKET',
      'TICKETDECAISSE',
      'DUPLICATA',
      'DEVIS',
      'ESTIMATE',
      'QUOTATION',
      'QUOTE',
      'STATEMENT',
      'ACCOUNTSTATEMENT',
      'BILLINGSTATEMENT',
      'BILL',
      'BILLOFSALE',
      'JUSTIFICATIF',
      'BONDECOMMANDE',
      'BONDELIVRAISON',
      'NOTEDEDEPENSE',
      'NOTEDERESTAURANT',
      'ADDITION',
      'ORDER',
      'PURCHASEORDER',
    };

    return excludedTitles.contains(normalized);
  }

  bool _isExcludedMerchantLine(String line) {
    if (_isDocumentTypeHeader(line)) return true;
    if (_excludedMerchantHeaderRegex.hasMatch(line)) return true;
    if (_clientOrRecipientPrefixRegex.hasMatch(line)) return true;
    if (_invoiceMetadataPrefixRegex.hasMatch(line)) return true;
    if (_tableHeaderLineRegex.hasMatch(line)) return true;
    if (_taxOrLegalIdLineRegex.hasMatch(line)) return true;
    if (_phoneLineRegex.hasMatch(line)) return true;
    if (_addressLineRegex.hasMatch(line)) return true;
    if (_urlOrEmailRegex.hasMatch(line)) return true;
    if (_tier1TotalLabelRegex.hasMatch(line) ||
        _tier2TotalLabelRegex.hasMatch(line) ||
        _tier3PaymentOrSubtotalLabelRegex.hasMatch(line)) {
      return true;
    }
    if (_excludedAmountLineRegex.hasMatch(line)) return true;

    // Exclude lines that contain a monetary figure or date
    if (_currencyPrefixedAmountRegex.hasMatch(line) ||
        _currencySuffixedAmountRegex.hasMatch(line) ||
        _decimalAmountRegex.hasMatch(line)) {
      return true;
    }
    if (_dmyNumericRegex.hasMatch(line) ||
        _ymdNumericRegex.hasMatch(line) ||
        _textualDayFirstDateRegex.hasMatch(line) ||
        _textualMonthFirstDateRegex.hasMatch(line)) {
      return true;
    }

    return false;
  }

  String _formatMerchantName(String cleaned) {
    return cleaned.trim();
  }

  // ---------------------------------------------------------------------------
  // 4. CATEGORY SUGGESTION
  // ---------------------------------------------------------------------------

  ParsedField<String> _suggestCategory({
    required String? merchantName,
    required String fullText,
  }) {
    final combined = '${merchantName ?? ''} \n $fullText'.toLowerCase();

    // Professional services, consulting, IT, dev, web, design, freelance
    if (RegExp(
      r'\b(consulting|consultant|consultation|development|developpement|d[eé]veloppement|web|software|logiciel|design|graphic|graphique|marketing|seo|freelance|prestation|prestations|honoraires|avocat|notaire|comptable|expertise|audit|conseil|agency|agence|studio)\b',
    ).hasMatch(combined)) {
      return const ParsedField<String>(
        value: ReceiptCategories.professionalServices,
        confidence: 0.88,
      );
    }

    // Apparel, clothing, and fashion keywords
    if (RegExp(
      r'\b(tank\s*top|jacket|denim|shirt|t-shirt|tee-shirt|pants|trousers|dress|skirt|shoes|sneakers|coat|sweater|pull|chemise|pantalon|jean|chaussures|v[eê]tements?|mode|fashion|apparel|clothing|zara|h&m|uniqlo|mango|celio)\b',
    ).hasMatch(combined)) {
      return const ParsedField<String>(
        value: ReceiptCategories.other,
        confidence: 0.80,
      );
    }

    if (RegExp(
      r'\b(carrefour|auchan|leclerc|intermarche|intermarché|monoprix|franprix|lidl|aldi|casino|super\s*u|hyper\s*u|biocoop|picard|supermarket|epicerie|épicerie)\b',
    ).hasMatch(combined)) {
      return const ParsedField<String>(
        value: ReceiptCategories.groceries,
        confidence: 0.88,
      );
    }

    if (RegExp(
      r'\b(restaurant|bistro|bistrot|brasserie|cafe|café|starbucks|mcdonald|burger|pizza|boulangerie|patisserie|pâtisserie|paul|sushi|traiteur|menu|espresso|croissant)\b',
    ).hasMatch(combined)) {
      return const ParsedField<String>(
        value: ReceiptCategories.mealsAndDining,
        confidence: 0.86,
      );
    }

    if (RegExp(
      r'\b(totalenergies|total\s+access|shell|bp|esso|station|carburant|gazole|sans\s+plomb|sp95|sp98|peage|péage|vinci\s+autoroutes|sncf|ratp|uber|taxi|bolt|parking|indigo|effia|train)\b',
    ).hasMatch(combined)) {
      return const ParsedField<String>(
        value: ReceiptCategories.transportAndFuel,
        confidence: 0.88,
      );
    }

    if (RegExp(
      r'\b(hotel|hôtel|ibis|novotel|mercure|accor|booking|airbnb|hostel|chambre|nuitee|nuitée|taxe\s+de\s+séjour)\b',
    ).hasMatch(combined)) {
      return const ParsedField<String>(
        value: ReceiptCategories.accommodation,
        confidence: 0.87,
      );
    }

    if (RegExp(
      r'\b(bureau\s+vallée|bureau\s+vallee|staples|papeterie|fnac|darty|boulanger|ldlc|apple|amazon|cartouche|imprimante|fournitures)\b',
    ).hasMatch(combined)) {
      return const ParsedField<String>(
        value: ReceiptCategories.officeSupplies,
        confidence: 0.82,
      );
    }

    if (RegExp(
      r'\b(pharmacie|parapharmacie|medecin|médecin|laboratoire|optique|dentiste)\b',
    ).hasMatch(combined)) {
      return const ParsedField<String>(
        value: ReceiptCategories.healthcare,
        confidence: 0.86,
      );
    }

    if (RegExp(
      r'\b(orange|sfr|bouygues|free\s+mobile|edf|engie|veolia|la\s+poste|chronopost|ups|dhl|fedex)\b',
    ).hasMatch(combined)) {
      return const ParsedField<String>(
        value: ReceiptCategories.utilitiesAndTelecom,
        confidence: 0.84,
      );
    }

    return const ParsedField<String>(
      value: ReceiptCategories.other,
      confidence: 0.50,
    );
  }
}

class _IndexedLine {
  const _IndexedLine({required this.index, required this.text});
  final int index;
  final String text;
}

class _LineAmountMatch {
  const _LineAmountMatch({
    required this.minorUnits,
    required this.hasExplicitCurrency,
    required this.rawMatch,
    required this.startOffset,
  });

  final int minorUnits;
  final bool hasExplicitCurrency;
  final String rawMatch;
  final int startOffset;
}

class _AmountCandidate {
  const _AmountCandidate({
    required this.minorUnits,
    required this.confidence,
    required this.tier,
    required this.rawMatch,
    required this.lineIndex,
  });

  final int minorUnits;
  final double confidence;
  final int tier;
  final String rawMatch;
  final int lineIndex;
}

class _DateCandidate {
  const _DateCandidate({
    required this.date,
    required this.confidence,
    required this.rawMatch,
    required this.lineIndex,
    required this.isAmbiguous,
  });

  final DateTime date;
  final double confidence;
  final String rawMatch;
  final int lineIndex;
  final bool isAmbiguous;
}

class _MerchantCandidate {
  const _MerchantCandidate({
    required this.name,
    required this.confidence,
    required this.rawMatch,
    required this.lineIndex,
  });

  final String name;
  final double confidence;
  final String rawMatch;
  final int lineIndex;
}
