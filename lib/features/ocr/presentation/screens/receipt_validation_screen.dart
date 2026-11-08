import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/settings/app_preferences.dart';
import '../../../receipts/domain/entities/receipt.dart';
import '../../data/services/image_acquisition_service.dart';
import '../../domain/models/financial_analysis.dart';
import '../../domain/services/ocr_service.dart';
import '../widgets/ocr_result_banner.dart';

/// OCR Validation and Receipt Editor screen (Section 9C).
///
/// Displays a prefilled form with extracted OCR fields (Merchant, Date,
/// Amount, Category, and Receipt Image Preview), allowing manual corrections
/// and explicit user confirmation before persisting locally.
class ReceiptValidationScreen extends ConsumerStatefulWidget {
  const ReceiptValidationScreen({
    super.key,
    this.ocrScanResult,
    this.acquiredImage,
    this.existingReceipt,
  });

  final OcrScanResult? ocrScanResult;
  final AcquiredReceiptImage? acquiredImage;
  final Receipt? existingReceipt;

  @override
  ConsumerState<ReceiptValidationScreen> createState() =>
      _ReceiptValidationScreenState();
}

class _ReceiptValidationScreenState
    extends ConsumerState<ReceiptValidationScreen> {
  static const Uuid _uuid = Uuid();
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _merchantController;
  late final TextEditingController _amountController;
  late final TextEditingController _vatController;
  late final TextEditingController _invoiceNumberController;

  late DateTime _selectedDate;
  late String _selectedCategory;
  Uint8List? _previewBytes;
  bool _isSaving = false;

  bool get _isEditingExisting => widget.existingReceipt != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingReceipt;
    final parsed = widget.ocrScanResult?.parsedReceipt;

    final initialMerchant =
        existing?.merchantName ?? parsed?.merchantName.value ?? '';

    final int? initialMinorUnits =
        existing?.amountMinorUnits ?? parsed?.totalAmountMinorUnits.value;
    final initialAmountText = initialMinorUnits != null && initialMinorUnits > 0
        ? (initialMinorUnits / 100.0).toStringAsFixed(2)
        : '';

    final analysis = widget.ocrScanResult?.analysis;

    final int? initialVatMinor =
        existing?.vatAmountMinorUnits ?? analysis?.vatAmountMinor.value;
    final initialVatText = initialVatMinor != null && initialVatMinor > 0
        ? (initialVatMinor / 100.0).toStringAsFixed(2)
        : '';
    final initialInvoice =
        existing?.invoiceNumber ?? analysis?.invoiceNumber.value ?? '';

    _merchantController = TextEditingController(text: initialMerchant);
    _amountController = TextEditingController(text: initialAmountText);
    _vatController = TextEditingController(text: initialVatText);
    _invoiceNumberController = TextEditingController(text: initialInvoice);

    _selectedDate = existing?.date ?? parsed?.date.value ?? DateTime.now();
    _selectedCategory =
        existing?.category ??
        parsed?.suggestedCategory.value ??
        ReceiptCategories.other;

    if (widget.acquiredImage != null) {
      _previewBytes = widget.acquiredImage!.bytes;
    } else if (existing?.imagePath != null) {
      _loadExistingImageBytes(existing!.imagePath!);
    }
  }

  Future<void> _loadExistingImageBytes(String imagePath) async {
    final storage = ref.read(receiptImageStorageServiceProvider);
    final bytes = await storage.readReceiptImageBytes(imagePath);
    if (mounted && bytes != null) {
      setState(() {
        _previewBytes = bytes;
      });
    }
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _amountController.dispose();
    _vatController.dispose();
    _invoiceNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isAfter(now) ? now : _selectedDate,
      firstDate: DateTime(2000),
      lastDate: now.add(const Duration(days: 7)),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  int? _parseEnteredAmountToMinorUnits(String raw) {
    final cleaned = raw
        .replaceAll(RegExp(r'[\s\u00A0\u202F€$£CHFcaCA]'), '')
        .replaceAll(',', '.')
        .trim();
    final parsedDouble = double.tryParse(cleaned);
    if (parsedDouble == null || parsedDouble <= 0) return null;
    return Receipt.majorToMinorUnits(parsedDouble);
  }

  Future<void> _saveValidatedReceipt() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final minorUnits = _parseEnteredAmountToMinorUnits(_amountController.text);
    if (minorUnits == null || minorUnits <= 0) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final repository = ref.read(receiptRepositoryProvider);
      final imageStorage = ref.read(receiptImageStorageServiceProvider);
      final existing = widget.existingReceipt;
      final receiptId = existing?.id ?? _uuid.v4();

      String? persistedImagePath = existing?.imagePath;
      if (widget.acquiredImage != null) {
        persistedImagePath = await imageStorage.saveReceiptImage(
          receiptId: receiptId,
          sourcePath: widget.acquiredImage!.path,
          bytes: widget.acquiredImage!.bytes,
        );
      }

      final now = DateTime.now();
      final analysis = widget.ocrScanResult?.analysis;
      final enteredVatMinor =
          _parseEnteredAmountToMinorUnits(_vatController.text);
      final finalVatMinor = enteredVatMinor ??
          (analysis?.vatAmountMinor.value != null
              ? analysis!.vatAmountMinor.value
              : existing?.vatAmountMinorUnits);
      final finalVatRate =
          analysis?.vatRates.firstOrNull ?? existing?.vatRate;
      final finalInvoiceNum = _invoiceNumberController.text.trim().isNotEmpty
          ? _invoiceNumberController.text.trim()
          : (analysis?.invoiceNumber.value ?? existing?.invoiceNumber);

      final receipt = Receipt.fromMinorUnits(
        id: receiptId,
        date: _selectedDate,
        amountMinorUnits: minorUnits,
        merchantName: _merchantController.text.trim(),
        imagePath: persistedImagePath,
        category: _selectedCategory,
        createdAt: existing?.createdAt ?? now,
        updatedAt: _isEditingExisting ? now : null,
        vatAmountMinorUnits: finalVatMinor,
        vatRate: finalVatRate,
        invoiceNumber: finalInvoiceNum,
      );

      if (_isEditingExisting) {
        await repository.updateReceipt(receipt);
      } else {
        await repository.saveReceipt(receipt);
      }

      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _openImageZoomModal(Uint8List bytes) {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        return Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: Stack(
            children: <Widget>[
              Center(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: Image.memory(bytes, fit: BoxFit.contain),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: SafeArea(
                  child: IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(
                        AppSpacing.minTouchTarget,
                        AppSpacing.minTouchTarget,
                      ),
                    ),
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.scannifyColors;
    final textTheme = Theme.of(context).textTheme;
    final prefs = ref.watch(appPreferencesProvider);
    final strings = prefs.strings;

    return Scaffold(
      backgroundColor: colors.primaryBackground,
      appBar: CustomAppBar(
        title: _isEditingExisting
            ? strings.editReceiptTitle
            : strings.validateReceiptTitle,
      ),
      body: ResponsiveConstrainedBox(
        maxWidth: AppSpacing.maxNarrowContentWidth,
        padding: ResponsiveUtils.responsiveHorizontalPadding(context),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.only(
              top: AppSpacing.sm,
              bottom: AppSpacing.xxl,
            ),
            children: <Widget>[
              // 1. OCR Confidence Summary Banner (when coming from scanner)
              if (widget.ocrScanResult != null) ...<Widget>[
                OcrResultBanner(
                  parsedResult: widget.ocrScanResult!.parsedReceipt,
                  isAutomaticOcrSupported:
                      widget.ocrScanResult!.isAutomaticOcrSupported,
                  strings: strings,
                  analysis: widget.ocrScanResult!.analysis,
                ),
                const SizedBox(height: AppSpacing.md),
                if (widget.ocrScanResult!.analysis != null &&
                    _hasFinancialDetails(
                      widget.ocrScanResult!.analysis!,
                    )) ...<Widget>[
                  _FinancialDetailsCard(
                    analysis: widget.ocrScanResult!.analysis!,
                    strings: strings,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ],

              // 2. Receipt Image Preview Card
              if (_previewBytes != null) ...<Widget>[
                GestureDetector(
                  onTap: () => _openImageZoomModal(_previewBytes!),
                  child: Container(
                    height: 190,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: colors.secondaryBackground,
                      borderRadius: AppRadii.cardBorderRadius,
                      border: Border.all(color: colors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        Image.memory(_previewBytes!, fit: BoxFit.contain),
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: AppRadii.chipBorderRadius,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const Icon(
                                  Icons.zoom_in_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  strings.zoom,
                                  style: textTheme.labelSmall?.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],

              // 3. Merchant Name Field
              Text(
                strings.merchantLabel,
                style: textTheme.labelLarge?.copyWith(
                  color: colors.secondaryText,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextFormField(
                controller: _merchantController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                style: textTheme.bodyLarge,
                decoration: InputDecoration(
                  hintText: strings.merchantHint,
                  prefixIcon: Icon(
                    Icons.storefront_rounded,
                    color: colors.primaryEmerald,
                  ),
                ),
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return strings.merchantRequired;
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),

              // 4. Total Amount Field
              Text(
                '${strings.amountLabel} (${widget.ocrScanResult?.parsedReceipt.detectedCurrencySymbol ?? prefs.currency.symbol})',
                style: textTheme.labelLarge?.copyWith(
                  color: colors.secondaryText,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.done,
                style: AppTypography.cardAmount(
                  colors.primaryText,
                ).copyWith(fontSize: 18),
                decoration: InputDecoration(
                  hintText: '0.00',
                  prefixIcon: Icon(
                    Icons.payments_outlined,
                    color: colors.primaryEmerald,
                  ),
                  suffixText:
                      widget
                          .ocrScanResult
                          ?.parsedReceipt
                          .detectedCurrencyCode ??
                      prefs.currency.code,
                ),
                validator: (String? value) {
                  final minor = _parseEnteredAmountToMinorUnits(value ?? '');
                  if (minor == null || minor <= 0) {
                    return strings.amountRequired;
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),

              // 4b. Accounting / Tax & Invoice details (TVA & N° Facture)
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colors.cardBackground,
                  borderRadius: AppRadii.cardBorderRadius,
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.receipt_long_rounded,
                          size: 18,
                          color: colors.primaryEmerald,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          strings.taxAndInvoiceDetails,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                strings.deductibleVatTitle,
                                style: textTheme.labelSmall?.copyWith(
                                  color: colors.secondaryText,
                                ),
                              ),
                              const SizedBox(height: 4),
                              TextFormField(
                                controller: _vatController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                style: textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: InputDecoration(
                                  isDense: true,
                                  hintText: '0.00',
                                  suffixText:
                                      widget.ocrScanResult?.parsedReceipt
                                          .detectedCurrencySymbol ??
                                      prefs.currency.symbol,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                strings.invoiceNumberLabel,
                                style: textTheme.labelSmall?.copyWith(
                                  color: colors.secondaryText,
                                ),
                              ),
                              const SizedBox(height: 4),
                              TextFormField(
                                controller: _invoiceNumberController,
                                textCapitalization:
                                    TextCapitalization.characters,
                                style: textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  hintText: 'FAC-001',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // 5. Receipt Date Picker
              Text(
                strings.dateLabel,
                style: textTheme.labelLarge?.copyWith(
                  color: colors.secondaryText,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              InkWell(
                borderRadius: AppRadii.buttonBorderRadius,
                onTap: _pickDate,
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: AppSpacing.minTouchTarget + 6,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: colors.secondaryBackground,
                    borderRadius: AppRadii.buttonBorderRadius,
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 20,
                        color: colors.primaryEmerald,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          _dateFormat.format(_selectedDate),
                          style: textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.edit_calendar_rounded,
                        size: 20,
                        color: colors.secondaryText,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // 6. Category Selector Chips
              Text(
                strings.categoryLabel,
                style: textTheme.labelLarge?.copyWith(
                  color: colors.secondaryText,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: ReceiptCategories.all.map((String category) {
                  return CategoryChip(
                    category: category,
                    isSelected: _selectedCategory == category,
                    onSelected: () {
                      setState(() {
                        _selectedCategory = category;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.xxl),

              // 7. Save Receipt Primary Action Button
              ScanButton(
                label: strings.saveReceipt,
                icon: Icons.check_circle_rounded,
                isFullWidth: true,
                isLoading: _isSaving,
                onPressed: _saveValidatedReceipt,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _hasFinancialDetails(FinancialAnalysis a) {
  return a.items.isNotEmpty ||
      a.subtotalHtMinor.value != null ||
      a.vatAmountMinor.value != null ||
      a.invoiceNumber.value != null ||
      a.supplierVatNumber.value != null ||
      a.supplierSiret.value != null;
}

class _FinancialDetailsCard extends StatefulWidget {
  const _FinancialDetailsCard({
    required this.analysis,
    this.strings,
  });

  final FinancialAnalysis analysis;
  final AppStrings? strings;

  @override
  State<_FinancialDetailsCard> createState() => _FinancialDetailsCardState();
}

class _FinancialDetailsCardState extends State<_FinancialDetailsCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.scannifyColors;
    final textTheme = Theme.of(context).textTheme;
    final a = widget.analysis;
    final s = widget.strings ?? AppStrings.of(context);

    final curr = a.currencyCode.value ?? 'EUR';
    final sym = curr == 'USD' ? '\$' : '€';

    return Container(
      decoration: BoxDecoration(
        color: colors.secondaryBackground,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadii.md)),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: <Widget>[
          InkWell(
            borderRadius: const BorderRadius.all(Radius.circular(AppRadii.md)),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    color: colors.primaryEmerald,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      s.financialDetailsAndVat,
                      style: textTheme.titleSmall?.copyWith(
                        color: colors.primaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (a.items.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: colors.cardBackground,
                        borderRadius: AppRadii.chipBorderRadius,
                      ),
                      child: Text(
                        s.itemsCountLabel(a.items.length),
                        style: textTheme.labelSmall?.copyWith(
                          color: colors.secondaryText,
                        ),
                      ),
                    ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: colors.secondaryText,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...<Widget>[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Identifiers: Invoice #, SIRET, VAT #
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      if (a.invoiceNumber.value != null)
                        _buildInfoTag(context, 'N° ${a.invoiceNumber.value}'),
                      if (a.supplierVatNumber.value != null)
                        _buildInfoTag(
                          context,
                          'TVA ${a.supplierVatNumber.value}',
                        ),
                      if (a.supplierSiret.value != null)
                        _buildInfoTag(
                          context,
                          'SIRET ${a.supplierSiret.value}',
                        ),
                    ],
                  ),
                  if (a.subtotalHtMinor.value != null ||
                      a.vatAmountMinor.value != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    _buildSummaryRow(
                      context,
                      label: s.subtotalExclTax,
                      amountMinor: a.subtotalHtMinor.value,
                      sym: sym,
                    ),
                    if (a.discountMinor.value != null &&
                        a.discountMinor.value! > 0)
                      _buildSummaryRow(
                        context,
                        label: s.discountLabel,
                        amountMinor: -a.discountMinor.value!,
                        sym: sym,
                        isNegative: true,
                      ),
                    _buildSummaryRow(
                      context,
                      label: s.vatLabel,
                      amountMinor: a.vatAmountMinor.value,
                      sym: sym,
                    ),
                    const Divider(height: 12),
                    _buildSummaryRow(
                      context,
                      label: s.totalInclTax,
                      amountMinor: a.totalTtcMinor.value,
                      sym: sym,
                      isBold: true,
                    ),
                  ],
                  if (a.items.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      s.lineItemsTitle,
                      style: textTheme.labelLarge?.copyWith(
                        color: colors.primaryText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    for (final item in a.items)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                '${item.description}'
                                '${item.quantity != null && item.quantity! > 1 ? " × ${item.quantity}" : ""}',
                                style: textTheme.bodySmall?.copyWith(
                                  color: colors.primaryText,
                                ),
                              ),
                            ),
                            if (item.totalMinor != null)
                              Text(
                                '${(item.totalMinor! / 100.0).toStringAsFixed(2)} $sym',
                                style: textTheme.bodySmall?.copyWith(
                                  color: colors.primaryText,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoTag(BuildContext context, String text) {
    final colors = context.scannifyColors;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: AppRadii.chipBorderRadius,
        border: Border.all(color: colors.border),
      ),
      child: Text(
        text,
        style: textTheme.labelSmall?.copyWith(
          color: colors.secondaryText,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    BuildContext context, {
    required String label,
    required int? amountMinor,
    required String sym,
    bool isBold = false,
    bool isNegative = false,
  }) {
    if (amountMinor == null) return const SizedBox.shrink();
    final colors = context.scannifyColors;
    final textTheme = Theme.of(context).textTheme;

    final formatted = '${(amountMinor.abs() / 100.0).toStringAsFixed(2)} $sym';
    final text = isNegative ? '-$formatted' : formatted;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: isBold ? colors.primaryText : colors.secondaryText,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          Text(
            text,
            style: textTheme.bodySmall?.copyWith(
              color: isBold ? colors.primaryEmerald : colors.primaryText,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
