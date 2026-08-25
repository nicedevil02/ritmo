// lib/features/supplementary_sports/movement/domain/week_slot_resolver.dart

library;

import 'package:ritmo/features/supplementary_sports/movement/domain/movement_slot_override.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/week_plan_item.dart';

/// A concrete occurrence of a movement routine on one calendar day.
class PlannedSlot {
  const PlannedSlot({
    required this.routineId,
    required this.weekdaySat0,
    required this.dateIso,
    required this.time,
    this.title = '',
    this.emoji = '🏃',
    this.reminderMinutes = 0,
    this.isLight = false,
    this.isOverride = false,
  });

  final String routineId;
  final Sat0Weekday weekdaySat0;
  final String dateIso;
  final String time;
  final String title;
  final String emoji;
  final int reminderMinutes;
  final bool isLight;
  final bool isOverride;

  PlannedSlot copyWith({
    Sat0Weekday? weekdaySat0,
    String? dateIso,
    String? time,
    bool? isLight,
    bool? isOverride,
  }) {
    return PlannedSlot(
      routineId: routineId,
      weekdaySat0: weekdaySat0 ?? this.weekdaySat0,
      dateIso: dateIso ?? this.dateIso,
      time: time ?? this.time,
      title: title,
      emoji: emoji,
      reminderMinutes: reminderMinutes,
      isLight: isLight ?? this.isLight,
      isOverride: isOverride ?? this.isOverride,
    );
  }
}

String dateIsoForSat0(Sat0Weekday sat0, DateTime now) {
  final todaySat0 = dartWeekdayToSat0(now.weekday);
  final day = DateTime(
    now.year,
    now.month,
    now.day,
  ).add(Duration(days: sat0 - todaySat0));
  return formatDateIso(day);
}

String formatDateIso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Saturday of the week that contains [now], using Ritmo's Sat0 week.
DateTime weekStartSaturday(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  return today.subtract(Duration(days: dartWeekdayToSat0(now.weekday)));
}

/// Returns the Sat0 index when [dateIso] falls inside this Ritmo week.
Sat0Weekday? sat0ForDateIsoInWeek(String dateIso, DateTime now) {
  final parsed = DateTime.tryParse(dateIso);
  if (parsed == null) return null;
  final day = DateTime(parsed.year, parsed.month, parsed.day);
  final start = weekStartSaturday(now);
  final end = start.add(const Duration(days: 6));
  if (day.isBefore(start) || day.isAfter(end)) return null;
  return dartWeekdayToSat0(day.weekday);
}

/// Applies this-week overrides onto expanded template slots.
///
/// MOVE landing outside the current week is dropped from this week's board
/// (the destination week will pick it up when loaded).
class WeekSlotResolver {
  const WeekSlotResolver();

  List<PlannedSlot> resolve({
    required List<PlannedSlot> templates,
    required List<MovementSlotOverride> overrides,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final byKey = <String, PlannedSlot>{
      for (final slot in templates) _key(slot.routineId, slot.dateIso): slot,
    };

    for (final override in overrides) {
      final key = _key(override.routineId, override.dateIso);
      switch (override.action) {
        case MovementSlotAction.skip:
          byKey.remove(key);
        case MovementSlotAction.retime:
          final existing = byKey[key];
          if (existing != null &&
              override.newTime != null &&
              override.newTime!.isNotEmpty) {
            byKey[key] = existing.copyWith(
              time: override.newTime,
              isOverride: true,
            );
          }
        case MovementSlotAction.light:
          final existing = byKey[key];
          if (existing != null) {
            byKey[key] = existing.copyWith(isLight: true, isOverride: true);
          }
        case MovementSlotAction.move:
          final existing = byKey.remove(key);
          final destIso = override.newDateIso;
          if (destIso == null || destIso.isEmpty) break;
          final destSat0 = sat0ForDateIsoInWeek(destIso, clock);
          if (destSat0 == null) break;
          final base =
              existing ??
              PlannedSlot(
                routineId: override.routineId,
                weekdaySat0: destSat0,
                dateIso: destIso,
                time: override.newTime ?? '18:30',
                isOverride: true,
              );
          byKey[_key(override.routineId, destIso)] = base.copyWith(
            weekdaySat0: destSat0,
            dateIso: destIso,
            time: override.newTime ?? base.time,
            isOverride: true,
          );
      }
    }

    final resolved = byKey.values.toList()
      ..sort((a, b) {
        final byDay = a.weekdaySat0.compareTo(b.weekdaySat0);
        if (byDay != 0) return byDay;
        return a.time.compareTo(b.time);
      });
    return resolved;
  }

  static String _key(String routineId, String dateIso) => '$routineId|$dateIso';
}
