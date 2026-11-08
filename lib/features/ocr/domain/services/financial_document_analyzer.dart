import '../models/financial_analysis.dart';
import '../models/parsed_receipt_result.dart';
import 'financial_validator.dart';
import 'receipt_parser.dart';

/// Rule-based financial interpretation layer that runs on top of OCR text.
///
/// 100% on-device and deterministic: no network, no API key, no document content
/// leaves the phone. It identifies the document type, supplier identifiers,
/// invoice number, dates, HT/VAT/TTC figures, discounts, payment method and line
/// items, then hands everything to [FinancialValidator].
///
/// Nothing is invented: absent fields stay `null`, and values derived from other
/// values (e.g. HT = TTC − VAT) are explicitly flagged as inferred.
class FinancialDocumentAnalyzer {
  const FinancialDocumentAnalyzer({
    required ReceiptParser parser,
    FinancialValidator validator = const FinancialValidator(),
    ConfidenceThresholds thresholds = ConfidenceThresholds.standard,
  }) : _parser = parser,
       _validator = validator,
       _thresholds = thresholds;

  final ReceiptParser _parser;
  final FinancialValidator _validator;
  final ConfidenceThresholds _thresholds;

  // -- Patterns ---------------------------------------------------------------

  static final RegExp _creditNoteRegex = RegExp(
    r'\b(?:avoir|credit\s+note|note\s+de\s+cr[eé]dit)\b',
    caseSensitive: false,
  );
  static final RegExp _quoteRegex = RegExp(
    r'\b(?:devis|quotation|quote|estimate|pro\s?forma)\b',
    caseSensitive: false,
  );
  static final RegExp _invoiceRegex = RegExp(
    r'\b(?:facture|invoice)\b',
    caseSensitive: false,
  );
  static final RegExp _receiptRegex = RegExp(
    r'(?:\bre[cç]u\b|\breceipt\b|\bticket\b|carte\s+bancaire|\bcaisse\b|\bcb\b)',
    caseSensitive: false,
  );

  static final RegExp _invoiceNumberRegex = RegExp(
    r'(?:invoice|facture|receipt|re[cç]u|ticket|devis|quote|bon\s+de\s+commande|order|commande|avoir|credit\s+note)\s*(?<marker>n[°ºo]\.?|no\.?|num[eé]ro|number|nr\.?|#)?\s*[:#\-]?\s*(?<id>(?=[A-Z0-9\-/_.]*\d)[A-Z0-9][A-Z0-9\-/_.]{1,})',
    caseSensitive: false,
  );
  static final RegExp _numberFirstRegex = RegExp(
    r'n[°º]\s*(?:de\s+)?(?:facture|commande|ticket|re[cç]u|devis)\s*[:#]?\s*(?<id>(?=[A-Z0-9\-/_.]*\d)[A-Z0-9][A-Z0-9\-/_.]{1,})',
    caseSensitive: false,
  );
  static final RegExp _dateLikeIdRegex = RegExp(
    r'^\d{1,2}[/.\-]\d{1,2}[/.\-]\d{2,4}$',
  );

  static final RegExp _frVatRegex = RegExp(
    r'\bFR\s?(?<key>[0-9A-Z]{2})\s?(?<siren>\d{3}\s?\d{3}\s?\d{3})\b',
    caseSensitive: false,
  );
  static final RegExp _labelledVatRegex = RegExp(
    r'(?:T\.?V\.?A|VAT|TIN)[^A-Z0-9]{0,15}(?<id>[A-Z]{2}\s?[A-Z0-9]{2}\s?[0-9\s]{8,14})',
    caseSensitive: false,
  );
  static final RegExp _siretRegex = RegExp(
    r'SIRET[^0-9]{0,8}(?<d>(?:\d[\s.]?){14})',
    caseSensitive: false,
  );
  static final RegExp _sirenRegex = RegExp(
    r'(?:SIREN|RCS\s+[A-Za-zÀ-ÿ\-]+)[^0-9]{0,8}(?<d>\d{3}[\s.]?\d{3}[\s.]?\d{3})\b',
    caseSensitive: false,
  );

