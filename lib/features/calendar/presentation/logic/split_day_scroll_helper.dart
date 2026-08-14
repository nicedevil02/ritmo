import 'package:ritmo/features/calendar/presentation/utils/calendar_tokens.dart';

/// Pure function to map minutes of day (0..1439) to scroll target in split day view.
({int columnIndex, double offset}) splitDayScrollTargetFor(
  int minutesOfDay, {
  double pxPerMinute = CalendarTokens.pxPerMinuteSplit,
  int boundaryMinutes = CalendarTokens.splitBoundaryMinutes,
  int leadMinutes = 60,
}) {
  final clampedM = minutesOfDay.clamp(0, 1439);
  final columnIndex = clampedM < boundaryMinutes ? 0 : 1;
  final minuteInColumn = clampedM < boundaryMinutes ? clampedM : clampedM - boundaryMinutes;
  final effectiveMinute = (minuteInColumn - leadMinutes).clamp(0, boundaryMinutes);
  final offset = effectiveMinute * pxPerMinute;
  return (columnIndex: columnIndex, offset: offset);
}
