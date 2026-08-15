import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/sources/agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/commitment_agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/task_agenda_source.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/settings/settings_registry.dart';
import 'package:ritmo/features/routines/domain/strategies/planner_strategy_registry.dart';
import 'package:ritmo/features/routines/domain/strategies/task_strategy.dart';

void main() {
  group('Phase M2-C: Task Unification & Display Behavior (P4 / M2-5..M2-7)', () {
    test('M2-5: CommitmentAgendaSource ignores allocations already materialized as TASK', () {
      const source = CommitmentAgendaSource(allocationsByDate: {
        '2026-08-15': [
          {
            'allocId': 'alloc_normal',
            'commTitle': 'جلسه با تیم',
            'exactTime': '10:00',
            'materializedEntityType': null,
            'materializedEntityId': null,
          },
          {
            'allocId': 'alloc_materialized_task',
            'commTitle': 'تسک انجام کار',
            'exactTime': '11:00',
            'materializedEntityType': 'TASK',
            'materializedEntityId': 'task_123',
          },
        ],
      });

      final ctx = AgendaDayContext(
        date: DateTime(2026, 8, 15),
        dateStr: '2026-08-15',
        isToday: true,
        prayerTimes: const {},
        options: const AgendaQueryOptions(),
      );

      final items = source.itemsForDate(ctx);
      expect(items, hasLength(1));
      expect(items.first.sourceId, equals('alloc_normal'));
    });

    test('M2-6: TaskStrategy matches itemType == TASK in PlannerStrategyRegistry', () {
      final strategy = PlannerStrategyRegistry.resolve(Category.work, itemType: 'TASK');
      expect(strategy, isA<TaskStrategy>());
    });

    test('M2-7: Dateless tasks only show on today and are omitted on other days', () {
      final source = TaskAgendaSource(
        tasksByDate: {},
        overdueTasks: [],
        datelessTasks: [
          {'id': 'task_dateless_1', 'title': 'خرید کتاب', 'isDone': 0, 'isImportant': 0},
        ],
        totalOverdueCount: 0,
        stepCounts: {},
      );

      // On Today: included
      final todayCtx = AgendaDayContext(
        date: DateTime(2026, 8, 15),
        dateStr: '2026-08-15',
        isToday: true,
        prayerTimes: const {},
        options: const AgendaQueryOptions(),
      );
      final todayItems = source.itemsForDate(todayCtx);
      expect(todayItems, hasLength(1));
      expect(todayItems.first.title, equals('خرید کتاب'));
      expect(todayItems.first.meta['isDateless'], isTrue);

      // On other days: excluded
      final tomorrowCtx = AgendaDayContext(
        date: DateTime(2026, 8, 16),
        dateStr: '2026-08-16',
        isToday: false,
        prayerTimes: const {},
        options: const AgendaQueryOptions(),
      );
      final tomorrowItems = source.itemsForDate(tomorrowCtx);
      expect(tomorrowItems, isEmpty);
    });

    test('M2-7: Overdue overflow card appears when totalOverdueCount > 20', () {
      final overdueList = List.generate(
        20,
        (i) => {'id': 'od_$i', 'title': 'کار معوقه $i', 'dueDate': '2026-08-01', 'isImportant': 0},
      );

      final source = TaskAgendaSource(
        tasksByDate: {},
        overdueTasks: overdueList,
        datelessTasks: [],
        totalOverdueCount: 25, // 5 overflow
        stepCounts: {},
      );

      final ctx = AgendaDayContext(
        date: DateTime(2026, 8, 15),
        dateStr: '2026-08-15',
        isToday: true,
        prayerTimes: const {},
        options: const AgendaQueryOptions(),
      );

      final items = source.itemsForDate(ctx);
      // 20 overdue + 1 overflow card = 21 items
      expect(items, hasLength(21));
      final overflowCard = items.last;
      expect(overflowCard.meta['isOverdueOverflow'], isTrue);
      expect(overflowCard.meta['remainingCount'], equals(5));
      expect(overflowCard.title, contains('۵ مورد دیگر'));
    });

    test('M2-7: calendar_overdue_lookback_days is registered in SettingsRegistry with default 14', () {
      final desc = SettingsRegistry.all.firstWhere(
        (s) => s.key == 'calendar_overdue_lookback_days',
        orElse: () => throw Exception('calendar_overdue_lookback_days not found'),
      );
      expect(desc.group, equals(SettingsGroup.calendar));
      expect(desc.defaultValue, equals(14));
    });
  });
}
