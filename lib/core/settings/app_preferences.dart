import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../localization/app_localizations.dart';
import '../providers/core_providers.dart';

/// Supported currencies for display and export.
enum SupportedCurrency {
  eur(
    code: 'EUR',
    symbol: '€',
    name: 'Euro',
    region: 'European Union',
    flagEmoji: '🇪🇺',
    symbolAfterAmount: true,
  ),
  usd(
    code: 'USD',
    symbol: r'$',
    name: 'US Dollar',
    region: 'United States',
    flagEmoji: '🇺🇸',
    symbolAfterAmount: false,
  ),
  gbp(
    code: 'GBP',
    symbol: '£',
    name: 'British Pound',
    region: 'United Kingdom',
    flagEmoji: '🇬🇧',
    symbolAfterAmount: false,
  ),
  chf(
    code: 'CHF',
    symbol: 'CHF',
    name: 'Swiss Franc',
    region: 'Switzerland',
    flagEmoji: '🇨🇭',
    symbolAfterAmount: true,
  ),
  cad(
    code: 'CAD',
    symbol: r'CA$',
    name: 'Canadian Dollar',
    region: 'Canada',
    flagEmoji: '🇨🇦',
    symbolAfterAmount: false,
  ),
  mad(
    code: 'MAD',
    symbol: 'DH',
    name: 'Moroccan Dirham',
    region: 'Morocco',
    flagEmoji: '🇲🇦',
    symbolAfterAmount: true,
  ),
  sar(
    code: 'SAR',
    symbol: 'SAR',
    name: 'Saudi Riyal',
    region: 'Saudi Arabia',
    flagEmoji: '🇸🇦',
    symbolAfterAmount: true,
  ),
  aed(
    code: 'AED',
    symbol: 'AED',
    name: 'UAE Dirham',
    region: 'United Arab Emirates',
    flagEmoji: '🇦🇪',
    symbolAfterAmount: true,
  ),
  dzd(
    code: 'DZD',
    symbol: 'DA',
    name: 'Algerian Dinar',
    region: 'Algeria',
    flagEmoji: '🇩🇿',
    symbolAfterAmount: true,
  ),
  tnd(
    code: 'TND',
    symbol: 'DT',
    name: 'Tunisian Dinar',
    region: 'Tunisia',
    flagEmoji: '🇹🇳',
    symbolAfterAmount: true,
  ),
  egp(
    code: 'EGP',
    symbol: r'E£',
    name: 'Egyptian Pound',
    region: 'Egypt',
    flagEmoji: '🇪🇬',
    symbolAfterAmount: true,
  ),
  jpy(
    code: 'JPY',
    symbol: '¥',
    name: 'Japanese Yen',
    region: 'Japan',
    flagEmoji: '🇯🇵',
    symbolAfterAmount: false,
  ),
  aud(
    code: 'AUD',
    symbol: r'AU$',
    name: 'Australian Dollar',
    region: 'Australia',
    flagEmoji: '🇦🇺',
    symbolAfterAmount: false,
  ),
  brl(
    code: 'BRL',
    symbol: r'R$',
    name: 'Brazilian Real',
    region: 'Brazil',
    flagEmoji: '🇧🇷',
    symbolAfterAmount: false,
  ),
  mxn(
    code: 'MXN',
    symbol: r'MX$',
    name: 'Mexican Peso',
    region: 'Mexico',
    flagEmoji: '🇲🇽',
    symbolAfterAmount: false,
  ),
  inr(
    code: 'INR',
    symbol: '₹',
    name: 'Indian Rupee',
    region: 'India',
    flagEmoji: '🇮🇳',
    symbolAfterAmount: false,
  ),
  sek(
    code: 'SEK',
    symbol: 'kr',
    name: 'Swedish Krona',
    region: 'Sweden',
    flagEmoji: '🇸🇪',
    symbolAfterAmount: true,
  ),
  nok(
    code: 'NOK',
    symbol: 'kr',
    name: 'Norwegian Krone',
    region: 'Norway',
    flagEmoji: '🇳🇴',
    symbolAfterAmount: true,
  ),
  dkk(
    code: 'DKK',
    symbol: 'kr',
    name: 'Danish Krone',
    region: 'Denmark',
    flagEmoji: '🇩🇰',
    symbolAfterAmount: true,
  ),
  pln(
    code: 'PLN',
    symbol: 'zł',
    name: 'Polish Zloty',
    region: 'Poland',
    flagEmoji: '🇵🇱',
    symbolAfterAmount: true,
  ),
  try_(
    code: 'TRY',
    symbol: '₺',
    name: 'Turkish Lira',
    region: 'Turkey',
    flagEmoji: '🇹🇷',
    symbolAfterAmount: true,
  ),
  zar(
    code: 'ZAR',
    symbol: 'R',
    name: 'South African Rand',
    region: 'South Africa',
    flagEmoji: '🇿🇦',
    symbolAfterAmount: false,
  ),
  sgd(
    code: 'SGD',
    symbol: r'SG$',
    name: 'Singapore Dollar',
    region: 'Singapore',
    flagEmoji: '🇸🇬',
    symbolAfterAmount: false,
  );

