import 'dart:typed_data';
import 'package:meta/meta.dart';
import '../../../monetization/domain/services/ad_service.dart';
import '../../../receipts/domain/entities/receipt.dart';

/// Supported export file formats.
enum ExportFormat {
  csv(extension: 'csv', mimeType: 'text/csv'),
  pdf(extension: 'pdf', mimeType: 'application/pdf');

  const ExportFormat({required this.extension, required this.mimeType});

  final String extension;
  final String mimeType;
}

/// Parameters defining a financial report export request.
@immutable
class ExportRequest {
  const ExportRequest({
    required this.receipts,
    required this.format,
    required this.periodLabel,
    this.reportTitle = 'Expense Report',
    this.currencySymbol = '€',
    this.currencyCode = 'EUR',
    this.csvFieldDelimiter = ',',
    this.includeReceiptImages = true,
    this.isAccountingDossier = false,
  });

  final List<Receipt> receipts;
  final ExportFormat format;
  final String periodLabel;
  final String reportTitle;
  final String currencySymbol;
  final String currencyCode;
  final String csvFieldDelimiter;
  final bool includeReceiptImages;
  final bool isAccountingDossier;
}

/// In-memory generated export document ready for sharing or download.
@immutable
class GeneratedExportDocument {
  const GeneratedExportDocument({
    required this.fileName,
    required this.bytes,
    required this.format,
    required this.totalMinorUnits,
    required this.receiptCount,
  });

  final String fileName;
  final Uint8List bytes;
  final ExportFormat format;
  final int totalMinorUnits;
  final int receiptCount;

  double get totalAmount => Receipt.minorToMajorUnits(totalMinorUnits);
}

/// Outcome of a full rewarded-ad-gated export and share operation.
@immutable
class ExportExecutionResult {
  const ExportExecutionResult({
    required this.isSuccess,
    required this.adRewardResult,
    this.document,
    this.errorMessage,
  });

  final bool isSuccess;
  final AdRewardResult adRewardResult;
  final GeneratedExportDocument? document;
  final String? errorMessage;
}

/// Abstract service for generating CSV and PDF financial reports and
/// sharing/downloading them across Android, iOS, and Web.
abstract interface class ExportService {
  /// Generates a UTF-8 CSV document from [request].
  Future<GeneratedExportDocument> generateCsv(ExportRequest request);

  /// Generates a branded, multi-page capable PDF financial report from [request].
  Future<GeneratedExportDocument> generatePdf(ExportRequest request);

  /// Enforces the rewarded-advertisement gate via [RewardedAdService] before
  /// generating and sharing/downloading the requested CSV or PDF file.
  ///
  /// The export file is strictly generated ONLY after reward confirmation.
  Future<ExportExecutionResult> executeRewardedExport(
    ExportRequest request, {
    bool shareImmediately = true,
  });

  /// Opens the native share sheet on Android/iOS or triggers a browser download on Web.
  Future<void> shareOrDownloadDocument(GeneratedExportDocument document);
}
