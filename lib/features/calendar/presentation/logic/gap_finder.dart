import 'dart:math';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/models/duration_bounds.dart';
import 'package:ritmo/core/utils/time_of_day_minutes.dart';

typedef TimeSlot = ({int startMinutes, int durationMinutes});

/// Pure logic to find and rank available free time gaps in a day.
class GapFinder {
  /// Returns free gaps in the day that can accommodate [minDurationMinutes],
  /// sorted by closeness to [preferredStartMinutes] (if provided) or chronologically.
  static List<TimeSlot> findFreeGaps(
    List<AgendaItem> dayItems, {
    required int minDurationMinutes,
    int? preferredStartMinutes,
    int dayStartMinutes = 6 * 60, // 06:00
    int dayEndMinutes = 23 * 60, // 23:00
    String? excludeItemId,
  }) {
    if (dayStartMinutes >= dayEndMinutes || minDurationMinutes <= 0) return [];

    // Collect all occupied intervals from timed items within day bounds
    final occupied = <({int start, int end})>[];
    for (final item in dayItems) {
      if (excludeItemId != null && item.id == excludeItemId) continue;
      if (!item.isTimed) continue;
      final startMin = TimeOfDayMinutes.tryParse(item.timeOfDay);
      if (startMin == null) continue;
      final dur = DurationBounds.sanitize(item.durationMinutes);
      final start = startMin.clamp(dayStartMinutes, dayEndMinutes);
      final end = (startMin + dur).clamp(dayStartMinutes, dayEndMinutes);
      if (start < end) {
        occupied.add((start: start, end: end));
      }
    }

    if (occupied.isEmpty) {
      final fullDuration = dayEndMinutes - dayStartMinutes;
      if (fullDuration >= minDurationMinutes) {
        return [(startMinutes: dayStartMinutes, durationMinutes: fullDuration)];
      }
      return [];
    }

    // Sort by start time
    occupied.sort((a, b) => a.start.compareTo(b.start));

    // Merge overlapping/adjacent intervals
    final merged = <({int start, int end})>[];
    var curStart = occupied.first.start;
    var curEnd = occupied.first.end;

    for (int i = 1; i < occupied.length; i++) {
      final interval = occupied[i];
      if (interval.start <= curEnd) {
        curEnd = max(curEnd, interval.end);
      } else {
        merged.add((start: curStart, end: curEnd));
        curStart = interval.start;
        curEnd = interval.end;
      }
    }
    merged.add((start: curStart, end: curEnd));

    // Compute complement intervals (free gaps)
    final gaps = <TimeSlot>[];
    int cursor = dayStartMinutes;

    for (final interval in merged) {
      if (interval.start > cursor) {
        final gapDur = interval.start - cursor;
        if (gapDur >= minDurationMinutes) {
          gaps.add((startMinutes: cursor, durationMinutes: gapDur));
        }
      }
      cursor = max(cursor, interval.end);
    }

    if (cursor < dayEndMinutes) {
      final gapDur = dayEndMinutes - cursor;
      if (gapDur >= minDurationMinutes) {
        gaps.add((startMinutes: cursor, durationMinutes: gapDur));
      }
    }

    // Sort by proximity to preferredStartMinutes if specified
    if (preferredStartMinutes != null) {
      gaps.sort((a, b) {
        final diffA = (a.startMinutes - preferredStartMinutes).abs();
        final diffB = (b.startMinutes - preferredStartMinutes).abs();
        return diffA.compareTo(diffB);
      });
    }

    return gaps;
  }
}
