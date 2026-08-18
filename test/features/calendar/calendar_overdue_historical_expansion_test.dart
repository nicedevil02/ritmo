import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_service.dart';
import 'package:ritmo/features/calendar/presentation/journey_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CAL-38: Historical Overdue Expansion in Agenda', () {
    test('agendaExpandedDaysBack constant is defined as 365', () {
      expect(JourneyController.agendaExpandedDaysBack, equals(365));
    });

    test('countOverdueBefore method exists on DayAgendaService and returns integer', () async {
      final service = DayAgendaService.instance;
      final count = await service.countOverdueBefore(DateTime(2026, 8, 18));
      expect(count, isA<int>());
    });
  });
}
