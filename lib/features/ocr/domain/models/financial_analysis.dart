import 'package:meta/meta.dart';

/// Configurable confidence thresholds (defaults: high ≥ 0.95, medium ≥ 0.75).
///
/// These defaults follow the product specification and must be re-calibrated
/// against real evaluation data; they are intentionally not hardcoded elsewhere.
@immutable
class ConfidenceThresholds {
  const ConfidenceThresholds({this.high = 0.95, this.medium = 0.75})
    : assert(high >= medium);

  final double high;
  final double medium;

  static const ConfidenceThresholds standard = ConfidenceThresholds();

  ConfidenceLevel levelOf(double confidence, {bool isPresent = true}) {
    if (!isPresent) return ConfidenceLevel.missing;
    if (confidence >= high) return ConfidenceLevel.high;
    if (confidence >= medium) return ConfidenceLevel.medium;
    return ConfidenceLevel.low;
  }
}

enum ConfidenceLevel { high, medium, low, missing }

enum FinancialDocumentType {
  invoice,
  receipt,
  quote,
  creditNote,
  unknown;

  String get jsonName => switch (this) {
    FinancialDocumentType.invoice => 'invoice',
    FinancialDocumentType.receipt => 'receipt',
    FinancialDocumentType.quote => 'quote',
    FinancialDocumentType.creditNote => 'credit_note',
    FinancialDocumentType.unknown => 'unknown',
  };
}

/// Whether a value was read from the document or derived from other values.
enum ValueSource { recognized, inferred }

/// A single extracted value with provenance and confidence.
@immutable
class ExtractedValue<T> {
  const ExtractedValue({
    required this.value,
    required this.confidence,
    this.source = ValueSource.recognized,
    this.rawMatch,
  });

  const ExtractedValue.missing()
    : value = null,
      confidence = 0.0,
      source = ValueSource.recognized,
      rawMatch = null;

  final T? value;
  final double confidence;
  final ValueSource source;
  final String? rawMatch;

  bool get isPresent => value != null;
  bool get isInferred => source == ValueSource.inferred;

  ConfidenceLevel level([
    ConfidenceThresholds thresholds = ConfidenceThresholds.standard,
  ]) => thresholds.levelOf(confidence, isPresent: isPresent);
}

enum IssueSeverity { info, warning, error }

/// A financial validation or extraction problem detected by the validator.
@immutable
class ValidationIssue {
  const ValidationIssue({
    required this.code,
    required this.severity,
    required this.fields,
    required this.messageFr,
    required this.messageEn,
  });

  final String code;
  final IssueSeverity severity;
  final List<String> fields;
  final String messageFr;
  final String messageEn;

  String message({required bool isFrench}) => isFrench ? messageFr : messageEn;

  String localizedMessage(String? langCode) {
    final lower = (langCode ?? 'en').toLowerCase();
    if (lower.startsWith('fr')) return messageFr;
    if (lower.startsWith('es')) {
      return switch (code) {
        'ht_vat_ttc_mismatch' =>
          'Descuadre contable: Base imponible + IVA ≠ Total.',
        'line_items_mismatch' =>
          'La suma de las líneas difiere del total del documento.',
        'negative_or_zero_total' =>
          'El importe total debe ser estrictamente positivo.',
        'missing_essential_fields' =>
          'Campos obligatorios ausentes (importe o fecha).',
        'future_date' => 'La fecha de la factura está en el futuro.',
        'tax_rate_inconsistent' =>
          'El tipo de IVA no coincide con los importes calculados.',
        _ => messageEn,
      };
    }
    if (lower.startsWith('de')) {
      return switch (code) {
        'ht_vat_ttc_mismatch' =>
          'Rechenabweichung: Netto + MwSt ≠ Gesamtbetrag.',
        'line_items_mismatch' =>
          'Summe der Einzelposten weicht vom Gesamtbetrag ab.',
        'negative_or_zero_total' =>
          'Der Gesamtbetrag muss positiv sein.',
        'missing_essential_fields' =>
          'Erforderliche Belegdaten fehlen (Betrag oder Datum).',
        'future_date' => 'Belegdatum liegt in der Zukunft.',
        'tax_rate_inconsistent' =>
          'MwSt-Satz stimmt nicht mit den Beträgen überein.',
        _ => messageEn,
      };
    }
    if (lower.startsWith('it')) {
      return switch (code) {
        'ht_vat_ttc_mismatch' =>
          'Discrepanza contabile: Imponibile + IVA ≠ Totale.',
        'line_items_mismatch' =>
          'La somma delle voci differisce dal totale del documento.',
        'negative_or_zero_total' =>
          'L\'importo totale deve essere maggiore di zero.',
        'missing_essential_fields' =>
          'Campi obbligatori mancanti (importo o data).',
        'future_date' => 'La data dello scontrino è nel futuro.',
        'tax_rate_inconsistent' =>
          'L\'aliquota IVA non corrisponde agli importi.',
        _ => messageEn,
      };
    }
    if (lower.startsWith('pt')) {
      return switch (code) {
        'ht_vat_ttc_mismatch' =>
          'Discrepância contábil: Subtotal + IVA ≠ Total.',
        'line_items_mismatch' =>
          'A soma dos itens difere do total do documento.',
        'negative_or_zero_total' =>
          'O valor total deve ser estritamente positivo.',
        'missing_essential_fields' =>
          'Campos obrigatórios ausentes (valor ou data).',
        'future_date' => 'A data do recibo está no futuro.',
        'tax_rate_inconsistent' =>
          'A taxa de IVA não coincide com os valores.',
        _ => messageEn,
      };
    }
    if (lower.startsWith('ar')) {
      return switch (code) {
        'ht_vat_ttc_mismatch' =>
          'عدم تطابق حسابي: المجموع + الضريبة لا يساوي الإجمالي.',
        'line_items_mismatch' =>
          'مجموع البنود يختلف عن الإجمالي المسجل في المستند.',
        'negative_or_zero_total' =>
          'يجب أن يكون المبلغ الإجمالي أكبر من صفر.',
        'missing_essential_fields' =>
          'بيانات أساسية مفقودة (المبلغ أو التاريخ).',
        'future_date' => 'تاريخ الفاتورة يقع في المستقبل.',
        'tax_rate_inconsistent' =>
          'نسبة الضريبة غير متطابقة مع المبالغ المحسوبة.',
        _ => messageEn,
      };
    }
    return messageEn;
  }
}

