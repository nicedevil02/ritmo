import 'package:flutter/foundation.dart';
import 'package:ritmo/core/domain/realm/budgets/zone_budget.dart';

/// Single realm metrics within a weekly report (F-15).
@immutable
class ZoneReportItem {
  const ZoneReportItem({
    required this.zoneId,
    required this.name,
    required this.colorHex,
    required this.icon,
    required this.totalMinutes,
    required this.sessionCount,
    this.previousWeekMinutes,
    this.budget,
  });

  final String zoneId;
  final String name;
  final String colorHex;
  final String icon;
  final int totalMinutes;
  final int sessionCount;
  final int? previousWeekMinutes;
  final ZoneBudget? budget;

  int get hours => totalMinutes ~/ 60;
  int get minutesRemainder => totalMinutes % 60;

  /// Time difference compared to the previous week in minutes (positive = more time spent).
  int? get diffMinutesFromPreviousWeek =>
      previousWeekMinutes != null ? totalMinutes - previousWeekMinutes! : null;

  /// Progress ratio towards minimum target budget (0.0 to 1.0+).
  double? get minBudgetProgress {
    final min = budget?.minMinutes;
    if (min == null || min <= 0) return null;
    return totalMinutes / min;
  }

  /// True if maximum budget limit is exceeded.
  bool get isMaxBudgetExceeded {
    final max = budget?.maxMinutes;
    if (max == null || max <= 0) return false;
    return totalMinutes > max;
  }
}

/// Comprehensive weekly presence report across all realms (F-15).
@immutable
class WeeklyRealmReport {
  const WeeklyRealmReport({
    required this.startRange,
    required this.endRange,
    required this.items,
  });

  final DateTime startRange;
  final DateTime endRange;
  final List<ZoneReportItem> items;

  int get totalTrackedMinutes =>
      items.fold(0, (sum, item) => sum + item.totalMinutes);

  int get totalSessions =>
      items.fold(0, (sum, item) => sum + item.sessionCount);

  ZoneReportItem? get topRealm => items.isNotEmpty ? items.first : null;

  /// Share of time percentage for a specific realm (0.0 to 1.0).
  double percentageFor(ZoneReportItem item) {
    final total = totalTrackedMinutes;
    if (total <= 0) return 0.0;
    return (item.totalMinutes / total).clamp(0.0, 1.0);
  }
}
