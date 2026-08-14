import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/features/calendar/data/calendar_search_repository.dart';

void main() {
  group('P0-7: Calendar Search Model & Hit Tests', () {
    test('CalendarSearchHit model handles recurring routines and dateStr correctly', () {
      const routineHit = CalendarSearchHit(
        id: 'r1',
        title: 'ورزش صبحگاهی',
        domain: AgendaDomain.routine,
        sourceId: 'routine_1',
        subtitle: 'روتین',
        isRecurring: true,
      );

      expect(routineHit.isRecurring, isTrue);
      expect(routineHit.dateStr, isNull);
      expect(routineHit.subtitle, equals('روتین'));
      expect(routineHit.domain, equals(AgendaDomain.routine));

      const taskHit = CalendarSearchHit(
        id: 't1',
        title: 'خرید کتاب',
        domain: AgendaDomain.task,
        sourceId: 'task_1',
        dateStr: '2026-08-14',
        isRecurring: false,
      );

      expect(taskHit.isRecurring, isFalse);
      expect(taskHit.dateStr, equals('2026-08-14'));
    });
  });
}