  const SupportedCurrency({
    required this.code,
    required this.symbol,
    required this.name,
    required this.region,
    required this.flagEmoji,
    required this.symbolAfterAmount,
  });

  final String code;
  final String symbol;
  final String name;
  final String region;
  final String flagEmoji;
  final bool symbolAfterAmount;

  static SupportedCurrency fromCode(String? code) {
    for (final c in SupportedCurrency.values) {
      if (c.code.toLowerCase() == code?.toLowerCase()) {
        return c;
      }
    }
    return SupportedCurrency.eur;
  }

  /// Formats integer minor currency units (e.g. `1250` -> `12,50 €` or `$12.50`).
  String formatMinorUnits(
    int minorUnits, {
    AppLanguage language = AppLanguage.english,
  }) {
    final majorValue = minorUnits / 100.0;
    final effectiveLang = language.effectiveLanguage;
    final localeName = switch (effectiveLang) {
      AppLanguage.french => 'fr_FR',
      AppLanguage.spanish => 'es_ES',
      AppLanguage.german => 'de_DE',
      AppLanguage.italian => 'it_IT',
      AppLanguage.portuguese => 'pt_PT',
      AppLanguage.arabic => 'ar_SA',
      _ => 'en_US',
    };
    final numberFormat = NumberFormat.currency(
      locale: localeName,
      symbol: '',
      decimalDigits: 2,
    );
    final formattedNumber = numberFormat.format(majorValue).trim();
    if (symbolAfterAmount) {
      return '$formattedNumber $symbol';
    }
    return '$symbol$formattedNumber';
  }
}

/// Immutable user preferences state (ThemeMode, Currency, and Language).
@immutable
class AppPreferencesState {
  const AppPreferencesState({
    this.themeMode = ThemeMode.dark,
    this.currency = SupportedCurrency.eur,
    this.language = AppLanguage.english,
  });

  final ThemeMode themeMode;
  final SupportedCurrency currency;
  final AppLanguage language;

  AppStrings get strings => AppStrings(language);

  String formatMinorUnits(int minorUnits) =>
      currency.formatMinorUnits(minorUnits, language: language);

  AppPreferencesState copyWith({
    ThemeMode? themeMode,
    SupportedCurrency? currency,
    AppLanguage? language,
  }) {
    return AppPreferencesState(
      themeMode: themeMode ?? this.themeMode,
      currency: currency ?? this.currency,
      language: language ?? this.language,
    );
  }
}

/// Controller persisting user theme, currency, and language selections in [SharedPreferences].
class AppPreferencesNotifier extends StateNotifier<AppPreferencesState> {
  AppPreferencesNotifier(this._prefs) : super(_loadInitial(_prefs));

  static const String _keyThemeMode = 'scannify_pref_theme_mode';
  static const String _keyCurrency = 'scannify_pref_currency';
  static const String _keyLanguage = 'scannify_pref_language';

  final SharedPreferences _prefs;

  static AppPreferencesState _loadInitial(SharedPreferences prefs) {
    final rawTheme = prefs.getString(_keyThemeMode);
    final ThemeMode resolvedThemeMode = switch (rawTheme) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark, // Default Dark Theme per design system specification
    };

    final currency = SupportedCurrency.fromCode(prefs.getString(_keyCurrency));
    final language = AppLanguage.fromCode(prefs.getString(_keyLanguage));

    return AppPreferencesState(
      themeMode: resolvedThemeMode,
      currency: currency,
      language: language,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final raw = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
      ThemeMode.dark => 'dark',
    };
    await _prefs.setString(_keyThemeMode, raw);
    state = state.copyWith(themeMode: mode);
  }

  Future<void> setCurrency(SupportedCurrency currency) async {
    await _prefs.setString(_keyCurrency, currency.code);
    state = state.copyWith(currency: currency);
  }

  Future<void> setLanguage(AppLanguage language) async {
    await _prefs.setString(_keyLanguage, language.code);
    state = state.copyWith(language: language);
  }
}

/// Riverpod provider exposing [AppPreferencesState] and its mutator methods.
final appPreferencesProvider =
    StateNotifierProvider<AppPreferencesNotifier, AppPreferencesState>((ref) {
      return AppPreferencesNotifier(ref.watch(sharedPreferencesProvider));
    });