  static final RegExp _htLabelRegex = RegExp(
    r'(?:TOTAL\s+H\.?\s?T\.?|MONTANT\s+H\.?\s?T\.?|NET\s+H\.?\s?T\.?|SOUS[\s-]?TOTAL\s+H\.?\s?T\.?|TOTAL\s+EXCL|TOTAL\s+HORS|HORS\s+TAXES?|TOTAL\s+BEFORE\s+TAX|PRE[\s-]?TAX)',
    caseSensitive: false,
  );
  static final RegExp _englishSubtotalRegex = RegExp(
    r'\bSUB[\s-]?TOTAL\b',
    caseSensitive: false,
  );
  static final RegExp _vatTotalLabelRegex = RegExp(
    r'(?:TOTAL\s+T\.?V\.?A\.?|MONTANT\s+(?:DE\s+LA\s+)?T\.?V\.?A\.?|TOTAL\s+(?:VAT|TAX)|VAT\s+TOTAL|TAX\s+TOTAL|T\.?V\.?A\.?\s+TOTALE)',
    caseSensitive: false,
  );
  static final RegExp _vatLineRegex = RegExp(
    r'(?:^|\s)(?:DONT\s+)?(?:T\.?V\.?A\.?|VAT|TAX)(?=[\s:(\d%]|$)',
    caseSensitive: false,
  );
  static final RegExp _htOrTtcTokenRegex = RegExp(
    r'\b(?:H\.?T\.?|TTC|T\.T\.C)\b',
    caseSensitive: false,
  );
  static final RegExp _vatNumberLineRegex = RegExp(
    r'(?:N[°º]|NUM[EÉ]RO|NUMBER|INTRA|IDENT|\bFR\s?[0-9A-Z]{2}\s?\d{3})',
    caseSensitive: false,
  );
  static final RegExp _discountRegex = RegExp(
    r'\b(?:REMISE|DISCOUNT|R[EÉ]DUCTION|RABAIS|ESCOMPTE|PROMO)\b',
    caseSensitive: false,
  );
  static final RegExp _paidRegex = RegExp(
    r"(?:ACOMPTE|D[EÉ]J[AÀ]\s+(?:R[EÈ]GL[EÉ]|PAY[EÉ])|AMOUNT\s+PAID|DEPOSIT|PAYMENTS?\s+RECEIVED)",
    caseSensitive: false,
  );
  static final RegExp _remainingRegex = RegExp(
    r'(?:RESTE\s+[AÀ]\s+PAYER|SOLDE\s+D[UÛ]|BALANCE\s+DUE|REMAINING|SOLDE\s+RESTANT)',
    caseSensitive: false,
  );
  static final RegExp _ratePercentRegex = RegExp(
    r'(?<!\d)(?<rate>\d{1,2}(?:[.,]\d{1,2})?)\s*%',
  );

  static final RegExp _paymentLabelRegex = RegExp(
    r'(?:payment\s+method|mode\s+de\s+(?:paiement|r[eè]glement)|paiement|r[eè]glement|pay[eé]\s+par|paid\s+(?:by|with))',
    caseSensitive: false,
  );
  static final RegExp _loyaltyRegex = RegExp(
    r'(?:FID[EÉ]LIT[EÉ]|LOYALTY|POINTS)',
    caseSensitive: false,
  );

