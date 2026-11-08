import 'package:meta/meta.dart';
import '../../../../core/errors/app_exception.dart';

/// Standard receipt categories supported by Scannify.
abstract final class ReceiptCategories {
  static const String mealsAndDining = 'Meals & Dining';
  static const String groceries = 'Groceries';
  static const String transportAndFuel = 'Transport & Fuel';
  static const String officeSupplies = 'Office Supplies';
  static const String softwareAndTech = 'Software & Tech';
  static const String accommodation = 'Accommodation';
  static const String utilitiesAndTelecom = 'Utilities & Telecom';
  static const String healthcare = 'Healthcare';
  static const String professionalServices = 'Professional Services';
  static const String other = 'Other';

  static const List<String> all = <String>[
    mealsAndDining,
    groceries,
    transportAndFuel,
    officeSupplies,
    softwareAndTech,
    accommodation,
    utilitiesAndTelecom,
    healthcare,
    professionalServices,
    other,
  ];
}

/// Core domain model representing a scanned or manually entered expense receipt.
///
/// Financial amounts are stored internally as integer minor currency units
/// ([amountMinorUnits], e.g., cents where `1250` = `12.50`) to eliminate
/// IEEE 754 floating-point rounding errors across aggregations and exports.
@immutable
class Receipt {
  /// Creates a [Receipt] from a major-unit [amount] (e.g., `12.50`).
  ///
  /// Internally converts [amount] into exact integer minor units (`cents`).
  factory Receipt({
    required String id,
    required DateTime date,
    required double amount,
    required String merchantName,
    String? imagePath,
    required String category,
    required DateTime createdAt,
    DateTime? updatedAt,
    double? vatAmount,
    int? vatAmountMinorUnits,
    double? vatRate,
    String? invoiceNumber,
  }) {
    final resolvedVatMinor = vatAmountMinorUnits ??
        (vatAmount != null ? majorToMinorUnits(vatAmount) : null);

    return Receipt.fromMinorUnits(
      id: id,
      date: date,
      amountMinorUnits: majorToMinorUnits(amount),
      merchantName: merchantName,
      imagePath: imagePath,
      category: category,
      createdAt: createdAt,
      updatedAt: updatedAt,
      vatAmountMinorUnits: resolvedVatMinor,
      vatRate: vatRate,
      invoiceNumber: invoiceNumber,
    );
  }

  /// Creates a [Receipt] directly from integer minor currency units ([amountMinorUnits]).
  const Receipt.fromMinorUnits({
    required this.id,
    required this.date,
    required this.amountMinorUnits,
    required this.merchantName,
    this.imagePath,
    required this.category,
    required this.createdAt,
    this.updatedAt,
    this.vatAmountMinorUnits,
    this.vatRate,
    this.invoiceNumber,
  });

  /// Unique identifier (UUID v4).
  final String id;

  /// Transaction date printed on the receipt.
  final DateTime date;

  /// Canonical monetary value in integer minor currency units (e.g. euro cents).
  final int amountMinorUnits;

  /// Merchant or vendor name.
  final String merchantName;

  /// Optional application-private file path or storage key for the receipt image.
  /// Never stores raw image bytes in the database.
  final String? imagePath;

  /// Expense category identifier.
  final String category;

  /// Timestamp when the receipt record was created locally.
  final DateTime createdAt;

  /// Timestamp when the receipt record was last modified locally.
  final DateTime? updatedAt;

  /// Extracted or validated VAT amount in integer minor units (cents).
  /// Null if not extracted/specified.
  final int? vatAmountMinorUnits;

  /// Detected VAT percentage rate (e.g., `20.0` for 20%).
  final double? vatRate;

  /// Invoice or receipt identification number (e.g. `FAC-2026-001`).
  final String? invoiceNumber;

  /// VAT amount in major currency units (e.g. `20.00`).
  double? get vatAmount =>
      vatAmountMinorUnits != null ? minorToMajorUnits(vatAmountMinorUnits!) : null;

  /// Effective deductible VAT in minor units (cents). Returns [vatAmountMinorUnits]
  /// if verified; otherwise computes a realistic estimation based on standard tax rates.
  int get effectiveVatMinorUnits {
    if (vatAmountMinorUnits != null) {
      return vatAmountMinorUnits!.clamp(0, amountMinorUnits);
    }
    final rate = switch (category) {
      ReceiptCategories.mealsAndDining => 0.10,
      ReceiptCategories.transportAndFuel => 0.10,
      ReceiptCategories.accommodation => 0.10,
      ReceiptCategories.groceries => 0.055,
      _ => 0.20,
    };
    return (amountMinorUnits * rate / (1.0 + rate)).round().clamp(0, amountMinorUnits);
  }

  /// Subtotal excluding tax (HT) in minor units (cents).
  int get subtotalHtMinorUnits =>
      (amountMinorUnits - effectiveVatMinorUnits).clamp(0, amountMinorUnits);

  /// Subtotal excluding tax (HT) in major currency units.
  double get subtotalHt => minorToMajorUnits(subtotalHtMinorUnits);

