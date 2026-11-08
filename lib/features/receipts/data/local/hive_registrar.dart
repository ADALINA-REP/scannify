import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/receipt.dart';

/// Binary [TypeAdapter] for [Receipt] persisted in Hive CE.
///
/// Uses field-indexed binary serialization so future schema versions can add
/// optional fields or migrate legacy field representations without data loss.
class ReceiptHiveAdapter extends TypeAdapter<Receipt> {
  static const int adapterTypeId = 1;

  @override
  final int typeId = adapterTypeId;

  @override
  Receipt read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    final rawAmountField = fields[2];
    final int amountMinorUnits;
    if (rawAmountField is int) {
      amountMinorUnits = rawAmountField;
    } else if (rawAmountField is double) {
      // Seamless migration from v1 floating-point amount to v2 integer minor units.
      amountMinorUnits = Receipt.majorToMinorUnits(rawAmountField);
    } else {
      amountMinorUnits = 0;
    }

    final int dateMs = (fields[1] as int?) ?? 0;
    final int createdMs = (fields[6] as int?) ?? dateMs;
    final int? updatedMs = fields[7] as int?;

    final rawCategory = (fields[5] as String?)?.trim() ?? '';

    final int? vatMinor = fields[8] as int?;
    final double? vatRate = (fields[9] as num?)?.toDouble();
    final String? invoiceNum = fields[10] as String?;

    return Receipt.fromMinorUnits(
      id: (fields[0] as String?) ?? '',
      date: DateTime.fromMillisecondsSinceEpoch(dateMs),
      amountMinorUnits: amountMinorUnits < 0 ? 0 : amountMinorUnits,
      merchantName: (fields[3] as String?) ?? '',
      imagePath: fields[4] as String?,
      category: rawCategory.isEmpty ? ReceiptCategories.other : rawCategory,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdMs),
      updatedAt: updatedMs != null
          ? DateTime.fromMillisecondsSinceEpoch(updatedMs)
          : null,
      vatAmountMinorUnits: vatMinor,
      vatRate: vatRate,
      invoiceNumber: invoiceNum,
    );
  }

  @override
  void write(BinaryWriter writer, Receipt obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date.millisecondsSinceEpoch)
      ..writeByte(2)
      ..write(obj.amountMinorUnits)
      ..writeByte(3)
      ..write(obj.merchantName)
      ..writeByte(4)
      ..write(obj.imagePath)
      ..writeByte(5)
      ..write(obj.category)
      ..writeByte(6)
      ..write(obj.createdAt.millisecondsSinceEpoch)
      ..writeByte(7)
      ..write(obj.updatedAt?.millisecondsSinceEpoch)
      ..writeByte(8)
      ..write(obj.vatAmountMinorUnits)
      ..writeByte(9)
      ..write(obj.vatRate)
      ..writeByte(10)
      ..write(obj.invoiceNumber);
  }
}

/// Manages cross-platform Hive CE initialization, box lifecycle, and schema migrations
/// across Android, iOS, and Web (IndexedDB).
class HiveConfig {
  HiveConfig._();

  static const int currentSchemaVersion = 2;
  static const String receiptsBoxName = 'scannify_receipts_box';
  static const String metadataBoxName = 'scannify_metadata_box';
  static const String schemaVersionKey = 'schema_version';

  static bool _isInitialized = false;

  /// Whether Hive CE has been initialized for the current runtime session.
  static bool get isInitialized => _isInitialized;

  /// Initializes Hive CE, registers adapters, opens persistent boxes, and
  /// executes any pending schema migrations.
  ///
  /// When [testDirectoryPath] is provided (for headless unit tests), uses
  /// `Hive.init(testDirectoryPath)` instead of `Hive.initFlutter()`.
  static Future<void> initialize({String? testDirectoryPath}) async {
    try {
      if (!_isInitialized) {
        if (testDirectoryPath != null) {
          Hive.init(testDirectoryPath);
        } else {
          await Hive.initFlutter();
        }
        registerAdapters();
        _isInitialized = true;
      }

      final metaBox = await Hive.openBox<dynamic>(metadataBoxName);
      final receiptsBox = await Hive.openBox<Receipt>(receiptsBoxName);

      await runMigrationsIfNeeded(metaBox: metaBox, receiptsBox: receiptsBox);

      AppLogger.info(
        'HiveConfig',
        'Hive CE initialized (schema v$currentSchemaVersion, records: ${receiptsBox.length}).',
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'HiveConfig',
        'Failed to initialize Hive CE local database.',
        e,
        stackTrace,
      );
      throw StorageException(
        message: 'Failed to initialize local database.',
        cause: e,
      );
    }
  }

  /// Registers all Hive CE [TypeAdapter]s idempotently.
  static void registerAdapters() {
    if (!Hive.isAdapterRegistered(ReceiptHiveAdapter.adapterTypeId)) {
      Hive.registerAdapter<Receipt>(ReceiptHiveAdapter());
    }
  }

  /// Executes deterministic schema migrations when upgrading from an older version.
  static Future<void> runMigrationsIfNeeded({
    required Box<dynamic> metaBox,
    required Box<Receipt> receiptsBox,
  }) async {
    final storedVersion = (metaBox.get(schemaVersionKey) as int?) ?? 0;
    if (storedVersion >= currentSchemaVersion) {
      return;
    }

    AppLogger.info(
      'HiveConfig',
      'Migrating local database schema from v$storedVersion to v$currentSchemaVersion.',
    );

    if (storedVersion < 2) {
      // Migration v0/v1 -> v2:
      // Ensure every persisted Receipt is re-written in canonical v2 minor-unit format
      // and has a valid non-empty category and merchant name fallback.
      final updates = <dynamic, Receipt>{};
      for (final key in receiptsBox.keys) {
        final existing = receiptsBox.get(key);
        if (existing != null) {
          final normalizedCategory = existing.category.trim().isEmpty
              ? ReceiptCategories.other
              : existing.category.trim();
          final normalizedMerchant = existing.merchantName.trim().isEmpty
              ? 'Unknown Merchant'
              : existing.merchantName.trim();
          final normalizedAmount = existing.amountMinorUnits < 0
              ? 0
              : existing.amountMinorUnits;

          final migrated = existing.copyWith(
            category: normalizedCategory,
            merchantName: normalizedMerchant,
            amountMinorUnits: normalizedAmount,
          );
          updates[key] = migrated;
        }
      }

      if (updates.isNotEmpty) {
        await receiptsBox.putAll(updates);
      }
    }

    await metaBox.put(schemaVersionKey, currentSchemaVersion);
  }

  /// Returns the open [Receipt] box, throwing a [StorageException] if not yet opened.
  static Box<Receipt> getReceiptsBox() {
    if (!Hive.isBoxOpen(receiptsBoxName)) {
      throw const StorageException(
        message:
            'Receipts box is not open. Call HiveConfig.initialize() first.',
      );
    }
    return Hive.box<Receipt>(receiptsBoxName);
  }

  /// Closes all open boxes and resets initialization state (useful in tests).
  static Future<void> closeAll() async {
    await Hive.close();
    _isInitialized = false;
  }
}