  static final RegExp _itemHeaderNameRegex = RegExp(
    r'(?:description|d[eé]signation|article|item|service|produit|prestation)',
    caseSensitive: false,
  );
  static final RegExp _itemHeaderNumRegex = RegExp(
    r'(?:qt[eé]|qty|quantit|prix|price|total|montant|amount)',
    caseSensitive: false,
  );
  static final RegExp _itemStopRegex = RegExp(
    r'^(?:SOUS[\s-]?TOTAL|SUB[\s-]?TOTAL|TOTAL|NET\s+[AÀ]\s+PAYER|MONTANT|T\.?V\.?A|VAT|TAX|DONT|REMISE|DISCOUNT|PAYMENT|PAIEMENT|ESP[EÈ]CES|CB|CARTE|RENDU|AMOUNT|BALANCE|MERCI|THANK|NOTE)(?![A-Za-zÀ-ÿ])',
    caseSensitive: false,
  );
  static final RegExp _itemSkipRegex = RegExp(
    r'^(?:(?:DATE|INVOICE|FACTURE|BILLED|BILL\s+TO|FROM|DUE|T[EÉ]L|EMAIL|SIRET|SIREN|RCS|WWW|PAYMENT|CLIENT|CUSTOMER)(?![A-Za-zÀ-ÿ])|N[°º])|@|www\.',
    caseSensitive: false,
  );
  static final RegExp _numericTokenRegex = RegExp(r'^[$€£¥]?\d[\d.,]*[$€£¥]?$');
  static final RegExp _currencyOnlyTokenRegex = RegExp(
    r'^(?:[$€£¥]|EUR|USD|GBP|CHF)$',
    caseSensitive: false,
  );

  // -- Public API ---------------------------------------------------------------

  /// Analyses [rawText]. When [parsed] is omitted it is computed with the same parser.
  FinancialAnalysis analyze(String rawText, {ParsedReceiptResult? parsed}) {
    final text = rawText.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final result = parsed ?? _parser.parse(text);
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      return _build(
        text,
        documentType: const ExtractedValue.missing(),
        supplier: const ExtractedValue.missing(),
        result: result,
        noText: true,
      );
    }

    final docType = _documentType(lines, text);
    final supplier = result.merchantName.isPresent
        ? ExtractedValue<String>(
            value: result.merchantName.value,
            confidence: result.merchantName.confidence,
            rawMatch: result.merchantName.rawMatch,
          )
        : const ExtractedValue<String>.missing();

