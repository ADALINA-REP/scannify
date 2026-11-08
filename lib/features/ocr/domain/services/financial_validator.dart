import '../models/financial_analysis.dart';

/// Independent financial consistency checks.
///
/// The validator NEVER modifies extracted values and never fabricates figures to
/// force equations to balance. It only reports issues so the UI can ask the user
/// to verify the problematic fields.
class FinancialValidator {
  const FinancialValidator();

  /// Tolerance in minor units for sums that accumulate per-line rounding.
  int _tolerance(FinancialAnalysis a) {
    final n = a.items.length;
    return n < 2 ? 2 : (n > 10 ? 10 : n);
  }

  List<ValidationIssue> validate(
    FinancialAnalysis a, {
    bool ambiguousDate = false,
    bool noTextDetected = false,
    Set<String> currencySymbolsInText = const <String>{},
  }) {
    final issues = <ValidationIssue>[];
    final t = a.thresholds;
    final tol = _tolerance(a);

    if (noTextDetected) {
      issues.add(
        const ValidationIssue(
          code: 'no_text_detected',
          severity: IssueSeverity.error,
          fields: <String>['document'],
          messageFr:
              'Aucun texte détecté : image floue, trop sombre ou mal cadrée. Reprenez la photo ou saisissez les informations manuellement.',
          messageEn:
              'No text detected: the image is blurry, too dark or badly framed. Retake the photo or enter the data manually.',
        ),
      );
      return issues;
    }

    final ttc = a.totalTtcMinor;
    final ht = a.subtotalHtMinor;
    final vat = a.vatAmountMinor;

    // --- Presence / confidence of critical fields --------------------------
    if (!ttc.isPresent) {
      issues.add(
        const ValidationIssue(
          code: 'missing_total',
          severity: IssueSeverity.error,
          fields: <String>['total_ttc'],
          messageFr: 'Montant total introuvable : saisissez-le manuellement.',
          messageEn: 'Total amount not found: please enter it manually.',
        ),
      );
    } else if (ttc.level(t) == ConfidenceLevel.low) {
      issues.add(
        const ValidationIssue(
          code: 'low_confidence_total_ttc',
          severity: IssueSeverity.warning,
          fields: <String>['total_ttc'],
          messageFr: 'Le montant total est incertain : vérifiez-le.',
          messageEn: 'The total amount is uncertain: please verify it.',
        ),
      );
    }

    if (!a.supplierName.isPresent) {
      issues.add(
        const ValidationIssue(
          code: 'missing_supplier',
          severity: IssueSeverity.warning,
          fields: <String>['supplier'],
          messageFr: 'Fournisseur / commerçant non identifié.',
          messageEn: 'Supplier / merchant could not be identified.',
        ),
      );
    } else if (a.supplierName.level(t) == ConfidenceLevel.low) {
      issues.add(
        const ValidationIssue(
          code: 'low_confidence_supplier',
          severity: IssueSeverity.warning,
          fields: <String>['supplier'],
          messageFr: 'Le nom du fournisseur est incertain : vérifiez-le.',
          messageEn: 'The supplier name is uncertain: please verify it.',
        ),
      );
    }

    if (!a.invoiceDate.isPresent) {
      issues.add(
        const ValidationIssue(
          code: 'missing_invoice_date',
          severity: IssueSeverity.warning,
          fields: <String>['invoice_date'],
          messageFr: 'Date du document introuvable.',
          messageEn: 'Document date not found.',
        ),
      );
    } else if (ambiguousDate) {
      issues.add(
        const ValidationIssue(
          code: 'ambiguous_date',
          severity: IssueSeverity.warning,
          fields: <String>['invoice_date'],
          messageFr: 'Date ambiguë (jour/mois) : vérifiez-la.',
          messageEn: 'Ambiguous date (day/month): please verify it.',
        ),
      );
    }

    if (a.dueDate.isPresent &&
        a.invoiceDate.isPresent &&
        a.dueDate.value!.isBefore(a.invoiceDate.value!)) {
      issues.add(
        const ValidationIssue(
          code: 'due_before_invoice_date',
          severity: IssueSeverity.warning,
          fields: <String>['due_date', 'invoice_date'],
          messageFr: "L'échéance est antérieure à la date de la facture.",
          messageEn: 'The due date is earlier than the invoice date.',
        ),
      );
    }

    // --- Arithmetic checks (recognized values only, never inferred) ---------
    final htOk = ht.isPresent && !ht.isInferred;
    final vatOk = vat.isPresent && !vat.isInferred;
    final discount = a.discountMinor.value ?? 0;

    if (ttc.isPresent && htOk && vatOk) {
      final direct = (ht.value! + vat.value! - ttc.value!).abs();
      final withDiscount = (ht.value! - discount + vat.value! - ttc.value!)
          .abs();
      if (direct > tol && withDiscount > tol) {
        issues.add(
          ValidationIssue(
            code: 'totals_mismatch',
            severity: IssueSeverity.error,
            fields: const <String>['subtotal_ht', 'vat_amount', 'total_ttc'],
            messageFr:
                'Incohérence : HT (${_fmt(ht.value!)}) + TVA (${_fmt(vat.value!)}) ≠ TTC (${_fmt(ttc.value!)}). Vérifiez ces montants.',
            messageEn:
                'Mismatch: HT (${_fmt(ht.value!)}) + VAT (${_fmt(vat.value!)}) ≠ TTC (${_fmt(ttc.value!)}). Please check these amounts.',
          ),
        );
      }
    }

    if (ttc.isPresent && htOk && ttc.value! + tol < ht.value! - discount) {
      issues.add(
        const ValidationIssue(
          code: 'ttc_below_ht',
          severity: IssueSeverity.error,
          fields: <String>['subtotal_ht', 'total_ttc'],
          messageFr: 'Le total TTC est inférieur au total HT.',
          messageEn: 'The total including tax is lower than the pre-tax total.',
        ),
      );
    }

    if (htOk && vatOk && a.vatRates.length == 1 && ht.value! > 0) {
      final expected = ht.value! * a.vatRates.first / 100.0;
      final diff = (expected - vat.value!).abs();
      if (diff > tol + ht.value! * 0.002) {
        issues.add(
          ValidationIssue(
            code: 'vat_rate_mismatch',
            severity: IssueSeverity.warning,
            fields: const <String>['vat_amount', 'subtotal_ht'],
            messageFr:
                'La TVA (${_fmt(vat.value!)}) ne correspond pas au taux ${a.vatRates.first.toStringAsFixed(a.vatRates.first % 1 == 0 ? 0 : 1)} % appliqué au HT.',
            messageEn:
                'VAT (${_fmt(vat.value!)}) does not match the ${a.vatRates.first.toStringAsFixed(a.vatRates.first % 1 == 0 ? 0 : 1)}% rate applied to the pre-tax total.',
          ),
        );
      }
    }

    // --- Line items -----------------------------------------------------------
    for (int i = 0; i < a.items.length; i++) {
      final item = a.items[i];
      if (item.quantity != null &&
          item.unitPriceMinor != null &&
          item.totalMinor != null &&
          !item.inferredFields.contains('unit_price')) {
        final expected = (item.quantity! * item.unitPriceMinor!).round();
        if ((expected - item.totalMinor!).abs() > tol) {
          issues.add(
            ValidationIssue(
              code: 'item_total_mismatch',
              severity: IssueSeverity.warning,
              fields: <String>['items[$i]'],
              messageFr:
                  'Ligne « ${item.description} » : quantité × prix unitaire ≠ total de ligne.',
              messageEn:
                  'Line "${item.description}": quantity × unit price ≠ line total.',
            ),
          );
        }
      }
    }

    final itemTotals = a.items
        .where((i) => i.totalMinor != null)
        .map((i) => i.totalMinor!)
        .toList();
    if (itemTotals.length >= 2 && a.items.length == itemTotals.length) {
      final sum = itemTotals.fold<int>(0, (p, e) => p + e);
      final candidates = <int>[
        if (htOk) ht.value!,
        if (htOk) ht.value! + discount,
        if (ttc.isPresent) ttc.value!,
        if (ttc.isPresent) ttc.value! + discount,
      ];
      if (candidates.isNotEmpty &&
          !candidates.any((c) => (c - sum).abs() <= tol)) {
        issues.add(
          ValidationIssue(
            code: 'items_sum_mismatch',
            severity: IssueSeverity.warning,
            fields: const <String>['items', 'subtotal_ht', 'total_ttc'],
            messageFr:
                'La somme des lignes (${_fmt(sum)}) ne correspond pas au sous-total ou au total du document.',
            messageEn:
                'The sum of the line items (${_fmt(sum)}) does not match the document subtotal or total.',
          ),
        );
      }
    }

    // --- Currency --------------------------------------------------------------
    if (currencySymbolsInText.length > 1) {
      issues.add(
        const ValidationIssue(
          code: 'mixed_currency',
          severity: IssueSeverity.warning,
          fields: <String>['currency'],
          messageFr: 'Plusieurs devises détectées : vérifiez la devise.',
          messageEn: 'Several currencies detected: please verify the currency.',
        ),
      );
    }

    // --- Legal identifiers --------------------------------------------------------
    if (a.supplierSiret.isPresent && a.supplierSiret.confidence < 0.7) {
      issues.add(
        const ValidationIssue(
          code: 'invalid_siret',
          severity: IssueSeverity.warning,
          fields: <String>['siret'],
          messageFr: 'Le SIRET lu ne passe pas le contrôle de validité.',
          messageEn: 'The SIRET read fails its checksum.',
        ),
      );
    }
    if (a.supplierSiren.isPresent &&
        !a.supplierSiren.isInferred &&
        a.supplierSiren.confidence < 0.7) {
      issues.add(
        const ValidationIssue(
          code: 'invalid_siren',
          severity: IssueSeverity.warning,
          fields: <String>['siren'],
          messageFr: 'Le SIREN lu ne passe pas le contrôle de validité.',
          messageEn: 'The SIREN read fails its checksum.',
        ),
      );
    }
    if (a.supplierVatNumber.isPresent && a.supplierVatNumber.confidence < 0.7) {
      issues.add(
        const ValidationIssue(
          code: 'invalid_vat_number',
          severity: IssueSeverity.warning,
          fields: <String>['vat_number'],
          messageFr: 'Le n° de TVA lu semble invalide (clé incorrecte).',
          messageEn: 'The VAT number read looks invalid (bad check key).',
        ),
      );
    }

    return issues;
  }

  static String _fmt(int minor) => (minor / 100.0).toStringAsFixed(2);
}
