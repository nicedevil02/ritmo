import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/sources/agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/cycle_agenda_source.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/features/calendar/presentation/logic/agenda_bucketing.dart';

void main() {
  group('Cycle Reminder & Upcoming Unique Banner Visibility Tests', () {
    test('1. Future countdown reminders are hidden before that day arrives, but period start event is shown', () {
      final periodStart = DateTime(2026, 9, 15); // 24 Shahrivar 1405
      final pmsStart = DateTime(2026, 9, 11); // 20 Shahrivar 1405 (reminder on 19 Shahrivar)

      final output = CycleEngineOutput(
        currentPhase: CyclePhase.follicular,
        dayOfCycle: 10,
        dayOfPeriod: 0,
        nextPeriodPrediction: periodStart,
        fertileWindowStart: null,
        fertileWindowEnd: null,
        ovulationDay: null,
        isIrregular: false,
        stats: CycleStats(avgCycleLength: 28, avgPeriodDuration: 5, totalRecordedCycles: 2),
        dataMaturity: 'HIGH',
        hasData: true,
        nextPeriodWindowStart: periodStart,
        nextPeriodWindowEnd: periodStart.add(const Duration(days: 4)),
        pmsWindowStart: pmsStart,
        pmsWindowEnd: periodStart,
        regularityScore: 90,
        trendPoints: const [],
        regularityLabel: 'منظم',
        predictionDisclaimer: '',
      );

      final source = CycleAgendaSource(
        cycleOutput: output,
        cycleAllowed: true,
        reminderLeadDays: const [3, 1],
        consentReminders: true,
      );

      // Scenario A: Future date 2026-09-10 (19 Shahrivar) viewed while today is 2026-08-29 (isToday: false)
      // The countdown reminder "احتمال شروع علائم PMS از فردا" must NOT be produced ahead of time!
      final ctxFuturePms = AgendaDayContext(
        date: DateTime(2026, 9, 10),
        dateStr: '2026-09-10',
        isToday: false,
        prayerTimes: const {},
        options: const AgendaQueryOptions(),
      );
      final itemsFuturePms = source.itemsForDate(ctxFuturePms);
      expect(
        itemsFuturePms.any((i) => i.title.contains('علائم PMS')),
        isFalse,
        reason: 'Future PMS reminder must not appear before that day arrives',
      );

      // Scenario B: Future date 2026-09-12 (21 Shahrivar) viewed ahead of time (isToday: false)
      // The countdown reminder "۳ روز تا شروع..." must NOT appear ahead of time!
      final ctxFuture3Days = AgendaDayContext(
        date: DateTime(2026, 9, 12),
        dateStr: '2026-09-12',
        isToday: false,
        prayerTimes: const {},
        options: const AgendaQueryOptions(),
      );
      final itemsFuture3Days = source.itemsForDate(ctxFuture3Days);
      expect(
        itemsFuture3Days.any((i) => i.title.contains('۳ روز تا شروع')),
        isFalse,
        reason: 'Future 3-day period reminder must not appear ahead of time',
      );

      // Scenario C: On the actual day of predicted period start 2026-09-15 (24 Shahrivar)
      // A clean calendar event marker "شروع احتمالی قاعدگی" MUST be present!
      final ctxPeriodStart = AgendaDayContext(
        date: DateTime(2026, 9, 15),
        dateStr: '2026-09-15',
        isToday: false,
        prayerTimes: const {},
        options: const AgendaQueryOptions(),
      );
      final itemsPeriodStart = source.itemsForDate(ctxPeriodStart);
      expect(itemsPeriodStart, hasLength(1));
      expect(itemsPeriodStart.first.title, equals('شروع احتمالی قاعدگی'));
      expect(itemsPeriodStart.first.kind, equals(AgendaItemKind.event));
      expect(itemsPeriodStart.first.domain, equals(AgendaDomain.cycle));

      // Scenario D: When that day actually arrives (isToday: true on 2026-09-10)
      // The PMS reminder MUST appear on that day!
      final ctxTodayPms = AgendaDayContext(
        date: DateTime(2026, 9, 10),
        dateStr: '2026-09-10',
        isToday: true,
        prayerTimes: const {},
        options: const AgendaQueryOptions(),
      );
      final itemsTodayPms = source.itemsForDate(ctxTodayPms);
      expect(
        itemsTodayPms.any((i) => i.title.contains('احتمال شروع علائم PMS از فردا')),
        isTrue,
        reason: 'PMS reminder must appear when that day arrives (isToday: true)',
      );
    });

    test('2. Upcoming Unique Banner excludes cycle items and reminder kinds', () {
      // Simulate future bucket containing a cycle reminder, a cycle event, and a user task
      final cycleReminder = AgendaItem(
        id: 'cycle:lead_pms:2026-09-10',
        domain: AgendaDomain.cycle,
        kind: AgendaItemKind.reminder,
        sourceId: 'lead_pms',
        title: 'یادآوری: احتمال شروع علائم PMS از فردا',
        dateStr: '2026-09-10',
        category: Category.personal,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.cycle, targetId: '2026-09-10'),
      );

      final cycleEvent = AgendaItem(
        id: 'cycle:predicted_start:2026-09-15',
        domain: AgendaDomain.cycle,
        kind: AgendaItemKind.event,
        sourceId: 'predicted_start',
        title: 'شروع احتمالی قاعدگی',
        dateStr: '2026-09-15',
        category: Category.personal,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.cycle, targetId: '2026-09-15'),
      );

      final userTask = AgendaItem(
        id: 'task:task_101:2026-09-02',
        domain: AgendaDomain.task,
        kind: AgendaItemKind.task,
        sourceId: 'task_101',
        title: 'ارسال پیش‌فاکتور به مشتری',
        dateStr: '2026-09-02',
        category: Category.work,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.task, targetId: 'task_101'),
      );

      final bucketed = <AgendaBucket, List<AgendaItem>>{
        AgendaBucket.today: [],
        AgendaBucket.tomorrow: [],
        AgendaBucket.thisWeek: [userTask],
        AgendaBucket.nextWeek: [],
        AgendaBucket.later: [cycleReminder, cycleEvent],
      };

      final futureBuckets = [
        AgendaBucket.today,
        AgendaBucket.tomorrow,
        AgendaBucket.thisWeek,
        AgendaBucket.nextWeek,
        AgendaBucket.later,
      ];

      final allFutureItems = <AgendaItem>[];
      for (final b in futureBuckets) {
        if (bucketed[b] != null) {
          allFutureItems.addAll(bucketed[b]!);
        }
      }

      final keyCounts = <String, int>{};
      for (final item in allFutureItems) {
        keyCounts[item.recurrenceKey] = (keyCounts[item.recurrenceKey] ?? 0) + 1;
      }

      final uniques = allFutureItems.where((i) {
        if (i.isCompleted) return false;
        if (i.domain == AgendaDomain.cycle) return false;
        if (i.kind == AgendaItemKind.reminder) return false;
        final cnt = keyCounts[i.recurrenceKey] ?? 0;
        return cnt < 3;
      }).toList();

      expect(uniques, hasLength(1));
      expect(uniques.first.title, equals('ارسال پیش‌فاکتور به مشتری'));
      expect(uniques.any((i) => i.domain == AgendaDomain.cycle), isFalse);
    });
  });
}
