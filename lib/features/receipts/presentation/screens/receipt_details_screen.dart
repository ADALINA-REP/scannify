import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/settings/app_preferences.dart';
import '../../../ocr/presentation/screens/receipt_validation_screen.dart';
import '../../domain/entities/receipt.dart';

/// Receipt Details screen (Section 9E).
///
/// Displays the receipt photo (with full-screen zoom), merchant name,
/// transaction date, formatted amount, category badge, and Edit / Delete
/// actions with destructive confirmation.
class ReceiptDetailsScreen extends ConsumerStatefulWidget {
  const ReceiptDetailsScreen({super.key, required this.receiptId});

  final String receiptId;

  @override
  ConsumerState<ReceiptDetailsScreen> createState() =>
      _ReceiptDetailsScreenState();
}

class _ReceiptDetailsScreenState extends ConsumerState<ReceiptDetailsScreen> {
  static final DateFormat _fullDateFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _timestampFormat = DateFormat('dd/MM/yyyy HH:mm');

  Uint8List? _imageBytes;
  bool _isLoadingImage = false;
  String? _loadedPath;

  Future<void> _loadReceiptImageIfNeeded(String? imagePath) async {
    if (imagePath == _loadedPath) return;
    _loadedPath = imagePath;

    if (imagePath == null || imagePath.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _imageBytes = null;
          _isLoadingImage = false;
        });
      }
      return;
    }

    setState(() {
      _isLoadingImage = true;
    });

    final storage = ref.read(receiptImageStorageServiceProvider);
    final bytes = await storage.readReceiptImageBytes(imagePath);

    if (mounted) {
      setState(() {
        _imageBytes = bytes;
        _isLoadingImage = false;
      });
    }
  }

  Future<void> _handleEdit(Receipt receipt) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ReceiptValidationScreen(existingReceipt: receipt),
      ),
    );
    // Reset loaded path so any updated image is reloaded
    _loadedPath = null;
    final updated = await ref
        .read(receiptRepositoryProvider)
        .getReceiptById(widget.receiptId);
    if (updated != null && mounted) {
      await _loadReceiptImageIfNeeded(updated.imagePath);
    }
  }

  Future<void> _handleDelete(Receipt receipt) async {
    final strings = ref.read(appPreferencesProvider).strings;
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: strings.deleteReceiptConfirmTitle,
      message: strings.deleteReceiptConfirmMessage(receipt.merchantName),
      confirmLabel: strings.delete,
      cancelLabel: strings.cancel,
      isDestructive: true,
      icon: Icons.delete_forever_rounded,
    );

    if (!confirmed || !mounted) return;

    await ref.read(receiptRepositoryProvider).deleteReceipt(receipt.id);
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
    }
  }

  void _openFullScreenImage(Uint8List bytes) {
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
                  maxScale: 4.5,
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
    final allReceiptsAsync = ref.watch(allReceiptsStreamProvider);

    final Receipt? receipt = allReceiptsAsync.maybeWhen(
      data: (list) {
        for (final r in list) {
          if (r.id == widget.receiptId) return r;
        }
        return null;
      },
      orElse: () => null,
    );

    if (receipt == null) {
      return Scaffold(
        backgroundColor: colors.primaryBackground,
        appBar: CustomAppBar(
          title: strings.receiptDetailsTitle,
        ),
        body: EmptyState(
          title: strings.receiptNotFoundTitle,
          subtitle: strings.receiptNotFoundSubtitle,
        ),
      );
    }

    _loadReceiptImageIfNeeded(receipt.imagePath);
    final categoryStyle = CategoryStyles.forCategory(receipt.category);
    final localizedCategory = strings.categoryDisplayName(receipt.category);

    return Scaffold(
      backgroundColor: colors.primaryBackground,
      appBar: CustomAppBar(
        title: strings.receiptDetailsTitle,
        actions: <Widget>[
          IconButton(
            constraints: const BoxConstraints(
              minWidth: AppSpacing.minTouchTarget,
              minHeight: AppSpacing.minTouchTarget,
            ),
            tooltip: strings.edit,
            icon: Icon(Icons.edit_outlined, color: colors.primaryText),
            onPressed: () => _handleEdit(receipt),
          ),
          IconButton(
            constraints: const BoxConstraints(
              minWidth: AppSpacing.minTouchTarget,
              minHeight: AppSpacing.minTouchTarget,
            ),
            tooltip: strings.delete,
            icon: Icon(Icons.delete_outline_rounded, color: colors.error),
            onPressed: () => _handleDelete(receipt),
          ),
        ],
      ),
      body: ResponsiveConstrainedBox(
        maxWidth: AppSpacing.maxNarrowContentWidth,
        padding: ResponsiveUtils.responsiveHorizontalPadding(context),
        child: ListView(
          padding: const EdgeInsets.only(
            top: AppSpacing.sm,
            bottom: AppSpacing.xxl,
          ),
          children: <Widget>[
            // 1. Hero Financial Header Card
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: colors.cardBackground,
                borderRadius: AppRadii.cardBorderRadius,
                border: Border.all(color: colors.border),
              ),
              child: Column(
                children: <Widget>[
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: categoryStyle.accentColor.withValues(alpha: 0.15),
                      borderRadius: const BorderRadius.all(
                        Radius.circular(AppRadii.md),
                      ),
                    ),
                    child: Icon(
                      categoryStyle.icon,
                      color: categoryStyle.accentColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    receipt.merchantName,
                    textAlign: TextAlign.center,
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: categoryStyle.accentColor.withValues(alpha: 0.14),
                      borderRadius: AppRadii.chipBorderRadius,
                    ),
                    child: Text(
                      localizedCategory,
                      style: textTheme.labelMedium?.copyWith(
                        color: categoryStyle.accentColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    prefs.formatMinorUnits(receipt.amountMinorUnits),
                    style: AppTypography.heroAmount(colors.primaryEmerald),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // 2. Metadata Details Card
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: colors.cardBackground,
                borderRadius: AppRadii.cardBorderRadius,
                border: Border.all(color: colors.border),
              ),
              child: Column(
                children: <Widget>[
                  _DetailRow(
                    icon: Icons.calendar_today_rounded,
                    label: strings.dateLabel,
                    value: _fullDateFormat.format(receipt.date),
                  ),
                  Divider(color: colors.border, height: 24),
                  _DetailRow(
                    icon: Icons.category_outlined,
                    label: strings.categoryLabel,
                    value: localizedCategory,
                  ),
                  Divider(color: colors.border, height: 24),
                  _DetailRow(
                    icon: Icons.schedule_rounded,
                    label: strings.createdOnLabel,
                    value: _timestampFormat.format(receipt.createdAt),
                  ),
                  if (receipt.invoiceNumber != null &&
                      receipt.invoiceNumber!.isNotEmpty) ...<Widget>[
                    Divider(color: colors.border, height: 24),
                    _DetailRow(
                      icon: Icons.tag_rounded,
                      label: strings.invoiceNumberLabel,
                      value: receipt.invoiceNumber!,
                    ),
                  ],
                  Divider(color: colors.border, height: 24),
                  _DetailRow(
                    icon: Icons.receipt_long_rounded,
                    label: strings.deductibleVatTitle,
                    value: receipt.vatAmountMinorUnits != null
                        ? '${prefs.formatMinorUnits(receipt.vatAmountMinorUnits!)}${receipt.vatRate != null ? " (${receipt.vatRate!.toStringAsFixed(0)}%)" : ""}'
                        : '${prefs.formatMinorUnits(receipt.effectiveVatMinorUnits)} (${strings.estimatedBadge})',
                  ),
                  Divider(color: colors.border, height: 24),
                  _DetailRow(
                    icon: Icons.account_balance_rounded,
                    label: strings.subtotalExclTax,
                    value: prefs.formatMinorUnits(receipt.subtotalHtMinorUnits),
                  ),
                  if (receipt.updatedAt != null) ...<Widget>[
                    Divider(color: colors.border, height: 24),
                    _DetailRow(
                      icon: Icons.update_rounded,
                      label: strings.lastUpdatedLabel,
                      value: _timestampFormat.format(receipt.updatedAt!),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // 3. Receipt Image Section
            Text(
              strings.receiptImageSectionTitle,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_isLoadingImage)
              const LoadingSkeleton(height: 220)
            else if (_imageBytes != null)
              GestureDetector(
                onTap: () => _openFullScreenImage(_imageBytes!),
                child: Container(
                  height: 260,
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
                      Image.memory(_imageBytes!, fit: BoxFit.cover),
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.72),
                            borderRadius: AppRadii.chipBorderRadius,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Icon(
                                Icons.fullscreen_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                strings.viewFullscreen,
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
              )
            else
              Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: colors.secondaryBackground,
                  borderRadius: AppRadii.cardBorderRadius,
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  children: <Widget>[
                    Icon(
                      Icons.image_not_supported_outlined,
                      size: 32,
                      color: colors.mutedText,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      strings.noImageAttached,
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: AppSpacing.xl),

            // 4. Bottom Action Buttons
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handleEdit(receipt),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: Text(strings.edit),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.error,
                      side: BorderSide(
                        color: colors.error.withValues(alpha: 0.5),
                      ),
                    ),
                    onPressed: () => _handleDelete(receipt),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: Text(strings.delete),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.scannifyColors;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: <Widget>[
        Icon(icon, size: 18, color: colors.secondaryText),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: textTheme.bodyMedium?.copyWith(color: colors.secondaryText),
          ),
        ),
        Text(
          value,
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
