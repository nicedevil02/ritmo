import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_snapshot_builder.dart';
import 'package:ritmo/core/domain/agenda/models/day_agenda_snapshot.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/features/calendar/presentation/logic/agenda_bucketing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CAL-37: Elimination of Silent Catches in Agenda Bucketing', () {
    test('bucketRange gracefully handles invalid dateKey entries while processing valid ones', () {
      final now = DateTime(2026, 8, 18);
      final validItem = AgendaItem(
        id: 'valid_1',
        domain: AgendaDomain.routine,
        kind: AgendaItemKind.routine,
        sourceId: 'src_1',
        title: 'Valid Item',
        category: Category.fitness,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.routine, targetId: 'src_1'),
        dateStr: '2026-08-18',
        timeOfDay: '07:00',
      );

      const builder = DayAgendaSnapshotBuilder();
      final snapshots = <String, DayAgendaSnapshot>{
        'invalid-date-format': builder.buildSnapshot(DayAgenda.empty('invalid-date-format')),
        '2026-08-18': builder.buildSnapshot(DayAgenda(
          dateStr: '2026-08-18',
          items: [validItem],
        )),
      };

      final result = bucketRange(snapshots, now: now);

      expect(result[AgendaBucket.today], contains(validItem));
    });

    test('daySubGroupLabel returns Persianized fallback on invalid input without throwing', () {
      final label = daySubGroupLabel('not-a-real-date-123');
      expect(label, contains('۱۲۳'));
    });
  });
}