/// One extracted line item. Any field may be `null` when not on the document.
@immutable
class ExtractedLineItem {
  const ExtractedLineItem({
    required this.description,
    this.quantity,
    this.unitPriceMinor,
    this.vatRate,
    this.totalMinor,
    this.inferredFields = const <String>[],
    this.rawLine,
  });

  final String description;
  final double? quantity;
  final int? unitPriceMinor;
  final double? vatRate;
  final int? totalMinor;

  /// Names of fields derived rather than read (e.g. `unit_price`).
  final List<String> inferredFields;
  final String? rawLine;
}

/// Complete financial interpretation of a document (on top of OCR text).
@immutable
class FinancialAnalysis {
  const FinancialAnalysis({
    required this.documentType,
    required this.supplierName,
    required this.supplierVatNumber,
    required this.supplierSiren,
    required this.supplierSiret,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.dueDate,
    required this.currencyCode,
    required this.items,
    required this.subtotalHtMinor,
    required this.discountMinor,
    required this.vatAmountMinor,
    required this.vatRates,
    required this.totalTtcMinor,
    required this.amountPaidMinor,
    required this.remainingMinor,
    required this.paymentMethod,
    required this.issues,
    required this.rawText,
    this.thresholds = ConfidenceThresholds.standard,
  });

  final ExtractedValue<FinancialDocumentType> documentType;
  final ExtractedValue<String> supplierName;
  final ExtractedValue<String> supplierVatNumber;
  final ExtractedValue<String> supplierSiren;
  final ExtractedValue<String> supplierSiret;
  final ExtractedValue<String> invoiceNumber;
  final ExtractedValue<DateTime> invoiceDate;
  final ExtractedValue<DateTime> dueDate;
  final ExtractedValue<String> currencyCode;
  final List<ExtractedLineItem> items;
  final ExtractedValue<int> subtotalHtMinor;
  final ExtractedValue<int> discountMinor;
  final ExtractedValue<int> vatAmountMinor;
  final List<double> vatRates;
  final ExtractedValue<int> totalTtcMinor;
  final ExtractedValue<int> amountPaidMinor;
  final ExtractedValue<int> remainingMinor;
  final ExtractedValue<String> paymentMethod;
  final List<ValidationIssue> issues;
  final String rawText;
  final ConfidenceThresholds thresholds;

  bool get hasErrors => issues.any((i) => i.severity == IssueSeverity.error);

  bool get hasWarnings => issues.any((i) => i.severity != IssueSeverity.info);

  /// Whether the user must explicitly verify before data is trusted:
  /// any error, or a warning/low confidence touching a critical field.
  bool get needsUserReview {
    if (hasErrors) return true;
    const critical = <String>{'total_ttc', 'invoice_date', 'supplier'};
    for (final issue in issues) {
      if (issue.severity == IssueSeverity.warning &&
          issue.fields.any(critical.contains)) {
        return true;
      }
    }
    final totalLevel = totalTtcMinor.level(thresholds);
    return totalLevel == ConfidenceLevel.low ||
        totalLevel == ConfidenceLevel.missing;
  }

  double _major(int? minor) => (minor ?? 0) / 100.0;

