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

class MemorySettingsService extends SettingsService {
  MemorySettingsService() : super.test();

  final Map<String, String> values = {};

  @override
  String? getString(String key) => values[key];

  @override
  Future<bool> setString(String key, String value) async {
    values[key] = value;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CAL-23: Calendar Scale Persistence', () {
    test('setScale persists scale name to SettingsService', () async {
      final fakeSettings = MemorySettingsService();
      final controller = JourneyController(agendaService: StubAgendaService());

      controller.setScale(JourneyScale.week, settingsService: fakeSettings);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(fakeSettings.values['calendar_default_scale'], equals('week'));

      controller.setScale(JourneyScale.month, settingsService: fakeSettings);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(fakeSettings.values['calendar_default_scale'], equals('month'));
    });

    test('scaleToString is 1-to-1 with JourneyScale enum names', () {
      for (final scale in JourneyScale.values) {
        expect(JourneyController.scaleToString(scale), equals(scale.name));
      }
    });
  });
}
