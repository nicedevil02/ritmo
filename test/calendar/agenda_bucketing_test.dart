import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/models/day_agenda_snapshot.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/utils/date_key.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/calendar/presentation/logic/agenda_bucketing.dart';
import 'package:shamsi_date/shamsi_date.dart';

void main() {
  group('CAL-53: Comprehensive Agenda Bucketing Tests', () {
    test('1. No duplication & no loss across a 30-day dataset', () {
      final baseDate = DateTime(2026, 8, 1);
      final now = DateTime(2026, 8, 15, 12, 0); // Saturday or mid-month
      final snapshots = <String, DayAgendaSnapshot>{};

      int totalItemsCreated = 0;
      int completedPastItemsCount = 0;

      for (int i = 0; i < 30; i++) {
        final d = DateKey.addDays(baseDate, i);
        final dStr = DateKey.of(d);
        final items = <AgendaItem>[];

        for (int j = 0; j < 3; j++) {
          final isDone = (i < 14 && j == 0);
          final item = AgendaItem(
            id: 'item_${dStr}_$j',
            sourceId: 'src_${dStr}_$j',
            title: 'فعالیت $j در $dStr',
            domain: AgendaDomain.routine,
            kind: AgendaItemKind.routine,
            category: Category.personal,
            dateStr: dStr,
            timeOfDay: '${(9 + j).toString().padLeft(2, '0')}:00',
            durationMinutes: 30,
            completion: isDone ? AgendaCompletion.done : AgendaCompletion.none,
            deepLink: AgendaDeepLink(domain: AgendaDomain.routine, targetId: 'src_${dStr}_$j'),
          );
          items.add(item);
          totalItemsCreated++;
          if (i < 14 && isDone) {
            completedPastItemsCount++;
          }
        }

        snapshots[dStr] = DayAgendaSnapshot(
          dayAgenda: DayAgenda(dateStr: dStr, items: items),
          completedCount: items.where((x) => x.isCompleted).length,
          remainingCount: items.where((x) => !x.isCompleted).length,
          freeGaps: const [],
          conflicts: const [],
          overloadScore: 0,
          suggestions: const [],
        );
      }

      final bucketed = bucketRange(snapshots, now: now);

      // Verify no item appears in multiple buckets
      final seenIds = <String>{};
      int totalBucketedItems = 0;

      for (final bucket in AgendaBucket.values) {
        final itemsInBucket = bucketed[bucket] ?? [];
        for (final item in itemsInBucket) {
          expect(seenIds.contains(item.id), isFalse, reason: 'Duplicate item found in bucket ${bucket.name}: ${item.id}');
          seenIds.add(item.id);
          totalBucketedItems++;
        }
      }

      // Verify no loss: bucketed items + completed past items = total items
      expect(totalBucketedItems + completedPastItemsCount, equals(totalItemsCreated));
    });

    test('2. Boundary tests for now on every weekday (Saturday to Friday)', () {
      // 2026-08-15 is Saturday, 2026-08-21 is Friday
      final sat = DateTime(2026, 8, 15);

      for (int offset = 0; offset < 7; offset++) {
        final testNow = DateKey.addDays(sat, offset);
        final testNowStr = DateKey.of(testNow);
        final tomorrowStr = DateKey.of(DateKey.addDays(testNow, 1));

        final itemToday = AgendaItem(
          id: 'today_$offset',
          sourceId: 'src_t',
          title: 'امروز',
          domain: AgendaDomain.routine,
          kind: AgendaItemKind.routine,
          category: Category.personal,
          dateStr: testNowStr,
          deepLink: const AgendaDeepLink(domain: AgendaDomain.routine, targetId: 'src_t'),
        );

        final itemTomorrow = AgendaItem(
          id: 'tomorrow_$offset',
          sourceId: 'src_tm',
          title: 'فردا',
          domain: AgendaDomain.routine,
          kind: AgendaItemKind.routine,
          category: Category.personal,
          dateStr: tomorrowStr,
          deepLink: const AgendaDeepLink(domain: AgendaDomain.routine, targetId: 'src_tm'),
        );

        final snapshots = {
          testNowStr: DayAgendaSnapshot(
            dayAgenda: DayAgenda(dateStr: testNowStr, items: [itemToday]),
            completedCount: 0,
            remainingCount: 1,
            freeGaps: const [],
            conflicts: const [],
            overloadScore: 0,
            suggestions: const [],
          ),
          tomorrowStr: DayAgendaSnapshot(
            dayAgenda: DayAgenda(dateStr: tomorrowStr, items: [itemTomorrow]),
            completedCount: 0,
            remainingCount: 1,
            freeGaps: const [],
            conflicts: const [],
            overloadScore: 0,
            suggestions: const [],
          ),
        };

        final bucketed = bucketRange(snapshots, now: testNow);
        expect(bucketed[AgendaBucket.today]!.map((i) => i.id), contains(itemToday.id));
        expect(bucketed[AgendaBucket.tomorrow]!.map((i) => i.id), contains(itemTomorrow.id));
      }
    });

    test('3. Thursday & Friday: calculateDaysInBucket returns 0 for thisWeek (no "از ۱")', () {
      // Find a Thursday and Friday
      final thursday = DateTime(2026, 8, 20); // Thursday
      final friday = DateTime(2026, 8, 21); // Friday

      final daysThu = calculateDaysInBucket(AgendaBucket.thisWeek, now: thursday, items: const []);
      final daysFri = calculateDaysInBucket(AgendaBucket.thisWeek, now: friday, items: const []);

      expect(daysThu, equals(0));
      expect(daysFri, equals(0));
    });

    test('4. calculateRecurrenceLabel patterns: every day, workdays, plural weekday, fractions', () {
      // 1. Every day (n == m)
      final allDays = [
        DateTime(2026, 8, 15),
        DateTime(2026, 8, 16),
        DateTime(2026, 8, 17),
      ];
      expect(calculateRecurrenceLabel(allDays, 3), equals('هر روز'));

      // 2. Workdays (Saturday to Wednesday = 5 workdays in Shamsi)
      final workdays = [
        Jalali(1405, 5, 24).toDateTime(), // Saturday (1)
        Jalali(1405, 5, 25).toDateTime(), // Sunday (2)
        Jalali(1405, 5, 26).toDateTime(), // Monday (3)
        Jalali(1405, 5, 27).toDateTime(), // Tuesday (4)
        Jalali(1405, 5, 28).toDateTime(), // Wednesday (5)
      ];
      expect(calculateRecurrenceLabel(workdays, 7), equals('روزهای کاری'));

      // 3. Same weekday plural (e.g. all Saturdays)
      final saturdays = [
        Jalali(1405, 5, 24).toDateTime(), // Saturday
        Jalali(1405, 5, 31).toDateTime(), // Saturday
      ];
      expect(calculateRecurrenceLabel(saturdays, 14), equals('شنبه‌ها'));

      // 4. Fraction
      final fractionDays = [
        Jalali(1405, 5, 24).toDateTime(),
        Jalali(1405, 5, 26).toDateTime(),
      ];
      expect(calculateRecurrenceLabel(fractionDays, 7), equals('${toPersianDigits(2)} روز از ${toPersianDigits(7)}'));
    });

    test('5. Chronological unified ordering of singles and series', () {
      final items = [
        AgendaItem(
          id: 'rec_3',
          sourceId: 'rec_grp',
          title: 'روتین روزانه مکرر',
          domain: AgendaDomain.routine,
          kind: AgendaItemKind.routine,
          category: Category.work,
          dateStr: '2026-08-18',
          timeOfDay: '11:00',
          deepLink: const AgendaDeepLink(domain: AgendaDomain.routine, targetId: 'rec_grp'),
        ),
        AgendaItem(
          id: 'rec_1',
          sourceId: 'rec_grp',
          title: 'روتین روزانه مکرر',
          domain: AgendaDomain.routine,
          kind: AgendaItemKind.routine,
          category: Category.work,
          dateStr: '2026-08-16',
          timeOfDay: '11:00',
          deepLink: const AgendaDeepLink(domain: AgendaDomain.routine, targetId: 'rec_grp'),
        ),
        AgendaItem(
          id: 'rec_2',
          sourceId: 'rec_grp',
          title: 'روتین روزانه مکرر',
          domain: AgendaDomain.routine,
          kind: AgendaItemKind.routine,
          category: Category.work,
          dateStr: '2026-08-17',
          timeOfDay: '11:00',
          deepLink: const AgendaDeepLink(domain: AgendaDomain.routine, targetId: 'rec_grp'),
        ),
        AgendaItem(
          id: 'single_early',
          sourceId: 's_early',
          title: 'تک رویداد زودهنگام',
          domain: AgendaDomain.event,
          kind: AgendaItemKind.event,
          category: Category.personal,
          dateStr: '2026-08-16',
          timeOfDay: '08:00',
          deepLink: const AgendaDeepLink(domain: AgendaDomain.event, targetId: 's_early'),
        ),
      ];

      final collapsed = collapseRecurringSeries(items, daysInBucket: 7, minOccurrences: 3);
      expect(collapsed.length, equals(2));
      expect(collapsed[0], isA<AgendaSingle>());
      expect(collapsed[0].anchor.id, equals('single_early'));
      expect(collapsed[1], isA<AgendaSeries>());
      expect((collapsed[1] as AgendaSeries).instances.length, equals(3));
    });

    test('6. daySubGroupLabel generates valid Persian formatting with digits and weekday name', () {
      final label = daySubGroupLabel('2026-08-18');
      expect(label, contains('مرداد'));
      expect(label, contains(toPersianDigits('27')));
    });

    test('7. Invalid date key does not throw uncaught exceptions and does not crash', () {
      final invalidSnapshot = DayAgendaSnapshot(
        dayAgenda: DayAgenda(dateStr: 'invalid-date', items: [
          AgendaItem(
            id: 'inv_1',
            sourceId: 'src_inv',
            title: 'نامعتبر',
            domain: AgendaDomain.routine,
            kind: AgendaItemKind.routine,
            category: Category.personal,
            dateStr: 'invalid-date',
            deepLink: const AgendaDeepLink(domain: AgendaDomain.routine, targetId: 'src_inv'),
          ),
        ]),
        completedCount: 0,
        remainingCount: 1,
        freeGaps: const [],
        conflicts: const [],
        overloadScore: 0,
        suggestions: const [],
      );

      final bucketed = bucketRange({'invalid-date': invalidSnapshot}, now: DateTime.now());
      expect(bucketed, isNotNull);
    });
  });
}
