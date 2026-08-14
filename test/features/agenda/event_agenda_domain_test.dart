import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/sources/agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/routine_agenda_source.dart';
import 'package:ritmo/core/domain/models.dart';

void main() {
  group('B0-2: RoutineAgendaSource AgendaDomain.event emission', () {
    test('RoutineAgendaSource declares both routine and event domains', () {
      const source = RoutineAgendaSource(
        routines: [],
        schedules: [],
        occurrences: [],
        avgDurations: {},
        categoryAvgDurations: {},
        completionsByDate: {},
        activeModules: {'religion': true, 'medicine': true, 'courses': true},
      );

      expect(source.domains, contains(AgendaDomain.routine));
      expect(source.domains, contains(AgendaDomain.event));
    });

    test('RoutineAgendaSource yields AgendaDomain.event for EVENT itemType', () {
      final date = DateTime(2026, 8, 14);
      const dateStr = '2026-08-14';

      final rule = RecurrenceRule(
        weekdays: const [],
        startDate: date,
        intervalDays: 1,
        reminderTimes: const ['10:00'],
      );

      final routines = [
        {
          'id': 'routine_normal',
          'title': 'روتین روزمره',
          'category': 'personal',
          'itemType': 'ROUTINE',
          'targetDurationMinutes': 30,
          'priority': 1.0,
          'isEssential': 0,
        },
        {
          'id': 'routine_event',
          'title': 'رویداد جشن تولد',
          'category': 'personal',
          'itemType': 'EVENT',
          'targetDurationMinutes': 120,
          'priority': 2.0,
          'isEssential': 0,
        },
      ];

      final schedules = [
        {
          'id': 'sched_1',
          'routineId': 'routine_normal',
          'timeOfDay': '08:00',
          'daysOfWeek': '1,2,3,4,5,6,7',
          'recurrenceRule': jsonEncode(
            RecurrenceRule(
              startDate: date,
              weekdays: const [1, 2, 3, 4, 5, 6, 7],
              reminderTimes: const ['08:00'],
            ).toMap(),
          ),
        },
        {
          'id': 'sched_2',
          'routineId': 'routine_event',
          'timeOfDay': '10:00',
          'daysOfWeek': '',
          'recurrenceRule': jsonEncode(rule.toMap()),
        },
      ];

      final source = RoutineAgendaSource(
        routines: routines,
        schedules: schedules,
        occurrences: [],
        avgDurations: {},
        categoryAvgDurations: {},
        completionsByDate: {},
        activeModules: {'religion': true, 'medicine': true, 'courses': true},
      );

      final ctx = AgendaDayContext(
        date: date,
        dateStr: dateStr,
        isToday: true,
        prayerTimes: {},
        options: const AgendaQueryOptions(
          domains: {AgendaDomain.routine, AgendaDomain.event},
        ),
      );

      final items = source.itemsForDate(ctx);
      expect(items.length, equals(2));

      final normalItem = items.firstWhere((i) => i.sourceId == 'routine_normal');
      expect(normalItem.domain, equals(AgendaDomain.routine));

      final eventItem = items.firstWhere((i) => i.sourceId == 'routine_event');
      expect(eventItem.domain, equals(AgendaDomain.event));
      expect(eventItem.title, equals('رویداد جشن تولد'));
      expect(eventItem.durationMinutes, equals(120));
    });
  });
}
