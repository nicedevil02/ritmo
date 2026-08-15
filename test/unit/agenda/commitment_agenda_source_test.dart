import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/sources/agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/commitment_agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/goal_steps_agenda_source.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/modules/module_gate.dart';
import 'package:ritmo/core/settings/settings_registry.dart';

void main() {
  group('Phase M1-B: Commitments & Goals Gate (P5 / M1-4..M1-7)', () {
    test('CommitmentAgendaSource maps real commitment title, importance, and workKind correctly', () {
      final rows = [
        {
          'allocId': 'alloc_101',
          'dayKey': '2026-08-15',
          'plannedMinutes': 45,
          'timeWindowStart': '09:00',
          'timeWindowEnd': '10:00',
          'exactTime': '09:15',
          'allocStatus': 'DONE',
          'commId': 'comm_01',
          'commTitle': 'طراحی معماری پایگاه داده',
          'importance': 'MUST',
          'workKind': 'DEEP',
          'flexibility': 'FIXED',
        },
        {
          'allocId': 'alloc_102',
          'dayKey': '2026-08-15',
          'plannedMinutes': 20,
          'timeWindowStart': '16:00',
          'timeWindowEnd': '17:00',
          'exactTime': null,
          'allocStatus': 'PLANNED',
          'commId': 'comm_02',
          'commTitle': 'گفتگو با اعضای تیم',
          'importance': 'COULD',
          'workKind': 'SOCIAL',
          'flexibility': 'FLEXIBLE',
        },
      ];

      final source = CommitmentAgendaSource(
        allocationsByDate: {'2026-08-15': rows},
      );

      final ctx = AgendaDayContext(
        date: DateTime(2026, 8, 15),
        dateStr: '2026-08-15',
        isToday: true,
        prayerTimes: const {},
        options: const AgendaQueryOptions(),
      );

      final items = source.itemsForDate(ctx);
      expect(items, hasLength(2));

      // Item 1: MUST importance -> priority 2.0, isEssential true, fixed type, done completion, Category.work
      final item1 = items[0];
      expect(item1.id, equals('commitment:alloc_101:2026-08-15'));
      expect(item1.domain, equals(AgendaDomain.commitment));
      expect(item1.sourceId, equals('alloc_101'));
      expect(item1.title, equals('طراحی معماری پایگاه داده')); // Real title!
      expect(item1.priority, equals(2.0));
      expect(item1.isEssential, isTrue);
      expect(item1.itemType, equals(AgendaItemType.fixed));
      expect(item1.completion, equals(AgendaCompletion.done));
      expect(item1.category, equals(Category.work));
      expect(item1.timeOfDay, equals('09:15'));

      // Item 2: COULD importance -> priority 0.5, isEssential false, flexible type, pending completion, Category.social
      final item2 = items[1];
      expect(item2.id, equals('commitment:alloc_102:2026-08-15'));
      expect(item2.title, equals('گفتگو با اعضای تیم'));
      expect(item2.priority, equals(0.5));
      expect(item2.isEssential, isFalse);
      expect(item2.itemType, equals(AgendaItemType.flexible));
      expect(item2.completion, equals(AgendaCompletion.pending));
      expect(item2.category, equals(Category.personal));
      expect(item2.timeOfDay, equals('16:00'));
    });

    test('turning goals module OFF disables both goal steps and commitments', () {
      final settingsOff = <String, String>{'module_goals_enabled': 'false'};
      final isGoalsEnabled = ModuleGate.instance.isEnabledFrom(settingsOff, 'module_goals_enabled');
      expect(isGoalsEnabled, isFalse);

      final disabledGoalSteps = GoalStepsAgendaSource.disabled();
      expect(disabledGoalSteps.isEnabled, isFalse);

      final disabledCommitments = CommitmentAgendaSource.disabled();
      expect(disabledCommitments.isEnabled, isFalse);

      final ctx = AgendaDayContext(
        date: DateTime(2026, 8, 15),
        dateStr: '2026-08-15',
        isToday: true,
        prayerTimes: const {},
        options: const AgendaQueryOptions(),
      );

      expect(disabledGoalSteps.itemsForDate(ctx), isEmpty);
      expect(disabledCommitments.itemsForDate(ctx), isEmpty);
    });

    test('calendar_show_commitments is registered in SettingsRegistry', () {
      final desc = SettingsRegistry.all.firstWhere(
        (s) => s.key == 'calendar_show_commitments',
        orElse: () => throw Exception('calendar_show_commitments not found in SettingsRegistry'),
      );

      expect(desc.group, equals(SettingsGroup.calendar));
      expect(desc.type, equals(SettingType.boolean));
      expect(desc.defaultValue, isTrue);
    });
  });
}
