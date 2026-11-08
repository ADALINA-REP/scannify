import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/settings/app_preferences.dart';
import '../../../monetization/domain/services/quota_service.dart';
import '../../data/services/image_acquisition_service.dart';
import 'receipt_validation_screen.dart';

/// Receipt Scanner and Acquisition screen (Section 9B).
///
/// Features a minimal FinTech viewfinder frame with rounded Emerald corners,
/// capture guidance, Camera & Gallery acquisition with native cropping,
/// animated OCR laser progress, and daily quota / Rewarded Ad integration.
class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _laserController;
  bool _isProcessingOcr = false;
  String? _errorFeedback;

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _laserController.dispose();
    super.dispose();
  }

  Future<bool> _ensureQuotaAvailableOrUnlock() async {
    final quotaService = ref.read(quotaServiceProvider);
    final status = await quotaService.getQuotaStatus();
    if (status.canScanImmediately) {
      return true;
    }

    if (!mounted) return false;
    return _showQuotaRewardedDialog();
  }

  Future<bool> _showQuotaRewardedDialog() async {
    String? dialogError;
    bool isAdLoading = false;

    final unlocked = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            final strings = ref.read(appPreferencesProvider).strings;
            return RewardedAdDialog(
              title: strings.quotaExhaustedTitle,
              message: QuotaService.quotaExhaustedMessage,
              watchVideoLabel: dialogError != null
                  ? strings.retry
                  : strings.watchVideo,
              maybeLaterLabel: strings.maybeLater,
              errorMessage: dialogError,
              isLoading: isAdLoading,
              onMaybeLater: () => Navigator.of(dialogContext).pop(false),
              onWatchVideo: () async {
                setDialogState(() {
                  isAdLoading = true;
                  dialogError = null;
                });

                final adResult = await ref
                    .read(rewardedAdServiceProvider)
                    .unlockAdditionalScanWithAd();

                if (!dialogContext.mounted) return;

                if (adResult.isRewardGranted) {
                  Navigator.of(dialogContext).pop(true);
                } else {
                  setDialogState(() {
                    isAdLoading = false;
                    dialogError =
                        adResult.userMessage ??
                        'Ad unavailable right now. Please try again.';
                  });
                }
              },
            );
          },
        );
      },
    );

    return unlocked ?? false;
  }

  Future<void> _handleImageAcquisition({required bool fromCamera}) async {
    if (_isProcessingOcr) return;

    setState(() {
      _errorFeedback = null;
    });

    final ocrService = ref.read(ocrServiceProvider);
    if (ocrService.isSupported) {
      final hasQuota = await _ensureQuotaAvailableOrUnlock();
      if (!hasQuota) return;
    }

    try {
      final acquisitionService = ref.read(imageAcquisitionServiceProvider);
      final AcquiredReceiptImage? acquired = fromCamera
          ? await acquisitionService.captureFromCamera(enableCropping: true)
          : await acquisitionService.pickFromGallery(enableCropping: true);

      if (acquired == null || !mounted) {
        return; // User cancelled camera/gallery picker
      }

      if (!ocrService.isSupported) {
        // Web manual fallback: open validation form with the imported photo
        final fallbackScan = await ocrService.processImage(acquired.path);
        if (!mounted) return;
        final saved = await Navigator.of(context).push<bool>(
          MaterialPageRoute<bool>(
            builder: (_) => ReceiptValidationScreen(
              ocrScanResult: fallbackScan,
              acquiredImage: acquired,
            ),
          ),
        );
        if (saved == true && mounted) {
          Navigator.of(context).pop(true);
        }
        return;
      }

      setState(() {
        _isProcessingOcr = true;
      });

      final quotaService = ref.read(quotaServiceProvider);
      final scanResult = await quotaService.executeQuotaProtectedScan(
        () => ocrService.processImage(acquired.path),
      );

      if (!mounted) return;
      setState(() {
        _isProcessingOcr = false;
      });

      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => ReceiptValidationScreen(
            ocrScanResult: scanResult,
            acquiredImage: acquired,
          ),
        ),
      );

      if (saved == true && mounted) {
        Navigator.of(context).pop(true);
      }
    } on MonetizationException catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessingOcr = false;
      });
      if (e.code == 'QUOTA_EXHAUSTED') {
        await _showQuotaRewardedDialog();
      } else {
        setState(() {
          _errorFeedback = e.message;
        });
      }
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessingOcr = false;
        _errorFeedback = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isProcessingOcr = false;
        _errorFeedback =
            'An unexpected error occurred while scanning. Your scan quota was not deducted.';
      });
    }
  }

  Future<void> _openManualEntry() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const ReceiptValidationScreen()),
    );
    if (saved == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.scannifyColors;
    final textTheme = Theme.of(context).textTheme;
    final prefs = ref.watch(appPreferencesProvider);
    final strings = prefs.strings;
    final quotaAsync = ref.watch(quotaStatusStreamProvider);
    final ocrSupported = ref.watch(ocrServiceProvider).isSupported;

    return Scaffold(
      backgroundColor: colors.primaryBackground,
      appBar: CustomAppBar(
        title: strings.scannerTitle,
        actions: <Widget>[
          TextButton.icon(
            onPressed: _isProcessingOcr ? null : _openManualEntry,
            icon: const Icon(Icons.edit_note_rounded, size: 20),
            label: Text(strings.manualEntry),
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveConstrainedBox(
          maxWidth: AppSpacing.maxNarrowContentWidth,
          padding: ResponsiveUtils.responsiveHorizontalPadding(context),
          child: Column(
            children: <Widget>[
              const SizedBox(height: AppSpacing.xs),

              // Quota Status Pill
              quotaAsync.maybeWhen(
                data: (QuotaStatus quota) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colors.secondaryBackground,
                    borderRadius: AppRadii.chipBorderRadius,
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        quota.isUnlimitedPremium
                            ? Icons.workspace_premium_rounded
                            : Icons.bolt_rounded,
                        size: 16,
                        color: colors.primaryEmerald,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        quota.isUnlimitedPremium
                            ? strings.unlimitedOcrScansPro
                            : strings.scansAvailableToday(
                                quota.totalAvailableScans,
                              ),
                        style: textTheme.labelMedium?.copyWith(
                          color: colors.primaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                orElse: () => const SizedBox.shrink(),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Receipt Detection Viewfinder Frame
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: colors.secondaryBackground,
                    borderRadius: const BorderRadius.all(
                      Radius.circular(AppRadii.xl),
                    ),
                    border: Border.all(color: colors.border),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      // Rounded Emerald Detection Corners
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: CustomPaint(
                            painter: _ReceiptDetectionFramePainter(
                              color: colors.primaryEmerald,
                            ),
                          ),
                        ),
                      ),

                      // Animated Laser Bar during OCR
                      if (_isProcessingOcr &&
                          !AppAnimations.isReducedMotion(context))
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.xl + 8),
                            child: AnimatedBuilder(
                              animation: _laserController,
                              builder: (BuildContext context, Widget? _) {
                                return Align(
                                  alignment: Alignment(
                                    0,
                                    (_laserController.value * 2) - 1,
                                  ),
                                  child: Container(
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: colors.secondaryEmerald,
                                      boxShadow: <BoxShadow>[
                                        BoxShadow(
                                          color: colors.primaryEmerald
                                              .withValues(alpha: 0.7),
                                          blurRadius: 12,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                      // Center Guidance or OCR Progress
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xxl,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colors.primaryEmerald.withValues(
                                  alpha: 0.14,
                                ),
                              ),
                              child: _isProcessingOcr
                                  ? Padding(
                                      padding: const EdgeInsets.all(18.0),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 3,
                                        color: colors.primaryEmerald,
                                      ),
                                    )
                                  : Icon(
                                      Icons.receipt_long_rounded,
                                      size: 32,
                                      color: colors.primaryEmerald,
                                    ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              _isProcessingOcr
                                  ? strings.ocrAnalyzing
                                  : strings.scannerGuidance,
                              textAlign: TextAlign.center,
                              style: textTheme.titleMedium?.copyWith(
                                color: colors.primaryText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (!ocrSupported) ...<Widget>[
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                strings.webOcrNotice,
                                textAlign: TextAlign.center,
                                style: textTheme.bodySmall?.copyWith(
                                  color: colors.secondaryText,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (_errorFeedback != null) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.sm + 2),
                  decoration: BoxDecoration(
                    color: colors.error.withValues(alpha: 0.12),
                    borderRadius: const BorderRadius.all(
                      Radius.circular(AppRadii.sm),
                    ),
                    border: Border.all(
                      color: colors.error.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.error_outline_rounded,
                        size: 18,
                        color: colors.error,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          _errorFeedback!,
                          style: textTheme.bodySmall?.copyWith(
                            color: colors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.lg),

              // Primary Capture & Gallery Import Actions
              ScanButton(
                label: strings.capturePhoto,
                icon: Icons.camera_alt_rounded,
                isFullWidth: true,
                isLoading: _isProcessingOcr,
                onPressed: () => _handleImageAcquisition(fromCamera: true),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                height: AppSpacing.minTouchTarget + 4,
                child: OutlinedButton.icon(
                  onPressed: _isProcessingOcr
                      ? null
                      : () => _handleImageAcquisition(fromCamera: false),
                  icon: const Icon(Icons.photo_library_outlined, size: 20),
                  label: Text(strings.importFromGallery),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

/// Paints rounded corner brackets indicating the receipt alignment zone.
class _ReceiptDetectionFramePainter extends CustomPainter {
  const _ReceiptDetectionFramePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;

    const double cornerLen = 32.0;
    const double r = 16.0;

    // Top-left corner
    final tl = Path()
      ..moveTo(0, cornerLen)
      ..lineTo(0, r)
      ..arcToPoint(const Offset(r, 0), radius: const Radius.circular(r))
      ..lineTo(cornerLen, 0);
    canvas.drawPath(tl, paint);

    // Top-right corner
    final tr = Path()
      ..moveTo(size.width - cornerLen, 0)
      ..lineTo(size.width - r, 0)
      ..arcToPoint(Offset(size.width, r), radius: const Radius.circular(r))
      ..lineTo(size.width, cornerLen);
    canvas.drawPath(tr, paint);

    // Bottom-left corner
    final bl = Path()
      ..moveTo(0, size.height - cornerLen)
      ..lineTo(0, size.height - r)
      ..arcToPoint(
        Offset(r, size.height),
        radius: const Radius.circular(r),
        clockwise: false,
      )
      ..lineTo(cornerLen, size.height);
    canvas.drawPath(bl, paint);

    // Bottom-right corner
    final br = Path()
      ..moveTo(size.width - cornerLen, size.height)
      ..lineTo(size.width - r, size.height)
      ..arcToPoint(
        Offset(size.width, size.height - r),
        radius: const Radius.circular(r),
        clockwise: false,
      )
      ..lineTo(size.width, size.height - cornerLen);
    canvas.drawPath(br, paint);
  }

  @override
  bool shouldRepaint(covariant _ReceiptDetectionFramePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