    return _build(
      text,
      documentType: docType,
      supplier: supplier,
      result: result,
      lines: lines,
    );
  }

  // -- Assembly -----------------------------------------------------------------

  FinancialAnalysis _build(
    String text, {
    required ExtractedValue<FinancialDocumentType> documentType,
    required ExtractedValue<String> supplier,
    required ParsedReceiptResult result,
    List<String> lines = const <String>[],
    bool noText = false,
  }) {
    final ids = _extractIdentifiers(lines);
    final invoiceNumber = _invoiceNumber(lines);

    final invoiceDate = result.date.isPresent
        ? ExtractedValue<DateTime>(
            value: result.date.value,
            confidence: result.date.confidence,
            rawMatch: result.date.rawMatch,
          )
        : const ExtractedValue<DateTime>.missing();
    final dueParsed = noText ? null : _parser.extractDueDateFromText(text);
    final dueDate = dueParsed != null && dueParsed.isPresent
        ? ExtractedValue<DateTime>(
            value: dueParsed.value,
            confidence: dueParsed.confidence,
            rawMatch: dueParsed.rawMatch,
          )
        : const ExtractedValue<DateTime>.missing();

    final ttc = result.totalAmountMinorUnits.isPresent
        ? ExtractedValue<int>(
            value: result.totalAmountMinorUnits.value,
            confidence: result.totalAmountMinorUnits.confidence,
            rawMatch: result.totalAmountMinorUnits.rawMatch,
          )
        : const ExtractedValue<int>.missing();

    final amounts = _extractAmounts(lines);
    var ht = amounts.subtotalHt;
    var vat = amounts.vat;

    // Derived (never read) values are flagged `inferred` and excluded from checks.
    if (!ht.isPresent &&
        ttc.isPresent &&
        vat.isPresent &&
        ttc.value! >= vat.value!) {
      ht = ExtractedValue<int>(
        value: ttc.value! - vat.value!,
        confidence: 0.70,
        source: ValueSource.inferred,
      );
    } else if (!vat.isPresent &&
        ttc.isPresent &&
        ht.isPresent &&
        ttc.value! >= ht.value!) {
      vat = ExtractedValue<int>(
        value: ttc.value! - ht.value!,
        confidence: 0.70,
        source: ValueSource.inferred,
      );
    }

    var remaining = amounts.remaining;
    if (!remaining.isPresent &&
        amounts.paid.isPresent &&
        ttc.isPresent &&
        ttc.value! >= amounts.paid.value!) {
      remaining = ExtractedValue<int>(
        value: ttc.value! - amounts.paid.value!,
        confidence: 0.70,
        source: ValueSource.inferred,
      );
    }

    final currency = result.detectedCurrencyCode != null
        ? ExtractedValue<String>(
            value: result.detectedCurrencyCode,
            confidence: 0.90,
          )
        : const ExtractedValue<String>.missing();

    final draft = FinancialAnalysis(
      documentType: documentType,
      supplierName: supplier,
      supplierVatNumber: ids.vat,
      supplierSiren: ids.siren,
      supplierSiret: ids.siret,
      invoiceNumber: invoiceNumber,
      invoiceDate: invoiceDate,
      dueDate: dueDate,
      currencyCode: currency,
      items: noText ? const <ExtractedLineItem>[] : _extractItems(lines),
      subtotalHtMinor: ht,
      discountMinor: amounts.discount,
      vatAmountMinor: vat,
      vatRates: amounts.rates,
      totalTtcMinor: ttc,
      amountPaidMinor: amounts.paid,
      remainingMinor: remaining,
      paymentMethod: _paymentMethod(lines),
      issues: const <ValidationIssue>[],
      rawText: text,
      thresholds: _thresholds,
    );

    final symbols = <String>{
      if (text.contains(r'$')) r'$',
      if (text.contains('€')) '€',
      if (text.contains('£')) '£',
    };

    final issues = _validator.validate(
      draft,
      ambiguousDate: result.date.isAmbiguous,
      noTextDetected: noText,
      currencySymbolsInText: symbols,
    );
    return draft.withIssues(issues);
  }

  // -- Document type ------------------------------------------------------------

  ExtractedValue<FinancialDocumentType> _documentType(
    List<String> lines,
    String text,
  ) {
    // Tolerate common OCR confusions on the title (`INVO|CE`, `1NVOICE`).
    final head = lines
        .take(8)
        .join('\n')
        .replaceAll('|', 'I')
        .replaceAll(RegExp(r'\b1NV'), 'INV');
    final whole = text.replaceAll('|', 'I');

    ExtractedValue<FinancialDocumentType> hit(
      FinancialDocumentType type,
      RegExp re,
    ) {
      if (re.hasMatch(head)) {
        return ExtractedValue<FinancialDocumentType>(
          value: type,
          confidence: 0.96,
        );
      }
      if (re.hasMatch(whole)) {
        return ExtractedValue<FinancialDocumentType>(
          value: type,
          confidence: 0.85,
        );
      }
      return const ExtractedValue<FinancialDocumentType>.missing();
    }

    for (final candidate in <(FinancialDocumentType, RegExp)>[
      (FinancialDocumentType.creditNote, _creditNoteRegex),
      (FinancialDocumentType.quote, _quoteRegex),
      (FinancialDocumentType.invoice, _invoiceRegex),
      (FinancialDocumentType.receipt, _receiptRegex),
    ]) {
      final r = hit(candidate.$1, candidate.$2);
      if (r.isPresent) return r;
    }

    final looksLikeTicket = RegExp(
      r'(?:T\.?V\.?A|TOTAL|ESP[EÈ]CES|\bCB\b)',
      caseSensitive: false,
    ).hasMatch(whole);
    return looksLikeTicket
        ? const ExtractedValue<FinancialDocumentType>(
            value: FinancialDocumentType.receipt,
            confidence: 0.55,
            source: ValueSource.inferred,
          )
        : const ExtractedValue<FinancialDocumentType>.missing();
  }

  // -- Identifiers --------------------------------------------------------------

  ExtractedValue<String> _invoiceNumber(List<String> lines) {
    final limit = lines.length < 25 ? lines.length : 25;
    for (int i = 0; i < limit; i++) {
      final line = lines[i].replaceAll('|', 'I');
      for (final m in <RegExpMatch?>[
        _numberFirstRegex.firstMatch(line),
        _invoiceNumberRegex.firstMatch(line),
      ]) {
        if (m == null) continue;
        var id = (m.namedGroup('id') ?? '').replaceAll(RegExp(r'[.,;:]+$'), '');
        if (id.length < 2 || _dateLikeIdRegex.hasMatch(id)) continue;
        final hasMarker = m.groupNames.contains('marker')
            ? (m.namedGroup('marker') != null)
            : true;
        final labelled = hasMarker || line.contains(':') || line.contains('#');
        id = id.trim();
        return ExtractedValue<String>(
          value: id,
          confidence: labelled ? 0.93 : 0.75,
          rawMatch: lines[i],
        );
      }
    }
    return const ExtractedValue<String>.missing();
  }

  ({
    ExtractedValue<String> vat,
    ExtractedValue<String> siren,
    ExtractedValue<String> siret,
  })
  _extractIdentifiers(List<String> lines) {
    ExtractedValue<String> vat = const ExtractedValue<String>.missing();
    ExtractedValue<String> siren = const ExtractedValue<String>.missing();
    ExtractedValue<String> siret = const ExtractedValue<String>.missing();

    for (final line in lines) {
      if (!siret.isPresent) {
        final m = _siretRegex.firstMatch(line);
        if (m != null) {
          final digits = m.namedGroup('d')!.replaceAll(RegExp(r'\D'), '');
          if (digits.length == 14) {
            siret = ExtractedValue<String>(
              value: digits,
              confidence: _luhn(digits) ? 0.97 : 0.60,
              rawMatch: line,
            );
          }
        }
      }
      if (!siren.isPresent) {
        final m = _sirenRegex.firstMatch(line);
        if (m != null) {
          final digits = m.namedGroup('d')!.replaceAll(RegExp(r'\D'), '');
          if (digits.length == 9) {
            siren = ExtractedValue<String>(
              value: digits,
              confidence: _luhn(digits) ? 0.96 : 0.60,
              rawMatch: line,
            );
          }
        }
      }
      if (!vat.isPresent) {
        final fr = _frVatRegex.firstMatch(line);
        if (fr != null) {
          final sirenDigits = fr
              .namedGroup('siren')!
              .replaceAll(RegExp(r'\D'), '');
          final key = fr.namedGroup('key')!;
          final labelled = RegExp(
            r'T\.?V\.?A|VAT',
            caseSensitive: false,
          ).hasMatch(line);
          vat = ExtractedValue<String>(
            value: 'FR$key$sirenDigits',
            confidence: _frenchVatKeyValid(key, sirenDigits)
                ? (labelled ? 0.96 : 0.88)
                : 0.60,
            rawMatch: line,
          );
        } else {
          final m = _labelledVatRegex.firstMatch(line);
          if (m != null) {
            final id = m
                .namedGroup('id')!
                .replaceAll(RegExp(r'\s'), '')
                .toUpperCase();
            if (id.length >= 8 &&
                id.length <= 16 &&
                RegExp(r'\d').hasMatch(id)) {
              vat = ExtractedValue<String>(
                value: id,
                confidence: 0.85,
                rawMatch: line,
              );
            }
          }
        }
      }
    }

    // SIREN derived from a valid SIRET (first 9 digits): useful but not read as such.
    if (!siren.isPresent && siret.isPresent) {
      siren = ExtractedValue<String>(
        value: siret.value!.substring(0, 9),
        confidence: siret.confidence,
        source: ValueSource.inferred,
      );
    }
    if (!siren.isPresent && vat.isPresent && vat.value!.startsWith('FR')) {
      final digits = vat.value!.substring(vat.value!.length - 9);
      if (RegExp(r'^\d{9}$').hasMatch(digits)) {
        siren = ExtractedValue<String>(
          value: digits,
          confidence: vat.confidence,
          source: ValueSource.inferred,
        );
      }
    }
    return (vat: vat, siren: siren, siret: siret);
  }

  static bool _luhn(String digits) {
    int sum = 0;
    final reversed = digits.split('').reversed.toList();
    for (int i = 0; i < reversed.length; i++) {
      var d = int.parse(reversed[i]);
      if (i.isOdd) {
        d *= 2;
        if (d > 9) d -= 9;
      }
      sum += d;
    }
    return sum % 10 == 0;
  }

  static bool _frenchVatKeyValid(String key, String siren) {
    if (!RegExp(r'^\d{2}$').hasMatch(key)) {
      return true; // alphanumeric keys: cannot check
    }
    final expected = (12 + 3 * (int.parse(siren) % 97)) % 97;
    return expected == int.parse(key);
  }

  // -- Amounts ------------------------------------------------------------------

  ({
    ExtractedValue<int> subtotalHt,
    ExtractedValue<int> vat,
    ExtractedValue<int> discount,
    ExtractedValue<int> paid,
    ExtractedValue<int> remaining,
    List<double> rates,
  })
  _extractAmounts(List<String> lines) {
    ExtractedValue<int> ht = const ExtractedValue<int>.missing();
    ExtractedValue<int> vatTotal = const ExtractedValue<int>.missing();
    ExtractedValue<int> paid = const ExtractedValue<int>.missing();
    ExtractedValue<int> remaining = const ExtractedValue<int>.missing();
    final vatPerRate = <int>[];
    final discounts = <int>[];
    final rates = <double>{};

    int? lastAmount(String line, {int? requireExactly, bool total = true}) {
      final amounts = _parser.extractAmountsMinorUnits(
        line,
        isTotalLine: total,
      );
      if (amounts.isEmpty) return null;
      if (requireExactly != null && amounts.length != requireExactly) {
        return null;
      }
      return amounts.last;
    }

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      // Amount may sit on the following line when OCR split label and value.
      int? amountFor(String l, {int? exactly}) {
        final same = lastAmount(l, requireExactly: exactly);
        if (same != null) return same;
        if (i + 1 < lines.length &&
            _parser.extractAmountsMinorUnits(l, isTotalLine: true).isEmpty) {
          final next = lines[i + 1];
          if (!RegExp(r'[A-Za-zÀ-ÿ]{3,}').hasMatch(next)) {
            return lastAmount(next, requireExactly: exactly);
          }
        }
        return null;
      }

      for (final m in _ratePercentRegex.allMatches(line)) {
        if (_vatLineRegex.hasMatch(line) ||
            _vatTotalLabelRegex.hasMatch(line)) {
          final r = double.tryParse(m.namedGroup('rate')!.replaceAll(',', '.'));
          if (r != null && r > 0 && r <= 30) rates.add(r);
        }
      }

      if (_vatTotalLabelRegex.hasMatch(line)) {
        final a = amountFor(line);
        if (a != null) {
          vatTotal = ExtractedValue<int>(
            value: a,
            confidence: 0.93,
            rawMatch: line,
          );
        }
        continue;
      }

      if (_htLabelRegex.hasMatch(line)) {
        final a = amountFor(line);
        if (a != null) {
          ht = ExtractedValue<int>(value: a, confidence: 0.93, rawMatch: line);
        }
        continue;
      }
      if (_englishSubtotalRegex.hasMatch(line) && !ht.isPresent) {
        final a = amountFor(line);
        if (a != null) {
          ht = ExtractedValue<int>(value: a, confidence: 0.80, rawMatch: line);
        }
        continue;
      }

      if (_vatLineRegex.hasMatch(line) &&
          !_htOrTtcTokenRegex.hasMatch(line) &&
          !_vatNumberLineRegex.hasMatch(line)) {
        // Decimals / currency-marked amounts only: a bare integer on a VAT line
        // is far more likely an identifier or a rate than a monetary value.
        final a = lastAmount(line, requireExactly: 1, total: false);
        if (a != null) vatPerRate.add(a);
        continue;
      }

      if (_discountRegex.hasMatch(line)) {
        final a = lastAmount(line, requireExactly: 1);
        if (a != null) discounts.add(a);
        continue;
      }
      if (_remainingRegex.hasMatch(line)) {
        final a = amountFor(line);
        if (a != null) {
          remaining = ExtractedValue<int>(
            value: a,
            confidence: 0.88,
            rawMatch: line,
          );
        }
        continue;
      }
      if (_paidRegex.hasMatch(line)) {
        final a = amountFor(line);
        if (a != null) {
          paid = ExtractedValue<int>(
            value: a,
            confidence: 0.88,
            rawMatch: line,
          );
        }
      }
    }

    ExtractedValue<int> vat = vatTotal;
    if (!vat.isPresent && vatPerRate.isNotEmpty) {
      // A sum of VAT lines that were all READ from the document: still recognized,
      // just with a slightly lower confidence when several lines are combined.
      final sum = vatPerRate.fold<int>(0, (p, e) => p + e);
      vat = ExtractedValue<int>(
        value: sum,
        confidence: vatPerRate.length == 1 ? 0.88 : 0.80,
      );
    }

    final discount = discounts.isEmpty
        ? const ExtractedValue<int>.missing()
        : ExtractedValue<int>(
            value: discounts.fold<int>(0, (p, e) => p + e),
            confidence: 0.85,
          );

    return (
      subtotalHt: ht,
      vat: vat,
      discount: discount,
      paid: paid,
      remaining: remaining,
      rates: (rates.toList()..sort()),
    );
  }

  // -- Payment method -----------------------------------------------------------

  ExtractedValue<String> _paymentMethod(List<String> lines) {
    final kinds = <(String, RegExp)>[
      (
        'bank_transfer',
        RegExp(
          r'\b(?:VIREMENT|BANK\s+TRANSFER|WIRE|IBAN)\b',
          caseSensitive: false,
        ),
      ),
      (
        'cheque',
        RegExp(r'\b(?:CH[EÈ]QUE|CHECK|CHEQUE)\b', caseSensitive: false),
      ),
      (
        'cash',
        RegExp(r'\b(?:ESP[EÈ]CES|CASH|LIQUIDE)\b', caseSensitive: false),
      ),
      ('paypal', RegExp(r'\bPAYPAL\b', caseSensitive: false)),
      (
        'meal_voucher',
        RegExp(
          r'(?:TICKET\s+RESTO|TITRE\s+RESTAURANT|SWILE)',
          caseSensitive: false,
        ),
      ),
      (
        'card',
        RegExp(
          r'\b(?:CB|VISA|MASTERCARD|CARTE\s+BANCAIRE|CARTE|CARD|CONTACTLESS|SANS\s+CONTACT)\b',
          caseSensitive: false,
        ),
      ),
    ];

    ExtractedValue<String>? unlabelled;
    for (final line in lines) {
      if (_loyaltyRegex.hasMatch(line)) continue;
      final labelled = _paymentLabelRegex.hasMatch(line);
      for (final k in kinds) {
        if (k.$2.hasMatch(line)) {
          if (labelled) {
            return ExtractedValue<String>(
              value: k.$1,
              confidence: 0.92,
              rawMatch: line,
            );
          }
          unlabelled ??= ExtractedValue<String>(
            value: k.$1,
            confidence: 0.80,
            rawMatch: line,
          );
        }
      }
    }
    return unlabelled ?? const ExtractedValue<String>.missing();
  }

  // -- Line items ---------------------------------------------------------------

  List<ExtractedLineItem> _extractItems(List<String> lines) {
    int start = 0;
    var hasHeader = false;
    for (int i = 0; i < lines.length; i++) {
      if (_itemHeaderNameRegex.hasMatch(lines[i]) &&
          _itemHeaderNumRegex.hasMatch(lines[i]) &&
          !_parser.extractAmountsMinorUnits(lines[i]).isNotEmpty) {
        start = i + 1;
        hasHeader = true;
        break;
      }
    }

    final items = <ExtractedLineItem>[];
    for (int i = start; i < lines.length; i++) {
      final line = lines[i];
      if (_itemStopRegex.hasMatch(line) && (items.isNotEmpty || hasHeader)) {
        break;
      }
      if (_itemStopRegex.hasMatch(line)) continue;
      if (_itemSkipRegex.hasMatch(line)) continue;
      if (ReceiptParser.dueDateLabelRegex.hasMatch(line)) continue;
      final item = _parseItemLine(line, hasHeader: hasHeader);
      if (item != null) items.add(item);
    }
    return items;
  }

  ExtractedLineItem? _parseItemLine(String line, {required bool hasHeader}) {
    final tokens = line.split(RegExp(r'\s+'));
    final numeric = <String>[];
    double? vatRate;
    int idx = tokens.length;

    while (idx > 0) {
      final tk = tokens[idx - 1];
      if (_currencyOnlyTokenRegex.hasMatch(tk)) {
        idx--;
        continue;
      }
      if (tk.endsWith('%') && tk.length > 1) {
        final r = double.tryParse(
          tk.substring(0, tk.length - 1).replaceAll(',', '.'),
        );
        if (r == null) break;
        vatRate ??= r;
        idx--;
        continue;
      }
      if (_numericTokenRegex.hasMatch(tk)) {
        numeric.insert(0, tk);
        idx--;
        continue;
      }
      break;
    }
    if (numeric.isEmpty) return null;

    var description = tokens.take(idx).join(' ').trim();
    description = description.replaceAll(RegExp(r'[\s:\-–|]+$'), '');
    if (RegExp(r'[A-Za-zÀ-ÿ]').allMatches(description).length < 2) return null;

    double? qty;
    final leading = RegExp(
      r'^(\d{1,3})\s*[xX×]?\s+(.+)$',
    ).firstMatch(description);

    bool hasDecimalOrCurrency(String tk) =>
        RegExp(r'[.,]\d{1,2}[$€£¥]?$').hasMatch(tk) ||
        RegExp(r'[$€£¥]').hasMatch(tk);

    // Without a table header (receipts) require a clearly monetary last token.
    if (!hasHeader && !hasDecimalOrCurrency(numeric.last)) return null;

    int? amount(String tk) => _parser.parseAmountMinorUnits(tk);
    bool isIntLike(String tk) => RegExp(r'^\d{1,4}$').hasMatch(tk);

    int? unit;
    int? total;
    final inferred = <String>[];

    if (numeric.length == 1) {
      total = amount(numeric.first);
      if (leading != null) {
        qty = double.tryParse(leading.group(1)!);
        description = leading.group(2)!.trim();
      }
    } else if (numeric.length == 2) {
      total = amount(numeric[1]);
      if (isIntLike(numeric[0]) && !hasDecimalOrCurrency(numeric[0])) {
        qty = double.tryParse(numeric[0]);
        if (qty != null && qty > 0 && total != null) {
          unit = (total / qty).round();
          inferred.add('unit_price');
        }
      } else {
        unit = amount(numeric[0]);
      }
    } else {
      final n = numeric.length;
      total = amount(numeric[n - 1]);
      unit = amount(numeric[n - 2]);
      qty = double.tryParse(numeric[n - 3].replaceAll(',', '.'));
    }

    if (total == null) return null;
    if (description.length < 2) return null;

    return ExtractedLineItem(
      description: description,
      quantity: qty,
      unitPriceMinor: unit,
      vatRate: vatRate,
      totalMinor: total,
      inferredFields: inferred,
      rawLine: line,
    );
  }
}
