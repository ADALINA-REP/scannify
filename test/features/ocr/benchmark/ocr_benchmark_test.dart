import 'package:flutter_test/flutter_test.dart';
import 'package:scannify/features/ocr/domain/services/financial_document_analyzer.dart';
import 'package:scannify/features/ocr/domain/services/receipt_parser.dart';

import 'ocr_corpus.dart';

/// Measures field-level accuracy of the extraction layers on [ocrCorpus].
///
/// Baseline = `ReceiptParser` alone (merchant / date / total only, which is what
/// the app exposed before the financial analysis layer). New = `ReceiptParser` +
/// `FinancialDocumentAnalyzer`.
void main() {
  final parser = ReceiptParser(referenceClock: DateTime(2026, 11, 6));
  final analyzer = FinancialDocumentAnalyzer(parser: parser);

  test('benchmark: field-level accuracy on the synthetic corpus', () {
    final fields = <String, List<bool>>{};
    final baseline = <String, List<bool>>{};
    final failures = <String>[];
    final timings = <int>[];

    void score(Map<String, List<bool>> bucket, String field, bool ok) =>
        bucket.putIfAbsent(field, () => <bool>[]).add(ok);

    for (final s in ocrCorpus) {
      final sw = Stopwatch()..start();
      final parsed = parser.parse(s.text);
      final a = analyzer.analyze(s.text, parsed: parsed);
      sw.stop();
      timings.add(sw.elapsedMicroseconds);

      void check(
        String field,
        Object? expected,
        Object? actualNew, {
        Object? actualBase,
        bool baselineSupported = false,
      }) {
        final okNew = expected == actualNew;
        score(fields, field, okNew);
        if (baselineSupported) score(baseline, field, expected == actualBase);
        if (!okNew) {
          failures.add(
            '${s.name} → $field: expected <$expected> got <$actualNew>',
          );
        }
      }

      // Merchant / date / total are expected for every sample (null = must stay null).
      check(
        'supplier',
        s.merchant,
        a.supplierName.value,
        actualBase: parsed.merchantName.value,
        baselineSupported: true,
      );
      check(
        'invoice_date',
        s.date,
        a.invoiceDate.value,
        actualBase: parsed.date.value,
        baselineSupported: true,
      );
      check(
        'total_ttc',
        s.totalMinor,
        a.totalTtcMinor.value,
        actualBase: parsed.totalAmountMinorUnits.value,
        baselineSupported: true,
      );
      check('invoice_number', s.invoiceNumber, a.invoiceNumber.value);
      check('due_date', s.dueDate, a.dueDate.value);
      // Derived values (HT = TTC - VAT, ...) are flagged `inferred` and are not
      // counted as "read from the document".
      check(
        'subtotal_ht',
        s.htMinor,
        a.subtotalHtMinor.isInferred ? null : a.subtotalHtMinor.value,
      );
      check(
        'vat_amount',
        s.vatMinor,
        a.vatAmountMinor.isInferred ? null : a.vatAmountMinor.value,
      );
      check('currency', s.currency, a.currencyCode.value);
      check('payment_method', s.payment, a.paymentMethod.value);
      if (s.itemCount != null) {
        check('line_item_count', s.itemCount, a.items.length);
      }
    }

    String pct(List<bool> l) =>
        '${(100 * l.where((e) => e).length / l.length).toStringAsFixed(0)}% (${l.where((e) => e).length}/${l.length})';

    final buf = StringBuffer(
      '\n===== OCR PARSING BENCHMARK (synthetic text corpus, ${ocrCorpus.length} docs) =====\n',
    );
    buf.writeln(
      '${'field'.padRight(18)}${'new'.padRight(14)}baseline (parser only)',
    );
    for (final e in fields.entries) {
      final base = baseline[e.key];
      final col3 = base == null ? 'not extracted' : pct(base);
      buf.writeln('${e.key.padRight(18)}${pct(e.value).padRight(14)}$col3');
    }
    final avgMs = timings.fold<int>(0, (p, e) => p + e) / timings.length / 1000;
    buf.writeln(
      'avg analysis time: ${avgMs.toStringAsFixed(2)} ms/doc (text layers only, excludes OCR + image)',
    );
    if (failures.isNotEmpty) {
      buf.writeln('--- misses ---');
      failures.forEach(buf.writeln);
    }
    // ignore: avoid_print
    print(buf);

    // Regression floor: the three core fields must not regress below these on the corpus.
    double rate(String f) =>
        fields[f]!.where((e) => e).length / fields[f]!.length;
    expect(rate('total_ttc'), greaterThanOrEqualTo(0.99));
    expect(rate('invoice_date'), greaterThanOrEqualTo(0.99));
    expect(rate('supplier'), greaterThanOrEqualTo(0.85));
  });
}
