import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/sources/agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/event_agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/routine_agenda_source.dart';
import 'package:ritmo/features/calendar/presentation/utils/domain_palette.dart';

void main() {
  group('Phase M2-B: Item Kind Axis Decoupled From Domain (P3 / M2-3..M2-4)', () {
    test('M2-3: defaultKindFor maps all AgendaDomain values to safe defaults', () {
      expect(defaultKindFor(AgendaDomain.routine), equals(AgendaItemKind.routine));
      expect(defaultKindFor(AgendaDomain.task), equals(AgendaItemKind.task));
      expect(defaultKindFor(AgendaDomain.goalStep), equals(AgendaItemKind.task));
      expect(defaultKindFor(AgendaDomain.commitment), equals(AgendaItemKind.task));
      expect(defaultKindFor(AgendaDomain.prayer), equals(AgendaItemKind.practice));
      expect(defaultKindFor(AgendaDomain.mustahab), equals(AgendaItemKind.practice));
      expect(defaultKindFor(AgendaDomain.worshipDebt), equals(AgendaItemKind.practice));
      expect(defaultKindFor(AgendaDomain.sport), equals(AgendaItemKind.session));
      expect(defaultKindFor(AgendaDomain.course), equals(AgendaItemKind.session));
      expect(defaultKindFor(AgendaDomain.konkur), equals(AgendaItemKind.session));
      expect(defaultKindFor(AgendaDomain.medicine), equals(AgendaItemKind.dose));
      expect(defaultKindFor(AgendaDomain.cycle), equals(AgendaItemKind.reflection));
      expect(defaultKindFor(AgendaDomain.event), equals(AgendaItemKind.event));
      expect(defaultKindFor(AgendaDomain.appointment), equals(AgendaItemKind.event));
    });

    test('M2-3: RoutineAgendaSource explicitly maps 5 planner item types to distinct AgendaItemKind', () {
      final routines = [
        {'id': 'r_routine', 'title': 'ورزش صبحگاهی', 'itemType': 'ROUTINE', 'category': 'sport'},
        {'id': 'r_reminder', 'title': 'خاموش کردن چراغ', 'itemType': 'REMINDER', 'category': 'personal'},
        {'id': 'r_task', 'title': 'ارسال ایمیل کاری', 'itemType': 'TASK', 'category': 'work'},
        {'id': 'r_reflect', 'title': 'شکرگزاری شبانه', 'itemType': 'REFLECT', 'category': 'spiritual'},
        {'id': 'r_event', 'title': 'جلسه با مدیر', 'itemType': 'EVENT', 'category': 'work'},
      ];

      final schedules = routines.map((r) => {
        'routineId': r['id'],
        'scheduleType': 'FIXED_TIME',
        'timeOfDay': '09:00',
      }).toList();

      final source = RoutineAgendaSource(
        routines: routines,
        schedules: schedules,
        occurrences: const [],
        avgDurations: const {},
        categoryAvgDurations: const {},
        completionsByDate: const {},
        activeModules: const {},
      );

      final ctx = AgendaDayContext(
        date: DateTime(2026, 8, 15),
        dateStr: '2026-08-15',
        isToday: true,
        prayerTimes: const {},
        options: const AgendaQueryOptions(),
      );

      final items = source.itemsForDate(ctx);
      expect(items, hasLength(5));

      final mapBySourceId = {for (final i in items) i.sourceId: i};

      expect(mapBySourceId['r_routine']?.kind, equals(AgendaItemKind.routine));
      expect(mapBySourceId['r_reminder']?.kind, equals(AgendaItemKind.reminder));
      expect(mapBySourceId['r_task']?.kind, equals(AgendaItemKind.task));
      expect(mapBySourceId['r_reflect']?.kind, equals(AgendaItemKind.reflection));
      expect(mapBySourceId['r_event']?.kind, equals(AgendaItemKind.event));
    });

    test('M2-3: EventAgendaSource sets kind to AgendaItemKind.event', () {
      const source = EventAgendaSource(events: [
        {
          'id': 'evt_1',
          'title': 'دیدار با همکاران',
          'date': '2026-08-15',
          'startTime': '14:00',
          'durationMinutes': 60,
        },
      ]);

      final ctx = AgendaDayContext(
        date: DateTime(2026, 8, 15),
        dateStr: '2026-08-15',
        isToday: true,
        prayerTimes: const {},
        options: const AgendaQueryOptions(),
      );

      final items = source.itemsForDate(ctx);
      expect(items, hasLength(1));
      expect(items.first.kind, equals(AgendaItemKind.event));
    });

    test('M2-4: 5 planner kinds have 5 distinct icons and labels', () {
      final kinds = [
        AgendaItemKind.routine,
        AgendaItemKind.reminder,
        AgendaItemKind.task,
        AgendaItemKind.reflection,
        AgendaItemKind.event,
      ];

      final icons = kinds.map(kindIcon).toSet();
      final labels = kinds.map(kindLabelFa).toSet();

      // All 5 must be distinct
      expect(icons, hasLength(5));
      expect(labels, hasLength(5));
    });
  });
}
