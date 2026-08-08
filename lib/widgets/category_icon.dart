import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Maps category names to modern Lucide vector icons.
/// Falls back to emoji string if custom or unknown.
class CategoryIcon extends StatelessWidget {
  final String categoryName;
  final String? emojiFallback;
  final double size;
  final Color? color;

  const CategoryIcon({
    super.key,
    required this.categoryName,
    this.emojiFallback,
    this.size = 18,
    this.color,
  });

  IconData? _getLucideIcon(String name) {
    switch (name.trim().toLowerCase()) {
      case 'food':
        return LucideIcons.utensils;
      case 'travel':
        return LucideIcons.car;
      case 'shopping':
        return LucideIcons.shoppingBag;
      case 'bills':
        return LucideIcons.receiptText;
      case 'recharge':
        return LucideIcons.smartphone;
      case 'rent':
        return LucideIcons.house;
      case 'grocery':
        return LucideIcons.shoppingCart;
      case 'medical':
      case 'health':
        return LucideIcons.heartPulse;
      case 'entertainment':
        return LucideIcons.clapperboard;
      case 'salary':
        return LucideIcons.briefcase;
      case 'bonus':
      case 'gift':
        return LucideIcons.gift;
      case 'other income':
      case 'other':
        return LucideIcons.wallet;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lucideIcon = _getLucideIcon(categoryName);
    if (lucideIcon != null) {
      return Icon(
        lucideIcon,
        size: size,
        color: color ?? Theme.of(context).colorScheme.primary,
      );
    }
    return Text(
      emojiFallback ?? '📦',
      style: TextStyle(fontSize: size),
    );
  }
}
