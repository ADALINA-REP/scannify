import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/export/data/services/local_export_service.dart';
import '../../features/export/domain/services/export_service.dart';
import '../../features/monetization/data/services/ad_service_factory.dart';
import '../../features/monetization/data/services/default_rewarded_ad_service.dart';
import '../../features/monetization/data/services/local_premium_service.dart';
import '../../features/monetization/data/services/local_quota_service.dart';
import '../../features/monetization/domain/services/ad_service.dart';
import '../../features/monetization/domain/services/premium_service.dart';
import '../../features/monetization/domain/services/quota_service.dart';
import '../../features/ocr/data/services/image_acquisition_service.dart';
import '../../features/ocr/data/services/ocr_service_factory.dart';
import '../../features/ocr/domain/services/ocr_service.dart';
import '../../features/ocr/domain/services/receipt_parser.dart';
import '../../features/receipts/data/local/hive_registrar.dart';
import '../../features/receipts/data/repositories/local_receipt_repository.dart';
import '../../features/receipts/domain/entities/receipt.dart';
import '../../features/receipts/domain/repositories/receipt_repository.dart';
import '../storage/receipt_image_storage_service.dart';

/// Holds the resolved startup dependencies created during bootstrap.
class AppBootstrapState {
  const AppBootstrapState({
    required this.sharedPreferences,
    required this.isHiveInitialized,
    required this.isAdMobInitialized,
  });

  final SharedPreferences sharedPreferences;
  final bool isHiveInitialized;
  final bool isAdMobInitialized;
}

/// Provides the startup [AppBootstrapState] injected at root [ProviderScope].
final appBootstrapStateProvider = Provider<AppBootstrapState>((ref) {
  throw UnimplementedError(
    'appBootstrapStateProvider must be overridden in ProviderScope at startup.',
  );
});

/// Provides synchronous access to the initialized [SharedPreferences] instance.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  return ref.watch(appBootstrapStateProvider).sharedPreferences;
});

/// Provides the open Hive CE [Box] storing [Receipt] entities.
final receiptsBoxProvider = Provider<Box<Receipt>>((ref) {
  return HiveConfig.getReceiptsBox();
});

/// Provides the platform-specific [ReceiptImageStorageService] (private files on mobile, IndexedDB blob store on Web).
final receiptImageStorageServiceProvider = Provider<ReceiptImageStorageService>(
  (ref) {
    return ReceiptImageStorageService();
  },
);

/// Provides the offline-first [ReceiptRepository] bound to [LocalReceiptRepository].
final receiptRepositoryProvider = Provider<ReceiptRepository>((ref) {
  return LocalReceiptRepository(
    box: ref.watch(receiptsBoxProvider),
    imageStorageService: ref.watch(receiptImageStorageServiceProvider),
  );
});

/// Provides the stateless on-device [ReceiptParser] engine.
final receiptParserProvider = Provider<ReceiptParser>((ref) {
  return const ReceiptParser();
});

/// Provides the platform-appropriate [OcrService] (`MobileOcrService` on Android/iOS, `WebOcrService` on Web).
final ocrServiceProvider = Provider<OcrService>((ref) {
  final service = OcrServiceFactory.create(
    parser: ref.watch(receiptParserProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Provides the [ImageAcquisitionService] for camera capture, gallery import, and image cropping.
final imageAcquisitionServiceProvider = Provider<ImageAcquisitionService>((
  ref,
) {
  return DefaultImageAcquisitionService();
});

/// Provides the [PremiumService] managing subscription entitlements.
final premiumServiceProvider = Provider<PremiumService>((ref) {
  final service = LocalPremiumService(
    sharedPreferences: ref.watch(sharedPreferencesProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Provides the [QuotaService] managing the 3 daily free OCR scans and midnight resets.
final quotaServiceProvider = Provider<QuotaService>((ref) {
  final service = LocalQuotaService(
    sharedPreferences: ref.watch(sharedPreferencesProvider),
    premiumService: ref.watch(premiumServiceProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Provides the platform-specific [AdService] (`MobileAdService` on Android/iOS, `WebAdService` on Web).
final adServiceProvider = Provider<AdService>((ref) {
  final service = AdServiceFactory.create();
  ref.onDispose(service.dispose);
  return service;
});

/// Provides the [RewardedAdService] coordinating rewarded scan unlocks and rewarded exports.
final rewardedAdServiceProvider = Provider<RewardedAdService>((ref) {
  return DefaultRewardedAdService(
    adService: ref.watch(adServiceProvider),
    quotaService: ref.watch(quotaServiceProvider),
    premiumService: ref.watch(premiumServiceProvider),
  );
});

/// Provides the [ExportService] for generating and sharing CSV and PDF reports.
final exportServiceProvider = Provider<ExportService>((ref) {
  return LocalExportService(
    rewardedAdService: ref.watch(rewardedAdServiceProvider),
    imageStorageService: ref.watch(receiptImageStorageServiceProvider),
  );
});

/// Reactive stream of all locally stored receipts.
final allReceiptsStreamProvider = StreamProvider<List<Receipt>>((ref) {
  return ref.watch(receiptRepositoryProvider).watchAllReceipts();
});

/// Reactive stream of current-month receipts.
final currentMonthReceiptsStreamProvider = StreamProvider<List<Receipt>>((ref) {
  return ref.watch(receiptRepositoryProvider).watchCurrentMonthReceipts();
});

/// Reactive stream of daily OCR quota status.
final quotaStatusStreamProvider = StreamProvider<QuotaStatus>((ref) {
  return ref.watch(quotaServiceProvider).watchQuotaStatus();
});

/// Reactive stream of Premium entitlements.
final premiumEntitlementsStreamProvider = StreamProvider<PremiumEntitlements>((
  ref,
) {
  return ref.watch(premiumServiceProvider).watchEntitlements();
});
