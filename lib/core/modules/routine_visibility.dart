import 'package:ritmo/core/modules/module_content_map.dart';
import 'package:ritmo/core/modules/module_gate.dart';

/// Single source-of-truth for whether a routine should be visible
/// across Home dashboard and Calendar agenda.
class RoutineVisibility {
  const RoutineVisibility._();

  /// System routines that are explicitly owned by a specific module.
  /// Key   → routineId (exact, case-sensitive)
  /// Value → module settings key
  static const Map<String, String> _systemRoutineOwners = {
    'worship_debt_routine': 'module_religion_enabled',
  };

  /// Returns `true` when the routine should be shown in the UI.
  ///
  /// Evaluates explicit system owners and routine categories against active modules.
  static bool isVisible({
    required String routineId,
    String? category,
    required Map<String, String> settings,
  }) {
    // 1. Check system routine explicit owner
    final owner = _systemRoutineOwners[routineId];
    if (owner != null) {
      return ModuleGate.instance.isEnabledFrom(settings, owner);
    }

    // 2. Check routine category against module gates
    if (category != null && category.isNotEmpty) {
      final categoryOwner = ModuleContentMap.ownerOfCategory(category);
      if (categoryOwner != null) {
        return ModuleGate.instance.isEnabledFrom(settings, categoryOwner);
      }
    }

    return true;
  }
}

