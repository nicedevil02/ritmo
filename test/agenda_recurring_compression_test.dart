import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/features/calendar/presentation/logic/agenda_bucketing.dart';

AgendaItem _createItem({
  required String id,
  required AgendaDomain domain,
  required String sourceId,
  required String title,
  required String dateStr,
  String? timeOfDay,
  Map<String, dynamic> meta = const {},
}) {
  return AgendaItem(
    id: id,
    domain: domain,
    sourceId: sourceId,
    title: title,
    dateStr: dateStr,
    timeOfDay: timeOfDay,
    category: Category.personal,
    deepLink: AgendaDeepLink(domain: domain, targetId: sourceId),
    meta: meta,
  );
}

void main() {
  group('Agenda Recurring Compression Tests', () {
    test('recurrenceKey correctly groups course items with different sessionIds', () {
      final item1 = _createItem(
        id: 'course:session_101',
        domain: AgendaDomain.course,
        sourceId: 'session_101',
        title: 'ریاضی 1',
        dateStr: '2026-08-15',
        timeOfDay: '10:00',
        meta: {'schedule': {'id': 'sched_math'}},
      );

      final item2 = _createItem(
        id: 'course:session_102',
        domain: AgendaDomain.course,
        sourceId: 'session_102',
        title: 'ریاضی 1',
        dateStr: '2026-08-16',
        timeOfDay: '10:00',
        meta: {'schedule': {'id': 'sched_math'}},
      );

      expect(item1.recurrenceKey, equals('course|sched_math|10:00'));
      expect(item2.recurrenceKey, equals('course|sched_math|10:00'));
      expect(item1.recurrenceKey, equals(item2.recurrenceKey));
    });

    test('recurrenceKey groups prayer items independently of shifting astronomical times', () {
      final fajrDay1 = _createItem(
        id: 'prayer:fajr:2026-08-15',
        domain: AgendaDomain.prayer,
        sourceId: 'fajr',
        title: 'نماز صبح',
        dateStr: '2026-08-15',
        timeOfDay: '04:18',
      );

      final fajrDay2 = _createItem(
        id: 'prayer:fajr:2026-08-16',
        domain: AgendaDomain.prayer,
        sourceId: 'fajr',
        title: 'نماز صبح',
        dateStr: '2026-08-16',
        timeOfDay: '04:19',
      );

      final fajrDay3 = _createItem(
        id: 'prayer:fajr:2026-08-17',
        domain: AgendaDomain.prayer,
        sourceId: 'fajr',
        title: 'نماز صبح',
        dateStr: '2026-08-17',
        timeOfDay: '04:20',
      );

      expect(fajrDay1.recurrenceKey, equals('prayer|fajr'));
      expect(fajrDay2.recurrenceKey, equals('prayer|fajr'));
      expect(fajrDay3.recurrenceKey, equals('prayer|fajr'));

      final collapsed = collapseRecurringSeries([fajrDay1, fajrDay2, fajrDay3], daysInBucket: 7);
      expect(collapsed.length, equals(1));
      expect(collapsed.first, isA<AgendaSeries>());
      final series = collapsed.first as AgendaSeries;
      expect(series.instances.length, equals(3));
      expect(series.representative.title, equals('نماز صبح'));
    });

    test('calculateRecurrenceLabel: 7 days out of 7 returns هر روز', () {
      final dates = [
        DateTime(2026, 8, 15), // Sat
        DateTime(2026, 8, 16), // Sun
        DateTime(2026, 8, 17), // Mon
        DateTime(2026, 8, 18), // Tue
        DateTime(2026, 8, 19), // Wed
        DateTime(2026, 8, 20), // Thu
        DateTime(2026, 8, 21), // Fri
      ];
      final label = calculateRecurrenceLabel(dates, 7);
      expect(label, equals('هر روز'));
    });

    test('calculateRecurrenceLabel: 5 days Sat-Wed out of 7 returns روزهای کاری', () {
      final dates = [
        DateTime(2026, 8, 15), // Sat (Jalali 1)
        DateTime(2026, 8, 16), // Sun (Jalali 2)
        DateTime(2026, 8, 17), // Mon (Jalali 3)
        DateTime(2026, 8, 18), // Tue (Jalali 4)
        DateTime(2026, 8, 19), // Wed (Jalali 5)
      ];
      final label = calculateRecurrenceLabel(dates, 7);
      expect(label, equals('روزهای کاری'));
    });

    test('calculateRecurrenceLabel: 5 days out of 7 non-workdays returns ۵ روز از ۷', () {
      final dates = [
        DateTime(2026, 8, 15), // Sat
        DateTime(2026, 8, 16), // Sun
        DateTime(2026, 8, 18), // Tue
        DateTime(2026, 8, 20), // Thu
        DateTime(2026, 8, 21), // Fri
      ];
      final label = calculateRecurrenceLabel(dates, 7);
      expect(label, equals('۵ روز از ۷'));
    });

    test('calculateRecurrenceLabel: single weekday across weeks returns plural weekday (e.g. شنبه‌ها)', () {
      final dates = [
        DateTime(2026, 8, 15), // Sat
        DateTime(2026, 8, 22), // Sat
        DateTime(2026, 8, 29), // Sat
      ];
      final label = calculateRecurrenceLabel(dates, 21);
      expect(label, equals('شنبه‌ها'));
    });

    test('collapseRecurringSeries: items under 3 occurrences are NOT compressed', () {
      final items = [
        _createItem(
          id: 'routine:1:day1',
          domain: AgendaDomain.routine,
          sourceId: '1',
          title: 'پیاده‌روی',
          dateStr: '2026-08-15',
          meta: {'routine': {'id': 'r_walk'}},
        ),
        _createItem(
          id: 'routine:1:day2',
          domain: AgendaDomain.routine,
          sourceId: '1',
          title: 'پیاده‌روی',
          dateStr: '2026-08-16',
          meta: {'routine': {'id': 'r_walk'}},
        ),
      ];

      final entries = collapseRecurringSeries(items, daysInBucket: 7, minOccurrences: 3);
      expect(entries.length, equals(2));
      expect(entries.every((e) => e is AgendaSingle), isTrue);
    });

    test('collapseRecurringSeries: 3+ instances compressed into AgendaSeries and unique items appear at top', () {
      final items = [
        // 3 instances of routine "ورزش صبحگاهی"
        _createItem(
          id: 'r1',
          domain: AgendaDomain.routine,
          sourceId: 'routine_ex',
          title: 'ورزش صبحگاهی',
          dateStr: '2026-08-15',
          timeOfDay: '07:00',
          meta: {'routine': {'id': 'r_ex'}},
        ),
        _createItem(
          id: 'r2',
          domain: AgendaDomain.routine,
          sourceId: 'routine_ex',
          title: 'ورزش صبحگاهی',
          dateStr: '2026-08-16',
          timeOfDay: '07:00',
          meta: {'routine': {'id': 'r_ex'}},
        ),
        _createItem(
          id: 'r3',
          domain: AgendaDomain.routine,
          sourceId: 'routine_ex',
          title: 'ورزش صبحگاهی',
          dateStr: '2026-08-17',
          timeOfDay: '07:00',
          meta: {'routine': {'id': 'r_ex'}},
        ),
        // 1 unique task
        _createItem(
          id: 't1',
          domain: AgendaDomain.task,
          sourceId: 'task_unique',
          title: 'خرید کتاب پایتون',
          dateStr: '2026-08-18',
        ),
      ];

      final entries = collapseRecurringSeries(items, daysInBucket: 7, minOccurrences: 3);

      expect(entries.length, equals(2));
      // First entry MUST be the AgendaSingle (unique item at top)
      expect(entries[0], isA<AgendaSingle>());
      final single = entries[0] as AgendaSingle;
      expect(single.item.title, equals('خرید کتاب پایتون'));

      // Second entry MUST be the AgendaSeries (recurring series at bottom)
      expect(entries[1], isA<AgendaSeries>());
      final series = entries[1] as AgendaSeries;
      expect(series.representative.title, equals('ورزش صبحگاهی'));
      expect(series.instances.length, equals(3));
    });
  });
}
