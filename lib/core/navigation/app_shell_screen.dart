import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/dashboard/presentation/screens/home_dashboard_screen.dart';
import '../../features/export/presentation/screens/export_screen.dart';
import '../../features/ocr/presentation/screens/scanner_screen.dart';
import '../../features/receipts/domain/entities/receipt.dart';
import '../../features/receipts/presentation/screens/receipt_details_screen.dart';
import '../../features/receipts/presentation/screens/receipt_history_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../design_system/design_system.dart';
import '../providers/core_providers.dart';
import '../settings/app_preferences.dart';

/// Root navigation shell connecting Dashboard, History, Scanner, Export, and Settings.
class AppShellScreen extends ConsumerStatefulWidget {
  const AppShellScreen({super.key});

  @override
  ConsumerState<AppShellScreen> createState() => _AppShellScreenState();
}

class _AppShellScreenState extends ConsumerState<AppShellScreen> {
  ScannifyNavTab _currentTab = ScannifyNavTab.dashboard;
  final List<ScannifyNavTab> _tabHistory = <ScannifyNavTab>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(rewardedAdServiceProvider).warmupAds());
    });
  }

  Future<void> _openScanner() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const ScannerScreen()),
    );
  }

  Future<void> _openReceiptDetails(Receipt receipt) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ReceiptDetailsScreen(receiptId: receipt.id),
      ),
    );
  }

  void _selectTab(ScannifyNavTab tab) {
    if (_currentTab == tab) return;
    setState(() {
      _tabHistory.add(_currentTab);
      _currentTab = tab;
    });
  }

  void _handleBack() {
    if (_tabHistory.isNotEmpty) {
      final previousTab = _tabHistory.removeLast();
      setState(() {
        _currentTab = previousTab;
      });
    } else if (_currentTab != ScannifyNavTab.dashboard) {
      setState(() {
        _currentTab = ScannifyNavTab.dashboard;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeDashboardScreen(
        onScanReceiptPressed: _openScanner,
        onReceiptTapped: _openReceiptDetails,
        onViewAllHistoryPressed: () => _selectTab(ScannifyNavTab.history),
        onSettingsPressed: () => _selectTab(ScannifyNavTab.settings),
      ),
      ReceiptHistoryScreen(
        onReceiptTapped: _openReceiptDetails,
        onScanReceiptPressed: _openScanner,
        onBackPressed: _handleBack,
      ),
      ExportScreen(
        onBackPressed: _handleBack,
      ),
      SettingsScreen(
        onBackPressed: _handleBack,
      ),
    ];

    return PopScope(
      canPop: _currentTab == ScannifyNavTab.dashboard && _tabHistory.isEmpty,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        body: IndexedStack(index: _currentTab.index, children: pages),
        bottomNavigationBar: CustomBottomNavigation(
          currentTab: _currentTab,
          onTabSelected: _selectTab,
          onScanPressed: _openScanner,
          strings: ref.watch(appPreferencesProvider).strings,
        ),
      ),
    );
  }
}
