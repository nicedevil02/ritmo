import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/agenda_load_status.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_service.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/features/calendar/presentation/journey_controller.dart';

class StubAgendaService implements DayAgendaService {
  @override
  AgendaLoadStatus get lastLoadStatus => const AgendaLoadStatus.ok();

  @override
  Future<Map<String, DayAgenda>> agendaForRange(DateTime start, DateTime end, {AgendaQueryOptions? options}) async {
    return {};
  }

  @override
  Future<int> countOverdueBefore(DateTime cutoff) async => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSettingsService extends SettingsService {
  FakeSettingsService(this.storedScale) : super.test();

  final String? storedScale;

  @override
  String? getString(String key) {
    if (key == 'calendar_default_scale') return storedScale;
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CAL-22: loadDefaultScale via SettingsService and Priority Protection', () {
    test('loadDefaultScale reads setting and applies scale', () async {
      final fakeSettings = FakeSettingsService('month');
      final controller = JourneyController(agendaService: StubAgendaService());

      await controller.loadDefaultScale(settingsService: fakeSettings);

      expect(controller.activeScale, equals(JourneyScale.month));
    });

    test('loadDefaultScale does NOT override when scale was explicitly set by caller', () async {
      final fakeSettings = FakeSettingsService('month');
      final controller = JourneyController(agendaService: StubAgendaService());

      // Explicitly set scale to day
      controller.selectDate(DateTime.now(), scaleToSet: JourneyScale.day);
      expect(controller.scaleExplicitlySet, isTrue);
      expect(controller.activeScale, equals(JourneyScale.day));

      // Attempt to load default scale
      await controller.loadDefaultScale(settingsService: fakeSettings);

      // Must remain day!
      expect(controller.activeScale, equals(JourneyScale.day),
          reason: 'Explicitly set scale must never be overridden by loadDefaultScale');
    });

    test('Invalid scale value falls back to agenda without crash', () async {
      final fakeSettings = FakeSettingsService('corrupted_scale_val');
      final controller = JourneyController(agendaService: StubAgendaService());

      await controller.loadDefaultScale(settingsService: fakeSettings);

      expect(controller.activeScale, equals(JourneyScale.agenda));
    });
  });
}
