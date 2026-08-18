import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/features/calendar/presentation/logic/agenda_bucketing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CAL-35: Unified Chronological Ordering in collapseRecurringSeries', () {
    test('A single task at 23:00 is placed AFTER a recurring series at 06:00 on the same date', () {
      // 3 routine items at 06:00 on consecutive days forming a series
      final routine1 = AgendaItem(
        id: 'routine_1',
        domain: AgendaDomain.routine,
        kind: AgendaItemKind.routine,
        sourceId: 'routine_morning',
        title: 'Morning Routine',
        category: Category.fitness,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.routine, targetId: 'routine_morning'),
        dateStr: '2026-08-18',
        timeOfDay: '06:00',
        durationMinutes: 30,
      );
      final routine2 = AgendaItem(
        id: 'routine_2',
        domain: AgendaDomain.routine,
        kind: AgendaItemKind.routine,
        sourceId: 'routine_morning',
        title: 'Morning Routine',
        category: Category.fitness,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.routine, targetId: 'routine_morning'),
        dateStr: '2026-08-19',
        timeOfDay: '06:00',
        durationMinutes: 30,
      );
      final routine3 = AgendaItem(
        id: 'routine_3',
        domain: AgendaDomain.routine,
        kind: AgendaItemKind.routine,
        sourceId: 'routine_morning',
        title: 'Morning Routine',
        category: Category.fitness,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.routine, targetId: 'routine_morning'),
        dateStr: '2026-08-20',
        timeOfDay: '06:00',
        durationMinutes: 30,
      );

      // Single task at 23:00 on the first day
      final lateSingleTask = AgendaItem(
        id: 'single_task_late',
        domain: AgendaDomain.task,
        kind: AgendaItemKind.task,
        sourceId: 'task_late',
        title: 'Late Task',
        category: Category.work,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.task, targetId: 'task_late'),
        dateStr: '2026-08-18',
        timeOfDay: '23:00',
        durationMinutes: 15,
      );

      final entries = collapseRecurringSeries(
        [lateSingleTask, routine1, routine2, routine3],
        daysInBucket: 7,
        minOccurrences: 3,
      );

      expect(entries.length, equals(2));

      // The morning series (anchor at 2026-08-18 06:00) MUST come first
      expect(entries[0], isA<AgendaSeries>());
      expect(entries[0].anchor.timeOfDay, equals('06:00'));

      // The late task (at 2026-08-18 23:00) MUST come second
      expect(entries[1], isA<AgendaSingle>());
      expect(entries[1].anchor.timeOfDay, equals('23:00'));
    });
  });
}
