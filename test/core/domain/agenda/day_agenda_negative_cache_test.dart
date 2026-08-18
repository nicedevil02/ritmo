import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CAL-40: Revision-stamped Negative Cache for Empty Days', () {
    test('invalidateAll and invalidateDate increment dataRevision', () {
      final service = DayAgendaService.instance;
      final initialRevision = service.dataRevision;

      service.invalidateDate('2026-08-18');
      expect(service.dataRevision, equals(initialRevision + 1));

      service.invalidateAll();
      expect(service.dataRevision, equals(initialRevision + 2));
    });
  });
}
