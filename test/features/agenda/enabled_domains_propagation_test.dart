import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_snapshot_builder.dart';

void main() {
  group('B0-5: Enabled Domains Propagation in DayAgendaSnapshot', () {
    test('DayAgendaSnapshotBuilder propagates enabledDomains from DayAgenda to DayAgendaSnapshot', () {
      final enabledMap = <AgendaDomain, bool>{
        AgendaDomain.routine: true,
        AgendaDomain.event: true,
        AgendaDomain.prayer: false,
        AgendaDomain.sport: true,
        AgendaDomain.medicine: false,
        AgendaDomain.course: false,
      };

      final dayAgenda = DayAgenda(
        dateStr: '2026-08-14',
        items: const [],
        rhythmScore: 100,
        enabledDomains: enabledMap,
      );

      const builder = DayAgendaSnapshotBuilder();
      final snapshot = builder.buildSnapshot(dayAgenda);

      expect(snapshot.enabledDomains, equals(enabledMap));
      expect(snapshot.enabledDomains[AgendaDomain.event], isTrue);
      expect(snapshot.enabledDomains[AgendaDomain.prayer], isFalse);
      expect(snapshot.enabledDomains[AgendaDomain.medicine], isFalse);
    });
  });
}
