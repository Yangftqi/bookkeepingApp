import 'package:flutter/material.dart';

class ColorUtils {
  static Color fromHex(String? hex, {Color fallback = const Color(0xFF4F46E5)}) {
    if (hex == null || hex.trim().isEmpty) return fallback;
    var cleaned = hex.trim().replaceFirst('#', '');
    if (cleaned.length == 6) {
      cleaned = 'FF$cleaned';
    }
    if (cleaned.length != 8) return fallback;
    final parsed = int.tryParse(cleaned, radix: 16);
    if (parsed == null) return fallback;
    return Color(parsed);
  }

  static String toHex(Color color) {
    final val = color.value.toRadixString(16).padLeft(8, '0').toUpperCase();
    return '#$val';
  }

  static const List<String> defaultCategoryPalette = [
    '#FFEF4444',
    '#FF10B981',
    '#FF8B5CF6',
    '#FF3B82F6',
    '#FFF59E0B',
    '#FFEC4899',
    '#FF14B8A6',
    '#FFF97316',
    '#FF6366F1',
    '#FF84CC16',
    '#FF06B6D4',
    '#FFA855F7',
  ];
}
