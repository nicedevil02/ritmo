import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/sources/agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/routine_agenda_source.dart';
import 'package:ritmo/core/domain/models.dart';

void main() {
  group('B0-2: RoutineAgendaSource EVENT itemType emission', () {
    final date = DateTime(2026, 8, 14);
    const dateStr = '2026-08-14';

    RoutineAgendaSource buildSource({bool eventsEnabled = true}) {
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

      return RoutineAgendaSource(
        routines: routines,
        schedules: schedules,
        occurrences: [],
        avgDurations: {},
        categoryAvgDurations: {},
        completionsByDate: {},
        eventsEnabled: eventsEnabled,
        activeModules: {'religion': true, 'medicine': true, 'courses': true},
      );
    }

    AgendaDayContext ctxWith(AgendaQueryOptions options) => AgendaDayContext(
          date: date,
          dateStr: dateStr,
          isToday: true,
          prayerTimes: const {},
          options: options,
        );

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
      // پیش‌فرض باید روشن باشد تا ساختن مستقیم منبع رفتار قبلی را حفظ کند.
      expect(source.eventsEnabled, isTrue);
    });

    // REGRESSION GUARD — این تست پیش‌تر دقیقاً همان باگ را تثبیت کرده بود.
    //
    // اگر یک ردیف `routines` با itemType='EVENT' به AgendaDomain.event
    // تغییر دامنه بدهد، آیتم در تقویم نامرئی می‌شود؛ چون رجیستری رندرر،
    // مسیرهای تکمیل، DirectManipulationEligibility و توابع رنگ/آیکن/برچسب
    // همگی روی AgendaDomain.routine کلید می‌خورند. تمایز «رویداد بودن»
    // باید فقط از محور kind بیاید.
    test('EVENT itemType stays in AgendaDomain.routine but carries AgendaItemKind.event', () {
      final items = buildSource().itemsForDate(
        ctxWith(const AgendaQueryOptions(
          domains: {AgendaDomain.routine, AgendaDomain.event},
        )),
      );
      expect(items.length, equals(2));

      final normalItem = items.firstWhere((i) => i.sourceId == 'routine_normal');
      expect(normalItem.domain, equals(AgendaDomain.routine));
      expect(normalItem.kind, equals(AgendaItemKind.routine));

      final eventItem = items.firstWhere((i) => i.sourceId == 'routine_event');
      expect(eventItem.domain, equals(AgendaDomain.routine));
      expect(eventItem.kind, equals(AgendaItemKind.event));
      expect(eventItem.deepLink?.domain, equals(AgendaDomain.routine));
      expect(eventItem.title, equals('رویداد جشن تولد'));
      expect(eventItem.durationMinutes, equals(120));
    });

    test('A default (unfiltered) query surfaces the routine-backed event', () {
      final items = buildSource().itemsForDate(
        ctxWith(const AgendaQueryOptions()),
      );
      expect(items.map((i) => i.sourceId), containsAll(<String>['routine_normal', 'routine_event']));
    });

    test('An events-only query still surfaces the routine-backed event', () {
      final items = buildSource().itemsForDate(
        ctxWith(const AgendaQueryOptions(domains: {AgendaDomain.event})),
      );

      expect(items, hasLength(1));
      expect(items.first.sourceId, equals('routine_event'));
      expect(items.first.kind, equals(AgendaItemKind.event));
    });

    test('A routines-only query excludes nothing and keeps the event visible', () {
      final items = buildSource().itemsForDate(
        ctxWith(const AgendaQueryOptions(domains: {AgendaDomain.routine})),
      );

      expect(items.map((i) => i.sourceId), containsAll(<String>['routine_normal', 'routine_event']));
    });

    // دروازهٔ `calendar_show_events` باید روی هر دو مسیر رویداد یکسان عمل کند:
    // هم temporary_events (در EventAgendaSource) و هم رویدادهای روتین‌پایهٔ پلنر.
    test('Disabling events hides the routine-backed event but keeps the routine', () {
      final items = buildSource(eventsEnabled: false).itemsForDate(
        ctxWith(const AgendaQueryOptions()),
      );

      expect(items, hasLength(1));
      expect(items.first.sourceId, equals('routine_normal'));
      expect(items.first.kind, equals(AgendaItemKind.routine));
    });

    test('Disabling events empties an events-only query', () {
      final items = buildSource(eventsEnabled: false).itemsForDate(
        ctxWith(const AgendaQueryOptions(domains: {AgendaDomain.event})),
      );

      expect(items, isEmpty);
    });
  });
}