  /// Returns a copy of this analysis carrying [newIssues] (values are never altered).
  FinancialAnalysis withIssues(List<ValidationIssue> newIssues) =>
      FinancialAnalysis(
        documentType: documentType,
        supplierName: supplierName,
        supplierVatNumber: supplierVatNumber,
        supplierSiren: supplierSiren,
        supplierSiret: supplierSiret,
        invoiceNumber: invoiceNumber,
        invoiceDate: invoiceDate,
        dueDate: dueDate,
        currencyCode: currencyCode,
        items: items,
        subtotalHtMinor: subtotalHtMinor,
        discountMinor: discountMinor,
        vatAmountMinor: vatAmountMinor,
        vatRates: vatRates,
        totalTtcMinor: totalTtcMinor,
        amountPaidMinor: amountPaidMinor,
        remainingMinor: remainingMinor,
        paymentMethod: paymentMethod,
        issues: newIssues,
        rawText: rawText,
        thresholds: thresholds,
      );

  /// Strict-schema JSON (snake_case). Missing values are `null`; nothing is invented.
  Map<String, dynamic> toJson() {
    double? m(ExtractedValue<int> v) => v.isPresent ? _major(v.value) : null;
    final inferred = <String>[
      if (supplierSiren.isInferred) 'supplier.siren',
      if (subtotalHtMinor.isInferred) 'financial_summary.subtotal_ht',
      if (vatAmountMinor.isInferred) 'financial_summary.vat_amount',
      if (remainingMinor.isInferred) 'financial_summary.remaining_amount',
      if (currencyCode.isInferred) 'invoice.currency',
    ];
    String? date(ExtractedValue<DateTime> v) =>
        v.isPresent ? v.value!.toIso8601String().substring(0, 10) : null;

    return <String, dynamic>{
      'document_type': documentType.value?.jsonName ?? 'unknown',
      'supplier': <String, dynamic>{
        'name': supplierName.value,
        'address': null,
        'vat_number': supplierVatNumber.value,
        'siren': supplierSiren.value,
        'siret': supplierSiret.value,
      },
      'invoice': <String, dynamic>{
        'invoice_number': invoiceNumber.value,
        'invoice_date': date(invoiceDate),
        'due_date': date(dueDate),
        'currency': currencyCode.value,
      },
      'customer': <String, dynamic>{'name': null, 'address': null},
      'items': items
          .map(
            (i) => <String, dynamic>{
              'description': i.description,
              'quantity': i.quantity,
              'unit_price': i.unitPriceMinor == null
                  ? null
                  : i.unitPriceMinor! / 100.0,
              'vat_rate': i.vatRate,
              'total': i.totalMinor == null ? null : i.totalMinor! / 100.0,
            },
          )
          .toList(),
      'financial_summary': <String, dynamic>{
        'subtotal_ht': m(subtotalHtMinor),
        'discount': m(discountMinor),
        'vat_amount': m(vatAmountMinor),
        'total_ttc': m(totalTtcMinor),
        'amount_paid': m(amountPaidMinor),
        'remaining_amount': m(remainingMinor),
      },
      'payment_method': paymentMethod.value,
      'confidence': <String, dynamic>{
        'supplier': supplierName.confidence,
        'invoice_number': invoiceNumber.confidence,
        'invoice_date': invoiceDate.confidence,
        'total_ttc': totalTtcMinor.confidence,
      },
      'inferred_fields': inferred,
      'warnings': issues
          .where((i) => i.severity != IssueSeverity.info)
          .map((i) => i.code)
          .toList(),
    };
  }
}

/// Minimal strict validation of the extraction JSON before it is persisted.
abstract final class FinancialSchemaValidator {
  /// Returns a list of schema violations (empty when valid).
  static List<String> validate(Map<String, dynamic> json) {
    final errors = <String>[];
    void requireMap(String key) {
      if (json[key] is! Map) errors.add('"$key" must be an object');
    }

    if (json['document_type'] is! String) {
      errors.add('"document_type" must be a string');
    }
    requireMap('supplier');
    requireMap('invoice');
    requireMap('customer');
    requireMap('financial_summary');
    requireMap('confidence');
    if (json['items'] is! List) errors.add('"items" must be an array');
    if (json['warnings'] is! List) errors.add('"warnings" must be an array');

    final summary = json['financial_summary'];
    if (summary is Map) {
      for (final entry in summary.entries) {
        final v = entry.value;
        if (v != null && (v is! num || v.isNaN || v.isInfinite)) {
          errors.add(
            'financial_summary.${entry.key} must be a finite number or null',
          );
        }
      }
    }
    final confidence = json['confidence'];
    if (confidence is Map) {
      for (final entry in confidence.entries) {
        final v = entry.value;
        if (v is! num || v < 0 || v > 1) {
          errors.add('confidence.${entry.key} must be within 0..1');
        }
      }
    }
    final invoice = json['invoice'];
    if (invoice is Map) {
      for (final key in <String>['invoice_date', 'due_date']) {
        final v = invoice[key];
        if (v != null && (v is! String || DateTime.tryParse(v) == null)) {
          errors.add('invoice.$key must be an ISO date or null');
        }
      }
    }
    return errors;
  }
}
