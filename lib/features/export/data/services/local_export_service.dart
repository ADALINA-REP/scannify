import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/errors/app_exception.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/storage/receipt_image_storage_service.dart';
import '../../../monetization/domain/services/ad_service.dart';
import '../../../receipts/domain/entities/receipt.dart';
import '../../domain/services/export_service.dart';
import 'export_file_dispatcher.dart';

/// Default on-device implementation of [ExportService] producing UTF-8 CSV
/// files and professional FinTech PDF financial reports.
class LocalExportService implements ExportService {
  LocalExportService({
    required RewardedAdService rewardedAdService,
    ReceiptImageStorageService? imageStorageService,
    ExportFileDispatcher? fileDispatcher,
    DateTime Function()? clock,
  }) : _rewardedAdService = rewardedAdService,
       _imageStorageService = imageStorageService,
       _fileDispatcher = fileDispatcher ?? const ExportFileDispatcher(),
       _clock = clock ?? DateTime.now;

  final RewardedAdService _rewardedAdService;
  final ReceiptImageStorageService? _imageStorageService;
  final ExportFileDispatcher _fileDispatcher;
  final DateTime Function() _clock;

  static final DateFormat _isoDateFormatter = DateFormat('yyyy-MM-dd');
  static final DateFormat _displayDateFormatter = DateFormat('dd/MM/yyyy');
  static final DateFormat _timestampFormatter = DateFormat('dd/MM/yyyy HH:mm');

  @override
  Future<GeneratedExportDocument> generateCsv(ExportRequest request) async {
    try {
      final sortedReceipts = List<Receipt>.of(request.receipts)
        ..sort((a, b) => a.date.compareTo(b.date));

      final rows = <List<String>>[
        if (request.isAccountingDossier)
          <String>[
            'Date',
            'InvoiceNumber',
            'Merchant',
            'Category',
            'SubtotalHT',
            'VATAmount',
            'TotalTTC',
          ]
        else
          <String>['Date', 'Merchant', 'Category', 'Amount'],
      ];

      int totalMinorUnits = 0;
      for (final receipt in sortedReceipts) {
        totalMinorUnits += receipt.amountMinorUnits;
        if (request.isAccountingDossier) {
          rows.add(<String>[
            _isoDateFormatter.format(receipt.date),
            _sanitizeSpreadsheetCell(receipt.invoiceNumber ?? ''),
            _sanitizeSpreadsheetCell(receipt.merchantName),
            _sanitizeSpreadsheetCell(receipt.category),
            _formatMajorAmountFixed(receipt.subtotalHtMinorUnits),
            _formatMajorAmountFixed(receipt.effectiveVatMinorUnits),
            _formatMajorAmountFixed(receipt.amountMinorUnits),
          ]);
        } else {
          rows.add(<String>[
            _isoDateFormatter.format(receipt.date),
            _sanitizeSpreadsheetCell(receipt.merchantName),
            _sanitizeSpreadsheetCell(receipt.category),
            _formatMajorAmountFixed(receipt.amountMinorUnits),
          ]);
        }
      }

      final converter = ListToCsvConverter(
        fieldDelimiter: request.csvFieldDelimiter,
        textDelimiter: '"',
        eol: '\r\n',
      );

      // Include UTF-8 BOM (\uFEFF) so Microsoft Excel opens accented characters cleanly.
      final csvContent = '\uFEFF${converter.convert(rows)}';
      final utf8Bytes = Uint8List.fromList(utf8.encode(csvContent));

      return GeneratedExportDocument(
        fileName: _buildFileName(request, ExportFormat.csv),
        bytes: utf8Bytes,
        format: ExportFormat.csv,
        totalMinorUnits: totalMinorUnits,
        receiptCount: sortedReceipts.length,
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'LocalExportService',
        'Failed to generate CSV report.',
        e,
        stackTrace,
      );
      throw StorageException(
        message: 'Failed to generate CSV export file.',
        cause: e,
      );
    }
  }

