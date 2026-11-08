import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/services/premium_service.dart';
import '../../domain/services/quota_service.dart';

/// [SharedPreferences]-backed implementation of [QuotaService].
///
/// Persists daily scan quota state locally, resets at local midnight,
/// protects against rapid multi-clicks, and guarantees failed OCR operations
/// never consume a user's scan quota.
class LocalQuotaService implements QuotaService {
  LocalQuotaService({
    required SharedPreferences sharedPreferences,
    required PremiumService premiumService,
    DateTime Function()? clock,
    int dailyFreeLimit = QuotaService.defaultDailyFreeScanLimit,
  }) : _prefs = sharedPreferences,
       _premiumService = premiumService,
       _clock = clock ?? DateTime.now,
       _dailyFreeLimit = dailyFreeLimit;

  static const String _keyLastResetDate = 'scannify_quota_last_reset_date';
  static const String _keyFreeScansConsumed =
      'scannify_quota_free_scans_consumed';
  static const String _keyBonusScansAvailable =
      'scannify_quota_bonus_scans_available';
  static const String _keyLastTzOffsetMinutes =
      'scannify_quota_last_tz_offset_minutes';
  static const String _keyLastRewardEventId =
      'scannify_quota_last_reward_event_id';

  final SharedPreferences _prefs;
  final PremiumService _premiumService;
  final DateTime Function() _clock;
  final int _dailyFreeLimit;

  final StreamController<QuotaStatus> _statusController =
      StreamController<QuotaStatus>.broadcast();

  final Set<String> _processedRewardEventIds = <String>{};
  bool _isScanInFlight = false;

  @override
  Future<QuotaStatus> getQuotaStatus() async {
    await _ensureMidnightResetIfNeeded();
    return _buildCurrentStatus();
  }

  @override
  Stream<QuotaStatus> watchQuotaStatus() async* {
    yield await getQuotaStatus();
    yield* _statusController.stream;
  }

  @override
  Future<T> executeQuotaProtectedScan<T>(
    Future<T> Function() ocrOperation,
  ) async {
    if (_isScanInFlight) {
      throw const MonetizationException(
        message: 'A receipt scan is already in progress. Please wait.',
        code: 'SCAN_ALREADY_IN_PROGRESS',
      );
    }

    _isScanInFlight = true;
    try {
      final statusBefore = await getQuotaStatus();
      if (!statusBefore.canScanImmediately) {
        throw const MonetizationException(
          message: QuotaService.quotaExhaustedMessage,
          code: 'QUOTA_EXHAUSTED',
        );
      }

      // Run the OCR operation BEFORE committing quota consumption so that any
      // technical OCR failure leaves the user's quota untouched.
      final T result = await ocrOperation();

      // Re-verify midnight reset in case the scan crossed local midnight.
      await _ensureMidnightResetIfNeeded();
      final isPremium =
          _premiumService.currentEntitlements.hasUnlimitedOcrScans;

      if (!isPremium) {
        final consumed = _prefs.getInt(_keyFreeScansConsumed) ?? 0;
        final bonus = _prefs.getInt(_keyBonusScansAvailable) ?? 0;

        if (consumed < _dailyFreeLimit) {
          await _prefs.setInt(_keyFreeScansConsumed, consumed + 1);
        } else if (bonus > 0) {
          await _prefs.setInt(_keyBonusScansAvailable, bonus - 1);
        }
      }

      final updatedStatus = _buildCurrentStatus();
      _emitStatus(updatedStatus);
      return result;
    } finally {
      _isScanInFlight = false;
    }
  }

  @override
  Future<QuotaStatus> grantRewardedScan({required String rewardEventId}) async {
    final trimmedId = rewardEventId.trim();
    if (trimmedId.isEmpty) {
      throw const MonetizationException(
        message: 'Invalid reward event identifier.',
        code: 'INVALID_REWARD_ID',
      );
    }

    final lastPersistedRewardId = _prefs.getString(_keyLastRewardEventId);
    if (_processedRewardEventIds.contains(trimmedId) ||
        lastPersistedRewardId == trimmedId) {
      AppLogger.warning(
        'LocalQuotaService',
        'Ignored duplicate reward grant for already processed event ID.',
      );
      return getQuotaStatus();
    }

    await _ensureMidnightResetIfNeeded();
    final currentBonus = _prefs.getInt(_keyBonusScansAvailable) ?? 0;

    _processedRewardEventIds.add(trimmedId);
    await _prefs.setString(_keyLastRewardEventId, trimmedId);
    await _prefs.setInt(_keyBonusScansAvailable, currentBonus + 1);

    final updated = _buildCurrentStatus();
    _emitStatus(updated);

    AppLogger.info(
      'LocalQuotaService',
      'Granted 1 rewarded bonus scan (available bonus scans: ${updated.bonusScansAvailable}).',
    );
    return updated;
  }

  Future<void> _ensureMidnightResetIfNeeded() async {
    final nowLocal = _clock().toLocal();
    final todayKey = _formatLocalDateKey(nowLocal);
    final currentTzOffset = nowLocal.timeZoneOffset.inMinutes;

    final storedDateKey = _prefs.getString(_keyLastResetDate);
    final storedTzOffset = _prefs.getInt(_keyLastTzOffsetMinutes);

    if (storedDateKey != todayKey) {
      await _prefs.setString(_keyLastResetDate, todayKey);
      await _prefs.setInt(_keyFreeScansConsumed, 0);
      await _prefs.setInt(_keyBonusScansAvailable, 0);
      await _prefs.setInt(_keyLastTzOffsetMinutes, currentTzOffset);
      _emitStatus(_buildCurrentStatus());
      return;
    }

    if (storedTzOffset != currentTzOffset) {
      await _prefs.setInt(_keyLastTzOffsetMinutes, currentTzOffset);
    }
  }

  QuotaStatus _buildCurrentStatus() {
    final nowLocal = _clock().toLocal();
    final todayKey = _formatLocalDateKey(nowLocal);
    final storedDateKey = _prefs.getString(_keyLastResetDate) ?? todayKey;
    final consumed = (_prefs.getInt(_keyFreeScansConsumed) ?? 0).clamp(
      0,
      _dailyFreeLimit,
    );
    final bonus = (_prefs.getInt(_keyBonusScansAvailable) ?? 0).clamp(0, 999);
    final isPremium = _premiumService.currentEntitlements.hasUnlimitedOcrScans;

    return QuotaStatus(
      dailyFreeLimit: _dailyFreeLimit,
      freeScansConsumed: consumed,
      bonusScansAvailable: bonus,
      lastResetDateKey: storedDateKey,
      isUnlimitedPremium: isPremium,
    );
  }

  String _formatLocalDateKey(DateTime localTime) {
    final y = localTime.year.toString().padLeft(4, '0');
    final m = localTime.month.toString().padLeft(2, '0');
    final d = localTime.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  void _emitStatus(QuotaStatus status) {
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  void dispose() {
    _statusController.close();
  }
}