  /// Effective deductible VAT in major currency units.
  double get effectiveVat => minorToMajorUnits(effectiveVatMinorUnits);

  /// Monetary amount in major currency units (e.g., `12.50`), derived
  /// deterministically from [amountMinorUnits].
  double get amount => minorToMajorUnits(amountMinorUnits);

  /// Converts major currency units (e.g. `12.50`) to integer minor units (`1250`).
  static int majorToMinorUnits(double majorAmount) {
    if (majorAmount.isNaN || majorAmount.isInfinite) {
      throw const ValidationException(
        message: 'Receipt amount must be a finite number.',
      );
    }
    return (majorAmount * 100.0).round();
  }

  /// Converts integer minor currency units (`1250`) to major currency units (`12.50`).
  static double minorToMajorUnits(int minorUnits) {
    return minorUnits / 100.0;
  }

  /// Validates domain invariants before persistence.
  void validate() {
    if (id.trim().isEmpty) {
      throw const ValidationException(message: 'Receipt ID cannot be empty.');
    }
    if (merchantName.trim().isEmpty) {
      throw const ValidationException(
        message: 'Merchant name cannot be empty.',
      );
    }
    if (amountMinorUnits < 0) {
      throw const ValidationException(
        message: 'Receipt amount cannot be negative.',
      );
    }
    if (category.trim().isEmpty) {
      throw const ValidationException(
        message: 'Receipt category cannot be empty.',
      );
    }
  }

  /// Returns a copy of this [Receipt] with the given fields replaced.
  Receipt copyWith({
    String? id,
    DateTime? date,
    double? amount,
    int? amountMinorUnits,
    String? merchantName,
    String? imagePath,
    bool clearImagePath = false,
    String? category,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? vatAmountMinorUnits,
    bool clearVat = false,
    double? vatRate,
    String? invoiceNumber,
  }) {
    final resolvedMinorUnits =
        amountMinorUnits ??
        (amount != null ? majorToMinorUnits(amount) : this.amountMinorUnits);

    return Receipt.fromMinorUnits(
      id: id ?? this.id,
      date: date ?? this.date,
      amountMinorUnits: resolvedMinorUnits,
      merchantName: merchantName ?? this.merchantName,
      imagePath: clearImagePath ? null : (imagePath ?? this.imagePath),
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      vatAmountMinorUnits:
          clearVat ? null : (vatAmountMinorUnits ?? this.vatAmountMinorUnits),
      vatRate: vatRate ?? this.vatRate,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
    );
  }

  /// Serializes this [Receipt] to a schema-versioned map for migration or backup.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'dateIso': date.toIso8601String(),
      'amountMinorUnits': amountMinorUnits,
      'merchantName': merchantName,
      'imagePath': imagePath,
      'category': category,
      'createdAtIso': createdAt.toIso8601String(),
      'updatedAtIso': updatedAt?.toIso8601String(),
      'vatAmountMinorUnits': vatAmountMinorUnits,
      'vatRate': vatRate,
      'invoiceNumber': invoiceNumber,
    };
  }

  /// Deserializes a [Receipt] from a map, supporting both minor-unit (`v2`)
  /// and legacy floating-point (`v1`) representations.
  factory Receipt.fromMap(Map<dynamic, dynamic> map) {
    final int minorUnits;
    if (map['amountMinorUnits'] is int) {
      minorUnits = map['amountMinorUnits'] as int;
    } else if (map['amount'] is num) {
      minorUnits = majorToMinorUnits((map['amount'] as num).toDouble());
    } else {
      minorUnits = 0;
    }

    return Receipt.fromMinorUnits(
      id: (map['id'] as String?) ?? '',
      date: DateTime.parse(map['dateIso'] as String),
      amountMinorUnits: minorUnits,
      merchantName: (map['merchantName'] as String?) ?? '',
      imagePath: map['imagePath'] as String?,
      category: (map['category'] as String?) ?? ReceiptCategories.other,
      createdAt: DateTime.parse(map['createdAtIso'] as String),
      updatedAt: map['updatedAtIso'] != null
          ? DateTime.parse(map['updatedAtIso'] as String)
          : null,
      vatAmountMinorUnits: map['vatAmountMinorUnits'] as int?,
      vatRate: (map['vatRate'] as num?)?.toDouble(),
      invoiceNumber: map['invoiceNumber'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Receipt &&
        other.id == id &&
        other.date == date &&
        other.amountMinorUnits == amountMinorUnits &&
        other.merchantName == merchantName &&
        other.imagePath == imagePath &&
        other.category == category &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.vatAmountMinorUnits == vatAmountMinorUnits &&
        other.vatRate == vatRate &&
        other.invoiceNumber == invoiceNumber;
  }

  @override
  int get hashCode => Object.hash(
    id,
    date,
    amountMinorUnits,
    merchantName,
    imagePath,
    category,
    createdAt,
    updatedAt,
    vatAmountMinorUnits,
    vatRate,
    invoiceNumber,
  );

  @override
  String toString() =>
      'Receipt(id: $id, date: ${date.toIso8601String()}, category: $category)';
}
