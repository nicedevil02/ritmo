import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/modules/module_content_map.dart';
import 'package:ritmo/core/modules/module_gate.dart';
import 'package:ritmo/core/modules/routine_visibility.dart';
import 'package:ritmo/core/services/sync/sync_module_gate.dart';

void main() {
  group('Module Content & Category Mapping Tests', () {
    test('ModuleContentMap correctly identifies owners of domains and categories', () {
      expect(ModuleContentMap.ownerOfDomain(AgendaDomain.prayer), 'module_religion_enabled');
      expect(ModuleContentMap.ownerOfDomain(AgendaDomain.medicine), 'module_medicine_enabled');
      expect(ModuleContentMap.ownerOfDomain(AgendaDomain.goalStep), 'module_goals_enabled');
      expect(ModuleContentMap.ownerOfDomain(AgendaDomain.course), 'module_courses_enabled');
      expect(ModuleContentMap.ownerOfDomain(AgendaDomain.konkur), 'module_study_enabled');
      expect(ModuleContentMap.ownerOfDomain(AgendaDomain.sport), anyOf('module_sports_enabled', 'module_supplementary_sports_enabled'));

      expect(ModuleContentMap.ownerOfCategory('religious'), 'module_religion_enabled');
      expect(ModuleContentMap.ownerOfCategory('medical'), 'module_medicine_enabled');
      expect(ModuleContentMap.ownerOfCategory('sports'), 'module_sports_enabled');
      expect(ModuleContentMap.ownerOfCategory('fitness'), 'module_sports_enabled');
      expect(ModuleContentMap.ownerOfCategory('learning'), 'module_courses_enabled');
      expect(ModuleContentMap.ownerOfCategory('konkur'), 'module_study_enabled');
      expect(ModuleContentMap.ownerOfCategory('personal'), 'module_today_routines');
    });

    test('RoutineVisibility filters routines by category when module is disabled', () {
      final settings = {
        'module_religion_enabled': 'false',
        'module_medicine_enabled': 'true',
        'module_sports_enabled': 'false',
        'module_supplementary_sports_enabled': 'false',
      };

      // Religious routine should be hidden
      final isReligiousVisible = RoutineVisibility.isVisible(
        routineId: 'routine_1',
        category: 'religious',
        settings: settings,
      );
      expect(isReligiousVisible, isFalse);

      // Medical routine should be visible
      final isMedicalVisible = RoutineVisibility.isVisible(
        routineId: 'routine_2',
        category: 'medical',
        settings: settings,
      );
      expect(isMedicalVisible, isTrue);

      // Fitness routine should be hidden
      final isFitnessVisible = RoutineVisibility.isVisible(
        routineId: 'routine_3',
        category: 'fitness',
        settings: settings,
      );
      expect(isFitnessVisible, isFalse);

      // Personal routine should always be visible
      final isPersonalVisible = RoutineVisibility.isVisible(
        routineId: 'routine_4',
        category: 'personal',
        settings: settings,
      );
      expect(isPersonalVisible, isTrue);
    });

    test('SyncModuleGate checks category enable state correctly', () {
      final settings = {
        'module_religion_enabled': 'false',
        'module_medicine_enabled': 'true',
        'module_study_enabled': 'false',
        'module_sports_enabled': 'true',
      };

      expect(SyncModuleGate.isModuleEnabled(Category.religious, settings), isFalse);
      expect(SyncModuleGate.isModuleEnabled(Category.medical, settings), isTrue);
      expect(SyncModuleGate.isModuleEnabled(Category.konkur, settings), isFalse);
      expect(SyncModuleGate.isModuleEnabled(Category.fitness, settings), isTrue);
      expect(SyncModuleGate.isModuleEnabled(Category.personal, settings), isTrue);
    });
  });
}
