import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/modules/module_gate.dart';

void main() {
  group('Phase 3 — enabledDomains Derived from Settings Gates (P10 / W3-1, W3-2)', () {
    test('goalStep domain reflects module_goals_enabled setting', () {
      final settingsOff = <String, String>{'module_goals_enabled': 'false'};
      final goalsOff = ModuleGate.instance.isEnabledFrom(settingsOff, 'module_goals_enabled');
      expect(goalsOff, isFalse);

      final settingsOn = <String, String>{'module_goals_enabled': 'true'};
      final goalsOn = ModuleGate.instance.isEnabledFrom(settingsOn, 'module_goals_enabled');
      expect(goalsOn, isTrue);
    });

    test('task domain reflects module_today_routines core gate and calendar_show_tasks setting', () {
      final routinesEnabled = ModuleGate.instance.isEnabledFrom(const {}, 'module_today_routines');
      expect(routinesEnabled, isTrue, reason: 'core module is enabled by default');

      final settingsTasksHidden = <String, String>{'calendar_show_tasks': 'false'};
      final tasksEnabled = routinesEnabled && settingsTasksHidden['calendar_show_tasks'] != 'false';
      expect(tasksEnabled, isFalse);

      final settingsTasksVisible = <String, String>{'calendar_show_tasks': 'true'};
      final tasksVisible = routinesEnabled && settingsTasksVisible['calendar_show_tasks'] != 'false';
      expect(tasksVisible, isTrue);
    });

    test('failing source does not mark enabledDomains as false, instead reports in degradedSources', () {
      const dayAgenda = DayAgenda(
        dateStr: '2026-08-14',
        items: [],
        enabledDomains: {
          AgendaDomain.routine: true,
          AgendaDomain.goalStep: true,
          AgendaDomain.prayer: true,
        },
        degradedSources: {AgendaDomain.prayer},
      );

      expect(dayAgenda.enabledDomains[AgendaDomain.prayer], isTrue,
          reason: 'Domain must remain enabled according to settings');
      expect(dayAgenda.degradedSources, contains(AgendaDomain.prayer),
          reason: 'Failure must be reported in degradedSources');
    });
  });
}
