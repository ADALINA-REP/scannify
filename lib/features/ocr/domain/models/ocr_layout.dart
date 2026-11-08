import 'package:meta/meta.dart';

/// A recognized text line with its bounding box in image pixel coordinates.
///
/// Platform independent (no `dart:ui`) so layout reconstruction can be unit tested.
@immutable
class OcrTextLine {
  const OcrTextLine({
    required this.text,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;
  bool get hasGeometry => width > 0 && height > 0;

  /// Vertical overlap with [other] relative to the smaller of both heights (`0..1`).
  double verticalOverlapRatio(OcrTextLine other) {
    final overlap =
        (bottom < other.bottom ? bottom : other.bottom) -
        (top > other.top ? top : other.top);
    if (overlap <= 0) return 0;
    final minHeight = height < other.height ? height : other.height;
    if (minHeight <= 0) return 0;
    return overlap / minHeight;
  }
}

/// Rebuilds reading-order text from OCR lines while keeping table rows aligned.
///
/// ML Kit emits each table column as a separate block, so
/// `Consultation | 1 | $5.00 | $5.00` becomes four unrelated lines. This
/// reconstructor re-attaches numeric cells (quantity, price, total) to the text
/// cell on the same visual row, but deliberately leaves side-by-side TEXT blocks
/// (e.g. `From:` next to `Billed to:`) untouched to preserve block continuity.
class OcrLayoutReconstructor {
  const OcrLayoutReconstructor({this.minRowOverlap = 0.5});

  /// Minimum vertical overlap ratio for two cells to be on the same row.
  final double minRowOverlap;

  static final RegExp _numericCellRegex = RegExp(
    r'^[\s$€£¥]*\d[\d\s.,]*\s*(?:%|[$€£¥]|EUR|USD|GBP|CHF)?\s*$',
    caseSensitive: false,
  );

  static final RegExp _headerWordRegex = RegExp(
    r'^(?:description|d[eé]signation|article|item|service|produit|prestation|qty|qt[eé]|quantit[eé]|quantity|prix|price|unit\s*price|p\.?u\.?|total|montant|amount|tva|vat|ht|ttc|rate|taux)s?$',
    caseSensitive: false,
  );

  /// Whether [text] is a purely numeric / amount cell (`1`, `$5.00`, `12,50 €`, `20 %`).
  static bool isNumericCell(String text) => _numericCellRegex.hasMatch(text);

  /// Returns reconstructed text, one logical row per line.
  String reconstruct(List<OcrTextLine> lines) {
    final cleaned = lines.where((l) => l.text.trim().isNotEmpty).toList();
    if (cleaned.isEmpty) return '';
    if (cleaned.any((l) => !l.hasGeometry)) {
      return cleaned.map((l) => l.text.trim()).join('\n');
    }

    final consumed = <int>{};
    final attached = <int, List<int>>{};

    // 1. Merge header-vocabulary clusters (`SERVICE  QTY  PRICE  TOTAL`).
    final headerGroups = _findHeaderGroups(cleaned);
    final headerLead = <int, List<int>>{};
    for (final group in headerGroups) {
      group.sort((a, b) => cleaned[a].left.compareTo(cleaned[b].left));
      headerLead[group.first] = group.skip(1).toList();
      consumed.addAll(group.skip(1));
    }

    // 2. Attach numeric cells to the nearest text cell on their left.
    for (int i = 0; i < cleaned.length; i++) {
      if (consumed.contains(i)) continue;
      final cell = cleaned[i];
      if (!isNumericCell(cell.text.trim())) continue;

      int? partner;
      double bestRight = double.negativeInfinity;
      for (int j = 0; j < cleaned.length; j++) {
        if (j == i || consumed.contains(j)) continue;
        final candidate = cleaned[j];
        if (isNumericCell(candidate.text.trim())) continue;
        if (headerLead.containsKey(j) ||
            headerGroups.any((g) => g.contains(j))) {
          continue;
        }
        if (candidate.verticalOverlapRatio(cell) < minRowOverlap) continue;
        if (candidate.right > cell.left + candidate.height * 0.5) continue;
        if (candidate.right > bestRight) {
          bestRight = candidate.right;
          partner = j;
        }
      }
      if (partner != null) {
        attached.putIfAbsent(partner, () => <int>[]).add(i);
        consumed.add(i);
      }
    }

    // 3. Emit in the original (ML Kit block) order.
    final out = <String>[];
    for (int i = 0; i < cleaned.length; i++) {
      if (consumed.contains(i)) continue;
      final parts = <OcrTextLine>[cleaned[i]];
      for (final extra in headerLead[i] ?? const <int>[]) {
        parts.add(cleaned[extra]);
      }
      for (final extra in attached[i] ?? const <int>[]) {
        parts.add(cleaned[extra]);
      }
      parts.sort((a, b) => a.left.compareTo(b.left));
      out.add(parts.map((p) => p.text.trim()).join(' '));
    }
    return out.join('\n');
  }

  List<List<int>> _findHeaderGroups(List<OcrTextLine> lines) {
    final groups = <List<int>>[];
    final used = <int>{};
    for (int i = 0; i < lines.length; i++) {
      if (used.contains(i)) continue;
      if (!_headerWordRegex.hasMatch(lines[i].text.trim())) continue;
      final group = <int>[i];
      for (int j = 0; j < lines.length; j++) {
        if (j == i || used.contains(j)) continue;
        if (!_headerWordRegex.hasMatch(lines[j].text.trim())) continue;
        if (lines[i].verticalOverlapRatio(lines[j]) >= minRowOverlap) {
          group.add(j);
        }
      }
      if (group.length >= 3) {
        used.addAll(group);
        groups.add(group);
      }
    }
    return groups;
  }
}
