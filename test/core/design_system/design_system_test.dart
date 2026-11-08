import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scannify/core/design_system/design_system.dart';
import 'package:scannify/core/localization/app_localizations.dart';
import 'package:scannify/core/settings/app_preferences.dart';
import 'package:scannify/features/monetization/domain/services/quota_service.dart';
import 'package:scannify/features/receipts/domain/entities/receipt.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Phase 3 — Theme & Color Palette Specification', () {
    test('Dark theme matches mandatory FinTech hex specification', () {
      final dark = AppTheme.darkTheme;
      final colors = dark.extension<ScannifyThemeColors>()!;

      expect(colors.primaryBackground, const Color(0xFF0B0D0C));
      expect(colors.secondaryBackground, const Color(0xFF121614));
      expect(colors.cardBackground, const Color(0xFF1B211E));
      expect(colors.primaryEmerald, const Color(0xFF10B981));
      expect(colors.secondaryEmerald, const Color(0xFF34D399));
      expect(colors.primaryText, const Color(0xFFF5F7F5));
      expect(colors.secondaryText, const Color(0xFFA1AAA4));
      expect(colors.border, const Color(0xFF29332D));
      expect(colors.isDark, isTrue);
    });

    test('Light theme provides complete harmonious FinTech tokens', () {
      final light = AppTheme.lightTheme;
      final colors = light.extension<ScannifyThemeColors>()!;

      expect(colors.isDark, isFalse);
      expect(colors.cardBackground, const Color(0xFFFFFFFF));
      expect(colors.secondaryEmerald, const Color(0xFF10B981));
    });
  });

  group('Phase 3 — AppPreferences & Localization (EN / FR)', () {
    test(
      'Persists ThemeMode, Currency, and Language in SharedPreferences',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final prefs = await SharedPreferences.getInstance();
        final notifier = AppPreferencesNotifier(prefs);

        // Default is Dark Mode, EUR, English
        expect(notifier.state.themeMode, ThemeMode.dark);
        expect(notifier.state.currency, SupportedCurrency.eur);
        expect(notifier.state.language, AppLanguage.english);

        await notifier.setThemeMode(ThemeMode.light);
        await notifier.setCurrency(SupportedCurrency.usd);
        await notifier.setLanguage(AppLanguage.french);

        expect(notifier.state.themeMode, ThemeMode.light);
        expect(notifier.state.currency, SupportedCurrency.usd);
        expect(notifier.state.language, AppLanguage.french);
        expect(notifier.state.strings.navDashboard, 'Tableau de bord');
      },
    );
  });

  group('Phase 3 — Reusable UI Components Widget Validation', () {
    testWidgets(
      'Renders ExpenseSummaryCard, ReceiptCard, ScanButton, CategoryChip, and CustomBottomNavigation',
      (WidgetTester tester) async {
        bool scanTapped = false;
        ScannifyNavTab selectedTab = ScannifyNavTab.dashboard;

        final sampleReceipt = Receipt(
          id: 'r-100',
          date: DateTime(2026, 10, 24),
          amount: 48.90,
          merchantName: 'Bistrot Parisien',
          category: ReceiptCategories.mealsAndDining,
          createdAt: DateTime(2026, 10, 24),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              appBar: const CustomAppBar(
                title: 'Scannify',
                showBrandLogo: true,
              ),
              body: SingleChildScrollView(
                child: Column(
                  children: <Widget>[
                    ExpenseSummaryCard(
                      monthLabel: 'October 2026',
                      totalLabel: 'Monthly Expenses',
                      totalMinorUnits: 4890,
                      amountFormatter: (int minor) =>
                          '${(minor / 100).toStringAsFixed(2)} €',
                      receiptCountLabel: '1 receipt',
                      percentageChangeFromPreviousMonth: -12.5,
                    ),
                    ReceiptCard(
                      receipt: sampleReceipt,
                      formattedAmount: '48.90 €',
                      onTap: () {},
                    ),
                    CategoryChip(
                      category: ReceiptCategories.mealsAndDining,
                      isSelected: true,
                      onSelected: () {},
                    ),
                    ScanButton(
                      label: 'Scan Receipt',
                      badgeText: '3/3 free',
                      onPressed: () {
                        scanTapped = true;
                      },
                    ),
                    const PremiumCard(
                      title: 'Scannify Pro',
                      subtitle: 'Unlock unlimited power',
                      benefits: <String>[
                        'Unlimited OCR scans',
                        'CSV & PDF exports without ads',
                      ],
                    ),
                  ],
                ),
              ),
              bottomNavigationBar: CustomBottomNavigation(
                currentTab: selectedTab,
                onTabSelected: (ScannifyNavTab tab) {
                  selectedTab = tab;
                },
                onScanPressed: () {
                  scanTapped = true;
                },
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('October 2026'), findsOneWidget);
        expect(find.text('1 receipt'), findsOneWidget);
        expect(find.text('Bistrot Parisien'), findsOneWidget);
        expect(find.text('48.90 €'), findsWidgets);
        expect(find.text('Scan Receipt'), findsOneWidget);
        expect(find.text('Scannify Pro'), findsOneWidget);

        await tester.tap(find.text('Scan Receipt'));
        await tester.pump();
        expect(scanTapped, isTrue);

        await tester.tap(find.text('History'));
        await tester.pump();
        expect(selectedTab, ScannifyNavTab.history);
      },
    );

    testWidgets(
      'Renders RewardedAdDialog with exact required quota message and action buttons',
      (WidgetTester tester) async {
        bool watchPressed = false;
        bool laterPressed = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: RewardedAdDialog(
                onWatchVideo: () => watchPressed = true,
                onMaybeLater: () => laterPressed = true,
              ),
            ),
          ),
        );

        expect(find.text(QuotaService.quotaExhaustedMessage), findsOneWidget);
        expect(find.text('Watch Video'), findsOneWidget);
        expect(find.text('Maybe Later'), findsOneWidget);

        await tester.tap(find.text('Watch Video'));
        await tester.pump();
        expect(watchPressed, isTrue);

        await tester.tap(find.text('Maybe Later'));
        await tester.pump();
        expect(laterPressed, isTrue);
      },
    );

    testWidgets('Renders EmptyState and LoadingSkeleton cleanly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Column(
              children: <Widget>[
                const Expanded(
                  child: EmptyState(
                    title: 'No receipts yet',
                    subtitle: 'Scan your first receipt to begin.',
                  ),
                ),
                LoadingSkeleton.list(itemCount: 2),
              ],
            ),
          ),
        ),
      );

      expect(find.text('No receipts yet'), findsOneWidget);
      expect(find.byType(LoadingSkeleton), findsNWidgets(2));
    });
  });
}
