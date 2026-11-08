import 'package:meta/meta.dart';

/// Represents a single field extracted by [ReceiptParser] along with its
/// extraction confidence score (`0.0` to `1.0`) and provenance metadata.
@immutable
class ParsedField<T> {
  const ParsedField({
    required this.value,
    required this.confidence,
    this.rawMatch,
    this.lineIndex,
    this.isAmbiguous = false,
  }) : assert(
         confidence >= 0.0 && confidence <= 1.0,
         'Confidence must be between 0.0 and 1.0',
       );

  const ParsedField.empty()
    : value = null,
      confidence = 0.0,
      rawMatch = null,
      lineIndex = null,
      isAmbiguous = false;

  /// Extracted typed value, or `null` if no candidate could be found.
  final T? value;

  /// Normalized confidence score in the range `[0.0, 1.0]`.
  final double confidence;

  /// Original substring or line matched in the OCR text.
  final String? rawMatch;

  /// Zero-based line index where the match originated.
  final int? lineIndex;

  /// Whether multiple plausible interpretations existed (e.g. ambiguous `DD/MM` vs `MM/DD`).
  final bool isAmbiguous;

  /// Whether a non-null value was extracted.
  bool get isPresent => value != null;

  /// Whether the extracted value has high confidence (`>= 0.80`) and is unambiguous.
  bool get isHighConfidence => isPresent && confidence >= 0.80 && !isAmbiguous;

  /// Whether user attention is strongly advised before saving.
  bool get isUncertain => !isHighConfidence;
}

/// Complete structured output produced by [ReceiptParser] from raw OCR text.
@immutable
class ParsedReceiptResult {
  const ParsedReceiptResult({
    required this.merchantName,
    required this.date,
    required this.totalAmountMinorUnits,
    required this.suggestedCategory,
    required this.rawText,
    this.detectedCurrencyCode,
    this.detectedCurrencySymbol,
  });

  /// Extracted merchant name and its confidence score.
  final ParsedField<String> merchantName;

  /// Extracted receipt transaction date and its confidence score.
  final ParsedField<DateTime> date;

  /// Extracted total amount in integer minor currency units (e.g. cents) and its confidence score.
  final ParsedField<int> totalAmountMinorUnits;

  /// Suggested expense category inferred from merchant/receipt keywords.
  final ParsedField<String> suggestedCategory;

  /// Original raw text analyzed by the parser.
  final String rawText;

  /// Detected ISO currency code (e.g. `USD`, `EUR`, `GBP`), if evident from receipt symbols.
  final String? detectedCurrencyCode;

  /// Detected currency symbol (e.g. `$`, `€`, `£`), if evident from receipt symbols.
  final String? detectedCurrencySymbol;

  /// Extracted total amount in major currency units (e.g. `12.50`), or `null` if not found.
  double? get totalAmount => totalAmountMinorUnits.value != null
      ? totalAmountMinorUnits.value! / 100.0
      : null;

  /// Aggregate confidence score (`0.0` to `1.0`) weighted across core fields
  /// (Total Amount: 45%, Date: 30%, Merchant Name: 25%).
  double get overallConfidence {
    return (totalAmountMinorUnits.confidence * 0.45) +
        (date.confidence * 0.30) +
        (merchantName.confidence * 0.25);
  }

  /// Whether any core field is missing, ambiguous, or below high-confidence threshold.
  ///
  /// Note: Scannify always displays the prefilled validation form to the user
  /// before saving; this property highlights when one or more fields require
  /// explicit user verification.
  bool get hasUncertainFields =>
      merchantName.isUncertain ||
      date.isUncertain ||
      totalAmountMinorUnits.isUncertain;
}
