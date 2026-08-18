import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/features/calendar/presentation/logic/agenda_bucketing.dart';
import 'package:shamsi_date/shamsi_date.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CAL-34: Workday Recurrence Rule Strictness & Explicit Label', () {
    test('3 workdays (Saturday, Sunday, Monday) in a 7-day week does NOT get "روزهای کاری"', () {
      // 1405-05-24 (Sat), 1405-05-25 (Sun), 1405-05-26 (Mon)
      final d1 = Jalali(1405, 5, 24).toDateTime();
      final d2 = Jalali(1405, 5, 25).toDateTime();
      final d3 = Jalali(1405, 5, 26).toDateTime();

      final label = calculateRecurrenceLabel([d1, d2, d3], 7);

      expect(label, isNot(equals('روزهای کاری')));
      expect(label, equals('۳ روز از ۷'));
    });

    test('All 5 workdays (Saturday through Wednesday) in a 7-day week gets "روزهای کاری"', () {
      final dates = List.generate(5, (i) => Jalali(1405, 5, 24 + i).toDateTime());

      final label = calculateRecurrenceLabel(dates, 7);

      expect(label, equals('روزهای کاری'));
    });

    test('collapseRecurringSeries uses explicit recurrenceLabelFa when available on item', () {
      final items = List.generate(3, (i) {
        return AgendaItem(
          id: 'routine_explicit_$i',
          domain: AgendaDomain.routine,
          kind: AgendaItemKind.routine,
          sourceId: 'routine_explicit',
          title: 'Custom Routine',
          category: Category.fitness,
          deepLink: const AgendaDeepLink(domain: AgendaDomain.routine, targetId: 'routine_explicit'),
          dateStr: '2026-08-${18 + i}',
          timeOfDay: '08:00',
          recurrenceLabelFa: 'قاعده اختصاصی روتین',
        );
      });

      final entries = collapseRecurringSeries(items, daysInBucket: 7, minOccurrences: 3);

      expect(entries.length, equals(1));
      expect(entries.first, isA<AgendaSeries>());
      final series = entries.first as AgendaSeries;
      expect(series.recurrenceLabel, equals('قاعده اختصاصی روتین'));
    });
  });
}
