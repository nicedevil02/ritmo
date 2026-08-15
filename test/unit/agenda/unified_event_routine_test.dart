import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/sources/agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/routine_agenda_source.dart';
import 'package:ritmo/features/routines/domain/routine_recurrence.dart';

void main() {
  group('Unified Event-Routine Recurrence & Calendar Resolution Tests', () {
    // NOTE: routine-backed events (a `routines` row tagged itemType='EVENT')
    // stay inside AgendaDomain.routine. Only AgendaItemKind.event marks them as
    // events. Re-tagging the domain used to hide them from the whole calendar,
    // because renderers, completion paths and palette helpers all key on
    // AgendaDomain.routine.
    test('Event-Routine with EVERY_DAY recurrence appears on today, tomorrow, and future days', () {
      const recurrence = DailyRecurrence();
      final (schedType, daysOfWeek) = deriveScheduleParams(recurrence);
      final recurrenceJson = encodeRecurrenceRule(
        recurrence: recurrence,
        startDate: DateTime(2026, 8, 15),
        reminderTimes: ['10:00'],
      );

      final routines = [
        {
          'id': 'routine_event_daily',
          'title': 'جلسه هماهنگی روزانه',
          'itemType': 'EVENT',
          'category': 'personal',
          'targetDurationMinutes': 45,
          'isArchived': 0,
        },
      ];

      final schedules = [
        {
          'id': 'sched_event_daily',
          'routineId': 'routine_event_daily',
          'scheduleType': schedType,
          'timeOfDay': '10:00',
          'daysOfWeek': daysOfWeek,
          'recurrenceRule': recurrenceJson,
        },
      ];

      final source = RoutineAgendaSource(
        routines: routines,
        schedules: schedules,
        occurrences: const [],
        avgDurations: const {},
        categoryAvgDurations: const {},
        completionsByDate: const {},
        activeModules: const {},
      );

      // 1. Check Today (2026-08-15)
      final ctxToday = AgendaDayContext(
        date: DateTime(2026, 8, 15),
        dateStr: '2026-08-15',
        isToday: true,
        prayerTimes: const {},
        options: const AgendaQueryOptions(),
      );
      final itemsToday = source.itemsForDate(ctxToday);
      expect(itemsToday, hasLength(1));
      expect(itemsToday.first.title, equals('جلسه هماهنگی روزانه'));
      expect(itemsToday.first.domain, equals(AgendaDomain.routine));
      expect(itemsToday.first.kind, equals(AgendaItemKind.event));
      expect(itemsToday.first.timeOfDay, equals('10:00'));
      expect(itemsToday.first.durationMinutes, equals(45));

      // 2. Check Tomorrow (2026-08-16)
      final ctxTomorrow = AgendaDayContext(
        date: DateTime(2026, 8, 16),
        dateStr: '2026-08-16',
        isToday: false,
        prayerTimes: const {},
        options: const AgendaQueryOptions(),
      );
      final itemsTomorrow = source.itemsForDate(ctxTomorrow);
      expect(itemsTomorrow, hasLength(1));
      expect(itemsTomorrow.first.title, equals('جلسه هماهنگی روزانه'));
    });

    test('Event-Routine with CUSTOM_DAYS recurrence appears only on selected weekdays', () {
      // Weekdays: Saturday (6), Monday (1), Wednesday (3)
      final recurrence = WeekdaysRecurrence(weekdays: const {6, 1, 3});
      final (schedType, daysOfWeek) = deriveScheduleParams(recurrence);
      final recurrenceJson = encodeRecurrenceRule(
        recurrence: recurrence,
        startDate: DateTime(2026, 8, 15), // Saturday
        reminderTimes: ['14:30'],
      );

      final routines = [
        {
          'id': 'routine_event_custom',
          'title': 'کلاس آموزش موسیقی',
          'itemType': 'EVENT',
          'category': 'personal',
          'targetDurationMinutes': 60,
          'isArchived': 0,
        },
      ];

      final schedules = [
        {
          'id': 'sched_event_custom',
          'routineId': 'routine_event_custom',
          'scheduleType': schedType,
          'timeOfDay': '14:30',
          'daysOfWeek': daysOfWeek,
          'recurrenceRule': recurrenceJson,
        },
      ];

      final source = RoutineAgendaSource(
        routines: routines,
        schedules: schedules,
        occurrences: const [],
        avgDurations: const {},
        categoryAvgDurations: const {},
        completionsByDate: const {},
        activeModules: const {},
      );

      // Saturday (2026-08-15) -> Should appear
      final ctxSat = AgendaDayContext(
        date: DateTime(2026, 8, 15),
        dateStr: '2026-08-15',
        isToday: true,
        prayerTimes: const {},
        options: const AgendaQueryOptions(),
      );
      expect(source.itemsForDate(ctxSat), hasLength(1));

      // Sunday (2026-08-16, weekday 7) -> Should NOT appear
      final ctxSun = AgendaDayContext(
        date: DateTime(2026, 8, 16),
        dateStr: '2026-08-16',
        isToday: false,
        prayerTimes: const {},
        options: const AgendaQueryOptions(),
      );
      expect(source.itemsForDate(ctxSun), isEmpty);

      // Monday (2026-08-17, weekday 1) -> Should appear
      final ctxMon = AgendaDayContext(
        date: DateTime(2026, 8, 17),
        dateStr: '2026-08-17',
        isToday: false,
        prayerTimes: const {},
        options: const AgendaQueryOptions(),
      );
      expect(source.itemsForDate(ctxMon), hasLength(1));
    });

    test('Event-Routine with ONCE recurrence appears only on target date', () {
      final targetDate = DateTime(2026, 8, 17);
      final recurrence = OnceRecurrence(date: targetDate);
      final (schedType, daysOfWeek) = deriveScheduleParams(recurrence);
      final recurrenceJson = encodeRecurrenceRule(
        recurrence: recurrence,
        startDate: targetDate,
        reminderTimes: ['18:00'],
      );

      final routines = [
        {
          'id': 'routine_event_once',
          'title': 'جشن تولد دوست',
          'itemType': 'EVENT',
          'category': 'personal',
          'targetDurationMinutes': 120,
          'isArchived': 0,
        },
      ];

      final schedules = [
        {
          'id': 'sched_event_once',
          'routineId': 'routine_event_once',
          'scheduleType': schedType,
          'timeOfDay': '18:00',
          'daysOfWeek': daysOfWeek,
          'recurrenceRule': recurrenceJson,
        },
      ];

      final source = RoutineAgendaSource(
        routines: routines,
        schedules: schedules,
        occurrences: const [],
        avgDurations: const {},
        categoryAvgDurations: const {},
        completionsByDate: const {},
        activeModules: const {},
      );

      // 2026-08-15 -> Should NOT appear
      final ctxBefore = AgendaDayContext(
        date: DateTime(2026, 8, 15),
        dateStr: '2026-08-15',
        isToday: false,
        prayerTimes: const {},
        options: const AgendaQueryOptions(),
      );
      expect(source.itemsForDate(ctxBefore), isEmpty);

      // 2026-08-17 -> Should appear
      final ctxTarget = AgendaDayContext(
        date: targetDate,
        dateStr: '2026-08-17',
        isToday: false,
        prayerTimes: const {},
        options: const AgendaQueryOptions(),
      );
      final itemsTarget = source.itemsForDate(ctxTarget);
      expect(itemsTarget, hasLength(1));
      expect(itemsTarget.first.title, equals('جشن تولد دوست'));
      expect(itemsTarget.first.domain, equals(AgendaDomain.routine));
      expect(itemsTarget.first.kind, equals(AgendaItemKind.event));

      // 2026-08-18 -> Should NOT appear
      final ctxAfter = AgendaDayContext(
        date: DateTime(2026, 8, 18),
        dateStr: '2026-08-18',
        isToday: false,
        prayerTimes: const {},
        options: const AgendaQueryOptions(),
      );
      expect(source.itemsForDate(ctxAfter), isEmpty);
    });

    test('Standard Routine with ONCE recurrence appears only on target date', () {
      final targetDate = DateTime(2026, 8, 16);
      final recurrence = OnceRecurrence(date: targetDate);
      final (schedType, daysOfWeek) = deriveScheduleParams(recurrence);
      final recurrenceJson = encodeRecurrenceRule(
        recurrence: recurrence,
        startDate: targetDate,
        reminderTimes: ['08:00'],
      );

      final routines = [
        {
          'id': 'routine_std_once',
          'title': 'نظافت اساسی اتاق',
          'itemType': 'ROUTINE',
          'category': 'personal',
          'targetDurationMinutes': 90,
          'isArchived': 0,
        },
      ];

      final schedules = [
        {
          'id': 'sched_std_once',
          'routineId': 'routine_std_once',
          'scheduleType': schedType,
          'timeOfDay': '08:00',
          'daysOfWeek': daysOfWeek,
          'recurrenceRule': recurrenceJson,
        },
      ];

      final source = RoutineAgendaSource(
        routines: routines,
        schedules: schedules,
        occurrences: const [],
        avgDurations: const {},
        categoryAvgDurations: const {},
        completionsByDate: const {},
        activeModules: const {},
      );

      // Target Date (2026-08-16) -> Should appear
      final ctxTarget = AgendaDayContext(
        date: targetDate,
        dateStr: '2026-08-16',
        isToday: false,
        prayerTimes: const {},
        options: const AgendaQueryOptions(),
      );
      final items = source.itemsForDate(ctxTarget);
      expect(items, hasLength(1));
      expect(items.first.title, equals('نظافت اساسی اتاق'));
      expect(items.first.domain, equals(AgendaDomain.routine));
      expect(items.first.kind, equals(AgendaItemKind.routine));

      // Subsequent Date (2026-08-17) -> Should NOT appear
      final ctxAfter = AgendaDayContext(
        date: DateTime(2026, 8, 17),
        dateStr: '2026-08-17',
        isToday: false,
        prayerTimes: const {},
        options: const AgendaQueryOptions(),
      );
      expect(source.itemsForDate(ctxAfter), isEmpty);
    });
  });
}
