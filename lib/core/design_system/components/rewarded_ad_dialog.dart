import 'package:flutter/material.dart';
import '../../../features/monetization/domain/services/quota_service.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import '../utils/animation_utils.dart';

/// Modal dialog prompting the user to watch a short rewarded video advertisement
/// to unlock 1 additional OCR scan or a CSV/PDF financial report export.
class RewardedAdDialog extends StatelessWidget {
  const RewardedAdDialog({
    super.key,
    this.title = 'Daily Free Scans Used',
    this.message = QuotaService.quotaExhaustedMessage,
    this.watchVideoLabel = 'Watch Video',
    this.maybeLaterLabel = 'Maybe Later',
    this.errorMessage,
    this.isLoading = false,
    required this.onWatchVideo,
    required this.onMaybeLater,
  });

  final String title;
  final String message;
  final String watchVideoLabel;
  final String maybeLaterLabel;
  final String? errorMessage;
  final bool isLoading;
  final VoidCallback onWatchVideo;
  final VoidCallback onMaybeLater;

  @override
  Widget build(BuildContext context) {
    final colors = context.scannifyColors;
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      backgroundColor: colors.cardBackground,
      surfaceTintColor: Colors.transparent,
      titlePadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.sm,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xs,
      ),
      actionsPadding: const EdgeInsets.all(AppSpacing.lg),
      title: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colors.primaryEmerald.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.play_circle_fill_rounded,
              color: colors.primaryEmerald,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              title,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            message,
            style: textTheme.bodyMedium?.copyWith(color: colors.secondaryText),
          ),
          if (errorMessage != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: colors.error.withValues(alpha: 0.12),
                borderRadius: const BorderRadius.all(
                  Radius.circular(AppRadii.sm),
                ),
                border: Border.all(color: colors.error.withValues(alpha: 0.4)),
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
                      errorMessage!,
                      style: textTheme.bodySmall?.copyWith(color: colors.error),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: <Widget>[
        OutlinedButton(
          onPressed: isLoading
              ? null
              : () {
                  HapticsUtil.selection();
                  onMaybeLater();
                },
          child: Text(maybeLaterLabel),
        ),
        ElevatedButton.icon(
          onPressed: isLoading
              ? null
              : () {
                  HapticsUtil.mediumImpact();
                  onWatchVideo();
                },
          icon: isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF041F15),
                  ),
                )
              : const Icon(Icons.play_arrow_rounded, size: 20),
          label: Text(watchVideoLabel),
        ),
      ],
    );
  }
}
