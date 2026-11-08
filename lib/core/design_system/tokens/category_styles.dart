import 'package:flutter/material.dart';
import '../../../features/receipts/domain/entities/receipt.dart';

/// Visual metadata (vector icon and accent color) for a receipt expense category.
///
/// Strictly uses Material vector icons — never emojis.
@immutable
class CategoryVisualStyle {
  const CategoryVisualStyle({required this.icon, required this.accentColor});

  final IconData icon;
  final Color accentColor;
}

abstract final class CategoryStyles {
  static CategoryVisualStyle forCategory(String category) {
    switch (category) {
      case ReceiptCategories.mealsAndDining:
        return const CategoryVisualStyle(
          icon: Icons.restaurant_rounded,
          accentColor: Color(0xFFF59E0B),
        );
      case ReceiptCategories.groceries:
        return const CategoryVisualStyle(
          icon: Icons.shopping_bag_rounded,
          accentColor: Color(0xFF10B981),
        );
      case ReceiptCategories.transportAndFuel:
        return const CategoryVisualStyle(
          icon: Icons.directions_car_filled_rounded,
          accentColor: Color(0xFF3B82F6),
        );
      case ReceiptCategories.officeSupplies:
        return const CategoryVisualStyle(
          icon: Icons.inventory_2_rounded,
          accentColor: Color(0xFF8B5CF6),
        );
      case ReceiptCategories.softwareAndTech:
        return const CategoryVisualStyle(
          icon: Icons.devices_rounded,
          accentColor: Color(0xFF06B6D4),
        );
      case ReceiptCategories.accommodation:
        return const CategoryVisualStyle(
          icon: Icons.hotel_rounded,
          accentColor: Color(0xFFEC4899),
        );
      case ReceiptCategories.utilitiesAndTelecom:
        return const CategoryVisualStyle(
          icon: Icons.wifi_tethering_rounded,
          accentColor: Color(0xFF6366F1),
        );
      case ReceiptCategories.healthcare:
        return const CategoryVisualStyle(
          icon: Icons.medical_services_rounded,
          accentColor: Color(0xFFEF4444),
        );
      case ReceiptCategories.professionalServices:
        return const CategoryVisualStyle(
          icon: Icons.business_center_rounded,
          accentColor: Color(0xFF14B8A6),
        );
      case ReceiptCategories.other:
      default:
        return const CategoryVisualStyle(
          icon: Icons.receipt_long_rounded,
          accentColor: Color(0xFF34D399),
        );
    }
  }
}
