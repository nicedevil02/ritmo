import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/occurrence_override_repository.dart';
import 'package:ritmo/core/domain/models.dart';

void main() {
  group('Override Cross-Domain Isolation (CAL-13 / CAL-57)', () {
    test('OccurrenceOverride.formatKey lowercases sourceType and isolates domains', () {
      final taskKey = OccurrenceOverride.formatKey('task', '42');
      final routineKey = OccurrenceOverride.formatKey('routine', '42');
      final upperTaskKey = OccurrenceOverride.formatKey('TASK', '42');

      expect(taskKey, equals('task:42'));
      expect(routineKey, equals('routine:42'));
      expect(upperTaskKey, equals('task:42'));
      expect(taskKey, isNot(equals(routineKey)));
    });

    test('Override for task:42 is not applied to routine:42 sharing identical sourceId', () {
      const dateStr = '2026-08-18';
      final taskItem = AgendaItem(
        id: 'task:42:$dateStr',
        domain: AgendaDomain.task,
        kind: AgendaItemKind.task,
        sourceId: '42',
        title: 'Important Task',
        category: Category.work,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.task, targetId: '42'),
        dateStr: dateStr,
        timeOfDay: '09:00',
        durationMinutes: 30,
      );

      final routineItem = AgendaItem(
        id: 'routine:42:$dateStr',
        domain: AgendaDomain.routine,
        kind: AgendaItemKind.routine,
        sourceId: '42',
        title: 'Morning Routine',
        category: Category.fitness,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.routine, targetId: '42'),
        dateStr: dateStr,
        timeOfDay: '09:00',
        durationMinutes: 30,
      );

      const taskOverride = OccurrenceOverride(
        sourceType: 'task',
        sourceId: '42',
        dateStr: dateStr,
        timeOfDay: '11:30',
        durationMinutes: 45,
        status: 'MOVED',
        createdAt: '2026-08-01T00:00:00Z',
        updatedAt: '2026-08-01T00:00:00Z',
      );

      final overrideMap = <String, OccurrenceOverride>{
        OccurrenceOverride.formatKey(taskOverride.sourceType, taskOverride.sourceId): taskOverride,
      };

      // Lookup for task:42 -> gets taskOverride
      final taskOvr = overrideMap[OccurrenceOverride.formatKey(taskItem.domain.name, taskItem.sourceId)];
      expect(taskOvr, isNotNull);
      expect(taskOvr!.timeOfDay, equals('11:30'));

      // Lookup for routine:42 -> must be NULL (no pollution)
      final routineOvr = overrideMap[OccurrenceOverride.formatKey(routineItem.domain.name, routineItem.sourceId)];
      expect(routineOvr, isNull, reason: 'Cross-domain collision: routine:42 erroneously received task:42 override');
    });
  });
}
