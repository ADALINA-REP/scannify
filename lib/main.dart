import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/design_system/theme/app_theme.dart';
import 'core/logging/app_logger.dart';
import 'core/monetization/admob_initializer.dart';
import 'core/navigation/app_shell_screen.dart';
import 'core/providers/core_providers.dart';
import 'core/settings/app_preferences.dart';
import 'features/receipts/data/local/hive_registrar.dart';

/// Bootstraps Scannify's core technical foundation:
/// 1. Centralized error handling (FlutterError & PlatformDispatcher).
/// 2. Cross-platform Hive CE local database & schema migrations.
/// 3. SharedPreferences local persistence & Intl date formatting data.
/// 4. Conditional AdMob initialization (Android & iOS only; skipped on Web).
Future<AppBootstrapState> bootstrapScannify() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    AppLogger.error(
      'FlutterError',
      details.exceptionAsString(),
      details.exception,
      details.stack,
    );
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    AppLogger.error(
      'PlatformDispatcher',
      'Unhandled asynchronous error.',
      error,
      stack,
    );
    return true;
  };

  await initializeDateFormatting();
  await HiveConfig.initialize();
  final sharedPreferences = await SharedPreferences.getInstance();
  final isAdMobInitialized = await AdMobInitializer.initialize();

  return AppBootstrapState(
    sharedPreferences: sharedPreferences,
    isHiveInitialized: HiveConfig.isInitialized,
    isAdMobInitialized: isAdMobInitialized,
  );
}

Future<void> main() async {
  final bootstrapState = await bootstrapScannify();

  runApp(
    ProviderScope(
      overrides: <Override>[
        appBootstrapStateProvider.overrideWithValue(bootstrapState),
      ],
      child: const ScannifyApp(),
    ),
  );
}

/// Root [MaterialApp] widget reactive to theme mode, currency, and language preferences.
class ScannifyApp extends ConsumerWidget {
  const ScannifyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(appPreferencesProvider);

    return MaterialApp(
      title: 'Scannify',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: prefs.themeMode,
      locale: prefs.language.locale,
      supportedLocales: const <Locale>[
        Locale('en'),
        Locale('fr'),
        Locale('es'),
        Locale('de'),
        Locale('it'),
        Locale('pt'),
        Locale('ar'),
      ],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AppShellScreen(),
    );
  }
}
