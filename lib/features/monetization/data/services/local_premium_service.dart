import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/services/premium_service.dart';

/// Local [SharedPreferences]-backed implementation of [PremiumService].
///
/// Stores verified subscription entitlement state locally for offline access
/// and exposes a reactive stream for UI and quota services.
class LocalPremiumService implements PremiumService {
  LocalPremiumService({
    required SharedPreferences sharedPreferences,
    DateTime Function()? clock,
  }) : _prefs = sharedPreferences {
    _currentEntitlements = _loadFromPreferences();
  }

  static const String _keyIsPremium = 'scannify_premium_active';
  static const String _keyPlanId = 'scannify_premium_plan_id';
  static const String _keyExpirationIso = 'scannify_premium_expiration_iso';

  final SharedPreferences _prefs;
  final StreamController<PremiumEntitlements> _controller =
      StreamController<PremiumEntitlements>.broadcast();

  late PremiumEntitlements _currentEntitlements;

  @override
  PremiumEntitlements get currentEntitlements {
    _currentEntitlements = _loadFromPreferences();
    return _currentEntitlements;
  }

  @override
  Stream<PremiumEntitlements> watchEntitlements() async* {
    yield currentEntitlements;
    yield* _controller.stream;
  }

  @override
  Future<PremiumEntitlements> refreshEntitlements() async {
    _currentEntitlements = _loadFromPreferences();
    if (!_controller.isClosed) {
      _controller.add(_currentEntitlements);
    }
    return _currentEntitlements;
  }

  @override
  Future<void> updateVerifiedEntitlement(
    PremiumEntitlements entitlements,
  ) async {
    await _prefs.setBool(_keyIsPremium, entitlements.isPremiumActive);
    if (entitlements.activePlanId != null) {
      await _prefs.setString(_keyPlanId, entitlements.activePlanId!);
    } else {
      await _prefs.remove(_keyPlanId);
    }

    if (entitlements.expirationDate != null) {
      await _prefs.setString(
        _keyExpirationIso,
        entitlements.expirationDate!.toIso8601String(),
      );
    } else {
      await _prefs.remove(_keyExpirationIso);
    }

    _currentEntitlements = _loadFromPreferences();
    if (!_controller.isClosed) {
      _controller.add(_currentEntitlements);
    }
  }

  PremiumEntitlements _loadFromPreferences() {
    return const PremiumEntitlements(
      isPremiumActive: true,
      activePlanId: 'unlimited_free',
      expirationDate: null,
    );
  }

  void dispose() {
    _controller.close();
  }
}
