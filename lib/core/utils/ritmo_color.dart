import 'package:flutter/material.dart';

class RitmoColor {
  RitmoColor._();

  /// Parses a hex color string safely (e.g. '#RGB', '#RRGGBB', '#AARRGGBB', '0xFF...', 'RRGGBB').
  /// Returns [fallback] if [hexStr] is null, empty, or malformed.
  static Color fromHex(
    String? hexStr, {
    Color fallback = const Color(0xFF6366F1),
  }) {
    if (hexStr == null) return fallback;
    var hex = hexStr.trim().replaceAll('#', '');
    if (hex.isEmpty) return fallback;

    if (hex.startsWith('0x') || hex.startsWith('0X')) {
      hex = hex.substring(2);
    }

    if (hex.length == 3) {
      // Short form #RGB -> #RRGGBB -> FFAABB
      hex = 'FF${hex[0]}${hex[0]}${hex[1]}${hex[1]}${hex[2]}${hex[2]}';
    } else if (hex.length == 6) {
      // #RRGGBB -> #FFRRGGBB
      hex = 'FF$hex';
    }

    if (hex.length != 8) return fallback;

    try {
      final value = int.parse(hex, radix: 16);
      return Color(value);
    } catch (_) {
      return fallback;
    }
  }
}
