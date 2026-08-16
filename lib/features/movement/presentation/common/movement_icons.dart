import 'package:flutter/material.dart';

/// نگاشت کلیدهای آیکون متنی به آیکون‌های متریال فلاتر برای ماژول حرکت
abstract final class MovementIcons {
  static const Map<String, IconData> _icons = {
    'directions_run': Icons.directions_run_rounded,
    'directions_walk': Icons.directions_walk_rounded,
    'directions_bike': Icons.directions_bike_rounded,
    'pool': Icons.pool_rounded,
    'fitness_center': Icons.fitness_center_rounded,
    'self_improvement': Icons.self_improvement_rounded,
    'sports_tennis': Icons.sports_tennis_rounded,
    'sports_soccer': Icons.sports_soccer_rounded,
    'sports_kabaddi': Icons.sports_kabaddi_rounded,
    'terrain': Icons.terrain_rounded,
    'sports_score': Icons.sports_score_rounded,
    'sports': Icons.sports_rounded,
    'timer': Icons.timer_rounded,
    'speed': Icons.speed_rounded,
    'favorite': Icons.favorite_rounded,
    'local_fire_department': Icons.local_fire_department_rounded,
  };

  static IconData fromKey(String? key) {
    if (key == null) return Icons.directions_run_rounded;
    return _icons[key.trim()] ?? Icons.directions_run_rounded;
  }
}
