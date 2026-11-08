import 'package:flutter/material.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../domain/models/financial_analysis.dart';
import '../../domain/models/parsed_receipt_result.dart';

/// Visual summary banner displaying OCR extraction confidence per field,
/// detected document type, and financial validation status.
class OcrResultBanner extends StatelessWidget {
  const OcrResultBanner({
    super.key,
    required this.parsedResult,
    required this.isAutomaticOcrSupported,
    this.strings,
    this.isFrench = false,
    this.analysis,
  });

  final ParsedReceiptResult parsedResult;
  final bool isAutomaticOcrSupported;
  final AppStrings? strings;
  final bool isFrench;
  final FinancialAnalysis? analysis;

  @override
  Widget build(BuildContext context) {
    final colors = context.scannifyColors;
    final textTheme = Theme.of(context).textTheme;
    final s = strings ??
        (isFrench
            ? const AppStrings(AppLanguage.french)
            : AppStrings.of(context));

    if (!isAutomaticOcrSupported) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: colors.secondaryBackground,
          borderRadius: const BorderRadius.all(Radius.circular(AppRadii.md)),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.edit_note_rounded,
              color: colors.primaryEmerald,
              size: 22,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                s.manualEntryActive,
                style: textTheme.bodySmall?.copyWith(color: colors.primaryText),
              ),
            ),
          ],
        ),
      );
    }

    final hasValidationIssues =
        analysis != null &&
        analysis!.issues.any(
          (i) =>
              i.severity == IssueSeverity.error ||
              i.severity == IssueSeverity.warning,
        );

    final hasUncertain = parsedResult.hasUncertainFields || hasValidationIssues;
    final overallPct = (parsedResult.overallConfidence * 100).round();
    final Color statusColor = hasUncertain
        ? colors.warning
        : colors.primaryEmerald;
    final IconData statusIcon = hasUncertain
        ? Icons.info_outline_rounded
        : Icons.verified_rounded;

    final docTypeLabel = _docTypeLabel(analysis?.documentType.value, s);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.10),
        borderRadius: const BorderRadius.all(Radius.circular(AppRadii.md)),
        border: Border.all(color: statusColor.withValues(alpha: 0.40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(statusIcon, color: statusColor, size: 20),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  hasUncertain
                      ? s.verifyExtractedFields(overallPct)
                      : s.ocrExtractionSuccess(overallPct),
                  style: textTheme.titleSmall?.copyWith(
                    color: colors.primaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (docTypeLabel != null) ...<Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primaryEmerald.withValues(alpha: 0.15),
                    borderRadius: AppRadii.chipBorderRadius,
                    border: Border.all(
                      color: colors.primaryEmerald.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    docTypeLabel,
                    style: textTheme.labelSmall?.copyWith(
                      color: colors.primaryEmerald,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              _ConfidencePill(
                label: s.merchantLabel,
                field: parsedResult.merchantName,
              ),
              _ConfidencePill(
                label: s.dateLabel,
                field: parsedResult.date,
              ),
              _ConfidencePill(
                label: s.totalInclTax,
                field: parsedResult.totalAmountMinorUnits,
              ),
              if (analysis?.invoiceNumber.value != null)
                _StaticBadge(
                  label: s.invoiceNumberLabel,
                  value: analysis!.invoiceNumber.value!,
                  isHigh: analysis!.invoiceNumber.confidence >= 0.8,
                ),
              if (analysis?.vatAmountMinor.value != null)
                _StaticBadge(
                  label: s.vatLabel,
                  value:
                      '${(analysis!.vatAmountMinor.value! / 100.0).toStringAsFixed(2)} €',
                  isHigh: true,
                ),
            ],
          ),
          if (parsedResult.date.isAmbiguous) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              s.dateAmbiguousWarning(parsedResult.date.rawMatch ?? ""),
              style: textTheme.bodySmall?.copyWith(color: colors.warning),
            ),
          ],
          if (analysis != null && analysis!.issues.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            for (final issue in analysis!.issues)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      issue.severity == IssueSeverity.error
                          ? Icons.error_outline_rounded
                          : Icons.warning_amber_rounded,
                      size: 14,
                      color: issue.severity == IssueSeverity.error
                          ? colors.error
                          : colors.warning,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        issue.localizedMessage(s.effective.code),
                        style: textTheme.labelSmall?.copyWith(
                          color: issue.severity == IssueSeverity.error
                              ? colors.error
                              : colors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  String? _docTypeLabel(FinancialDocumentType? type, AppStrings s) {
    if (type == null || type == FinancialDocumentType.unknown) return null;
    return s.documentTypeName(type);
  }
}

class _ConfidencePill extends StatelessWidget {
  const _ConfidencePill({required this.label, required this.field});

  final String label;
  final ParsedField<dynamic> field;

  @override
  Widget build(BuildContext context) {
    final colors = context.scannifyColors;
    final textTheme = Theme.of(context).textTheme;
    final pct = (field.confidence * 100).round();
    final isHigh = field.isHighConfidence;

    final Color pillColor = !field.isPresent
        ? colors.error
        : isHigh
        ? colors.primaryEmerald
        : colors.warning;

    final IconData icon = !field.isPresent
        ? Icons.help_outline_rounded
        : isHigh
        ? Icons.check_circle_outline_rounded
        : Icons.warning_amber_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: AppRadii.chipBorderRadius,
        border: Border.all(color: pillColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: pillColor),
          const SizedBox(width: 4),
          Text(
            '$label: ${field.isPresent ? "$pct%" : "—"}',
            style: textTheme.labelSmall?.copyWith(
              color: colors.primaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StaticBadge extends StatelessWidget {
  const _StaticBadge({
    required this.label,
    required this.value,
    required this.isHigh,
  });

  final String label;
  final String value;
  final bool isHigh;

  @override
  Widget build(BuildContext context) {
    final colors = context.scannifyColors;
    final textTheme = Theme.of(context).textTheme;
    final Color color = isHigh ? colors.primaryEmerald : colors.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: AppRadii.chipBorderRadius,
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            isHigh
                ? Icons.check_circle_outline_rounded
                : Icons.warning_amber_rounded,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            '$label: $value',
            style: textTheme.labelSmall?.copyWith(
              color: colors.primaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