  @override
  Future<GeneratedExportDocument> generatePdf(ExportRequest request) async {
    try {
      final sortedReceipts = List<Receipt>.of(request.receipts)
        ..sort((a, b) => a.date.compareTo(b.date));

      int totalMinorUnits = 0;
      int totalHtMinorUnits = 0;
      int totalVatMinorUnits = 0;
      final categoryTotals = <String, int>{};
      final categoryCounts = <String, int>{};
      final vatRateBreakdown = <double, (int, int, int)>{};

      for (final receipt in sortedReceipts) {
        final ttc = receipt.amountMinorUnits;
        final vat = receipt.effectiveVatMinorUnits;
        final ht = receipt.subtotalHtMinorUnits;

        totalMinorUnits += ttc;
        totalHtMinorUnits += ht;
        totalVatMinorUnits += vat;

        categoryTotals.update(
          receipt.category,
          (v) => v + ttc,
          ifAbsent: () => ttc,
        );
        categoryCounts.update(
          receipt.category,
          (v) => v + 1,
          ifAbsent: () => 1,
        );

        final rate = receipt.vatRate ??
            (switch (receipt.category) {
              ReceiptCategories.mealsAndDining => 10.0,
              ReceiptCategories.transportAndFuel => 10.0,
              ReceiptCategories.accommodation => 10.0,
              ReceiptCategories.groceries => 5.5,
              _ => 20.0,
            });

        vatRateBreakdown.update(
          rate,
          (tuple) => (tuple.$1 + ht, tuple.$2 + vat, tuple.$3 + ttc),
          ifAbsent: () => (ht, vat, ttc),
        );
      }

      final sortedCategories = categoryTotals.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final generatedAt = _clock();
      final currencyLabel = _pdfSafeCurrencyLabel(request);

      final pdf = pw.Document(
        title: '${request.reportTitle} - ${request.periodLabel}',
        author: 'Scannify Expense Tracker',
        creator: 'Scannify',
      );

      const emeraldPrimary = PdfColor.fromInt(0xFF10B981);
      const darkHeaderBg = PdfColor.fromInt(0xFF0B0D0C);
      const cardBg = PdfColor.fromInt(0xFFF4F7F5);
      const borderGrey = PdfColor.fromInt(0xFFDCE2DE);
      const mutedText = PdfColor.fromInt(0xFF5A655E);
      final isFrenchDoc = request.reportTitle.toLowerCase().contains('dossier') ||
          request.reportTitle.toLowerCase().contains('comptable');

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          header: (pw.Context context) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 20),
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              decoration: const pw.BoxDecoration(
                color: darkHeaderBg,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: <pw.Widget>[
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: <pw.Widget>[
                      pw.Text(
                        'SCANNIFY',
                        style: pw.TextStyle(
                          color: emeraldPrimary,
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        request.isAccountingDossier
                            ? (isFrenchDoc
                                ? 'Dossier Comptable & Fiscal Certifié'
                                : 'Certified Accounting & Tax Report')
                            : (isFrenchDoc
                                ? 'Rapport Financier & Justificatifs'
                                : 'Smart Expense & Receipt Report'),
                        style: const pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: <pw.Widget>[
                      pw.Text(
                        _pdfSafeText(request.reportTitle),
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Period: ${_pdfSafeText(request.periodLabel)}',
                        style: const pw.TextStyle(
                          color: emeraldPrimary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
          footer: (pw.Context context) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(top: 16),
              padding: const pw.EdgeInsets.only(top: 8),
              decoration: const pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide(color: borderGrey)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: <pw.Widget>[
                  pw.Text(
                    'Generated locally by Scannify on ${_timestampFormatter.format(generatedAt)}',
                    style: const pw.TextStyle(color: mutedText, fontSize: 8.5),
                  ),
                  pw.Text(
                    'Page ${context.pageNumber} of ${context.pagesCount}',
                    style: const pw.TextStyle(color: mutedText, fontSize: 8.5),
                  ),
                ],
              ),
            );
          },
          build: (pw.Context context) {
            return <pw.Widget>[
              // Executive Summary Row
              pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: cardBg,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(8),
                  ),
                  border: pw.Border.all(color: borderGrey),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: <pw.Widget>[
                    _buildSummaryMetric(
                      label: isFrenchDoc ? 'TOTAL TTC' : 'TOTAL (INCL. TAX)',
                      value:
                          '${_formatMajorAmountFixed(totalMinorUnits)} $currencyLabel',
                      highlight: true,
                    ),
                    _buildSummaryMetric(
                      label: isFrenchDoc ? 'BASE HT' : 'SUBTOTAL (EXCL. TAX)',
                      value:
                          '${_formatMajorAmountFixed(totalHtMinorUnits)} $currencyLabel',
                    ),
                    _buildSummaryMetric(
                      label: isFrenchDoc ? 'TVA DÉDUCTIBLE' : 'DEDUCTIBLE VAT',
                      value:
                          '+${_formatMajorAmountFixed(totalVatMinorUnits)} $currencyLabel',
                      highlight: true,
                    ),
                    _buildSummaryMetric(
                      label: isFrenchDoc ? 'JUSTIFICATIFS' : 'RECEIPTS',
                      value: '${sortedReceipts.length}',
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Category Breakdown Section
              if (sortedCategories.isNotEmpty) ...<pw.Widget>[
                pw.Text(
                  isFrenchDoc ? 'Ventilation par Catégorie' : 'Category Breakdown',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: darkHeaderBg,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.TableHelper.fromTextArray(
                  border: pw.TableBorder.all(color: borderGrey, width: 0.5),
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 9.5,
                    color: PdfColors.white,
                  ),
                  headerDecoration: const pw.BoxDecoration(color: darkHeaderBg),
                  cellStyle: const pw.TextStyle(fontSize: 9.5),
                  cellAlignments: <int, pw.Alignment>{
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.centerRight,
                    2: pw.Alignment.centerRight,
                    3: pw.Alignment.centerRight,
                  },
                  headers: isFrenchDoc
                      ? <String>[
                          'Catégorie',
                          'Reçus',
                          'Part',
                          'Total ($currencyLabel)',
                        ]
                      : <String>[
                          'Category',
                          'Receipts',
                          'Share',
                          'Total ($currencyLabel)',
                        ],
                  data: sortedCategories.map((entry) {
                    final count = categoryCounts[entry.key] ?? 0;
                    final sharePct = totalMinorUnits > 0
                        ? ((entry.value / totalMinorUnits) * 100.0)
                              .toStringAsFixed(1)
                        : '0.0';
                    return <String>[
                      _pdfSafeText(entry.key),
                      '$count',
                      '$sharePct%',
                      '${_formatMajorAmountFixed(entry.value)} $currencyLabel',
                    ];
                  }).toList(),
                ),
                pw.SizedBox(height: 20),
              ],

              // VAT Breakdown Section (Fiscalité & Déclaration de TVA)
              if (vatRateBreakdown.isNotEmpty) ...<pw.Widget>[
                pw.Text(
                  isFrenchDoc
                      ? 'Ventilation Fiscale & TVA Déductible'
                      : 'Tax & Deductible VAT Breakdown',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: darkHeaderBg,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.TableHelper.fromTextArray(
                  border: pw.TableBorder.all(color: borderGrey, width: 0.5),
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 9.5,
                    color: PdfColors.white,
                  ),
                  headerDecoration: const pw.BoxDecoration(color: darkHeaderBg),
                  cellStyle: const pw.TextStyle(fontSize: 9.5),
                  cellAlignments: <int, pw.Alignment>{
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.centerRight,
                    2: pw.Alignment.centerRight,
                    3: pw.Alignment.centerRight,
                  },
                  headers: isFrenchDoc
                      ? <String>[
                          'Taux TVA',
                          'Base HT ($currencyLabel)',
                          'TVA Déductible ($currencyLabel)',
                          'Total TTC ($currencyLabel)',
                        ]
                      : <String>[
                          'VAT Rate',
                          'Base Excl. Tax ($currencyLabel)',
                          'Deductible VAT ($currencyLabel)',
                          'Total Incl. Tax ($currencyLabel)',
                        ],
                  data: (vatRateBreakdown.entries.toList()
                        ..sort((a, b) => b.key.compareTo(a.key)))
                      .map((entry) {
                    final (ht, vat, ttc) = entry.value;
                    return <String>[
                      '${entry.key.toStringAsFixed(1)}%',
                      _formatMajorAmountFixed(ht),
                      '+${_formatMajorAmountFixed(vat)}',
                      _formatMajorAmountFixed(ttc),
                    ];
                  }).toList(),
                ),
                pw.SizedBox(height: 20),
              ],

              // Detailed Receipts Table
              pw.Text(
                isFrenchDoc
                    ? 'Livre-Journal des Dépenses (Détail des Écritures)'
                    : 'Expense & Accounting Ledger (Itemized Records)',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: darkHeaderBg,
                ),
              ),
              pw.SizedBox(height: 8),
              if (sortedReceipts.isEmpty)
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    isFrenchDoc
                        ? 'Aucun reçu enregistré pour la période sélectionnée.'
                        : 'No receipts recorded for the selected period.',
                    style: const pw.TextStyle(color: mutedText, fontSize: 10),
                  ),
                )
              else
                pw.TableHelper.fromTextArray(
                  border: pw.TableBorder.all(color: borderGrey, width: 0.5),
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 9,
                    color: PdfColors.white,
                  ),
                  headerDecoration: const pw.BoxDecoration(color: darkHeaderBg),
                  cellStyle: const pw.TextStyle(fontSize: 8.5),
                  cellAlignments: <int, pw.Alignment>{
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.centerLeft,
                    2: pw.Alignment.centerLeft,
                    3: pw.Alignment.centerLeft,
                    4: pw.Alignment.centerRight,
                    5: pw.Alignment.centerRight,
                    6: pw.Alignment.centerRight,
                  },
                  headers: isFrenchDoc
                      ? <String>[
                          'Date',
                          'N° Pièce',
                          'Fournisseur',
                          'Catégorie',
                          'HT',
                          'TVA',
                          'TTC',
                        ]
                      : <String>[
                          'Date',
                          'Item #',
                          'Merchant',
                          'Category',
                          'Excl. Tax',
                          'VAT',
                          'Total',
                        ],
                  data: sortedReceipts.asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final r = entry.value;
                    return <String>[
                      _displayDateFormatter.format(r.date),
                      '#$idx${r.invoiceNumber != null && r.invoiceNumber!.isNotEmpty ? " (${r.invoiceNumber})" : ""}',
                      _pdfSafeText(r.merchantName),
                      _pdfSafeText(r.category),
                      _formatMajorAmountFixed(r.subtotalHtMinorUnits),
                      '+${_formatMajorAmountFixed(r.effectiveVatMinorUnits)}',
                      _formatMajorAmountFixed(r.amountMinorUnits),
                    ];
                  }).toList(),
                ),
            ];
          },
        ),
      );

      // ANNEXE : Pièces Justificatives (Receipt Photos)
      if (request.includeReceiptImages && _imageStorageService != null) {
        int pieceNum = 0;
        for (final r in sortedReceipts) {
          pieceNum++;
          if (r.imagePath == null || r.imagePath!.trim().isEmpty) continue;

          try {
            final imageBytes =
                await _imageStorageService.readReceiptImageBytes(r.imagePath!);
            if (imageBytes != null && imageBytes.isNotEmpty) {
              pdf.addPage(
                pw.Page(
                  pageFormat: PdfPageFormat.a4,
                  margin: const pw.EdgeInsets.all(36),
                  build: (pw.Context context) {
                    return pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: <pw.Widget>[
                        // Top Header Bar
                        pw.Container(
                          margin: const pw.EdgeInsets.only(bottom: 16),
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: const pw.BoxDecoration(
                            color: darkHeaderBg,
                            borderRadius: pw.BorderRadius.all(
                              pw.Radius.circular(6),
                            ),
                          ),
                          child: pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: <pw.Widget>[
                              pw.Text(
                                isFrenchDoc
                                    ? 'PIÈCE JUSTIFICATIVE #$pieceNum'
                                    : 'RECEIPT PROOF #$pieceNum',
                                style: pw.TextStyle(
                                  color: emeraldPrimary,
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              pw.Text(
                                '${_displayDateFormatter.format(r.date)} • ${_formatMajorAmountFixed(r.amountMinorUnits)} $currencyLabel',
                                style: const pw.TextStyle(
                                  color: PdfColors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Subtitle Strip
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: pw.BoxDecoration(
                            color: cardBg,
                            borderRadius: const pw.BorderRadius.all(
                              pw.Radius.circular(6),
                            ),
                            border: pw.Border.all(color: borderGrey),
                          ),
                          child: pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: <pw.Widget>[
                              pw.Text(
                                '${isFrenchDoc ? "Fournisseur" : "Merchant"}: ${_pdfSafeText(r.merchantName)}${r.invoiceNumber != null && r.invoiceNumber!.isNotEmpty ? " • N°: ${_pdfSafeText(r.invoiceNumber!)}" : ""}',
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 9.5,
                                  color: darkHeaderBg,
                                ),
                              ),
                              pw.Text(
                                '${isFrenchDoc ? "TVA Déductible" : "Deductible VAT"}: ${_formatMajorAmountFixed(r.effectiveVatMinorUnits)} $currencyLabel',
                                style: const pw.TextStyle(
                                  color: emeraldPrimary,
                                  fontSize: 9.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        pw.SizedBox(height: 16),

                        // High-Resolution Receipt Image
                        pw.Expanded(
                          child: pw.Center(
                            child: pw.Container(
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(
                                  color: borderGrey,
                                  width: 1,
                                ),
                                borderRadius: const pw.BorderRadius.all(
                                  pw.Radius.circular(6),
                                ),
                              ),
                              child: pw.Image(
                                pw.MemoryImage(imageBytes),
                                fit: pw.BoxFit.contain,
                              ),
                            ),
                          ),
                        ),

                        // Footer Note
                        pw.Container(
                          margin: const pw.EdgeInsets.only(top: 12),
                          alignment: pw.Alignment.centerRight,
                          child: pw.Text(
                            isFrenchDoc
                                ? 'Dossier Comptable Scannify • Pièce #$pieceNum'
                                : 'Scannify Accounting Report • Receipt #$pieceNum',
                            style: const pw.TextStyle(
                              color: mutedText,
                              fontSize: 8,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              );
            }
          } catch (e) {
            AppLogger.warning(
              'LocalExportService',
              'Skipped embedding corrupted image for receipt ${r.id}',
              e,
            );
          }
        }
      }

      final pdfBytes = await pdf.save();
      return GeneratedExportDocument(
        fileName: _buildFileName(request, ExportFormat.pdf),
        bytes: pdfBytes,
        format: ExportFormat.pdf,
        totalMinorUnits: totalMinorUnits,
        receiptCount: sortedReceipts.length,
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'LocalExportService',
        'Failed to generate PDF report.',
        e,
        stackTrace,
      );
      throw StorageException(
        message: 'Failed to generate PDF export file.',
        cause: e,
      );
    }
  }

  @override
  Future<ExportExecutionResult> executeRewardedExport(
    ExportRequest request, {
    bool shareImmediately = true,
  }) async {
    // Gate export generation behind rewarded advertisement confirmation on supported platforms.
    final adResult = await _rewardedAdService.unlockExportWithAd();
    if (!adResult.isRewardGranted) {
      return ExportExecutionResult(
        isSuccess: false,
        adRewardResult: adResult,
        errorMessage:
            adResult.userMessage ??
            'Watch a short video advertisement to unlock your export.',
      );
    }

    try {
      final document = switch (request.format) {
        ExportFormat.csv => await generateCsv(request),
        ExportFormat.pdf => await generatePdf(request),
      };

      if (shareImmediately) {
        await shareOrDownloadDocument(document);
      }

      return ExportExecutionResult(
        isSuccess: true,
        adRewardResult: adResult,
        document: document,
      );
    } catch (e) {
      return ExportExecutionResult(
        isSuccess: false,
        adRewardResult: adResult,
        errorMessage: e is AppException
            ? e.message
            : 'Failed to generate or share export document.',
      );
    }
  }

  @override
  Future<void> shareOrDownloadDocument(GeneratedExportDocument document) {
    return _fileDispatcher.dispatch(document);
  }

  pw.Widget _buildSummaryMetric({
    required String label,
    required String value,
    bool highlight = false,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Text(
          label,
          style: const pw.TextStyle(
            fontSize: 7.5,
            color: PdfColor.fromInt(0xFF5A655E),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: highlight ? 13 : 11,
            fontWeight: pw.FontWeight.bold,
            color: highlight
                ? const PdfColor.fromInt(0xFF10B981)
                : const PdfColor.fromInt(0xFF0B0D0C),
          ),
        ),
      ],
    );
  }

  String _formatMajorAmountFixed(int minorUnits) {
    final isNegative = minorUnits < 0;
    final absUnits = minorUnits.abs();
    final major = absUnits ~/ 100;
    final cents = (absUnits % 100).toString().padLeft(2, '0');
    return '${isNegative ? '-' : ''}$major.$cents';
  }

  String _sanitizeSpreadsheetCell(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';
    // Prevent CSV formula injection in Excel / Google Sheets
    if (trimmed.startsWith('=') ||
        trimmed.startsWith('+') ||
        trimmed.startsWith('-') ||
        trimmed.startsWith('@')) {
      return "'$trimmed";
    }
    return trimmed;
  }

  String _pdfSafeCurrencyLabel(ExportRequest request) {
    if (request.currencyCode.trim().isNotEmpty) {
      return request.currencyCode.trim().toUpperCase();
    }
    if (request.currencySymbol == '€') {
      return 'EUR';
    }
    return _pdfSafeText(request.currencySymbol);
  }

  /// Replaces characters outside WinAnsi / Latin-1 range so standard PDF fonts
  /// never render missing-glyph boxes.
  String _pdfSafeText(String input) {
    return input
        .replaceAll('€', 'EUR')
        .replaceAll('’', "'")
        .replaceAll('‘', "'")
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('–', '-')
        .replaceAll('—', '-');
  }

  String _buildFileName(ExportRequest request, ExportFormat format) {
    final slugPeriod = request.periodLabel
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final datePart = _isoDateFormatter.format(_clock());
    final resolvedPeriod = slugPeriod.isEmpty ? 'report' : slugPeriod;
    return 'scannify_export_${resolvedPeriod}_$datePart.${format.extension}';
  }
}
