import 'package:ritmo/core/modules/module_gate.dart';

/// Single source-of-truth for whether a routine should be visible
/// across Home dashboard and Calendar agenda.
///
/// Rule: routines created by the user are *always* visible regardless of
/// which module is enabled. Only system-owned routines (like the worship-debt
/// routine) follow their owning module's gate.
class RoutineVisibility {
  const RoutineVisibility._();

  /// System routines that are owned by a specific module.
  /// Key   → routineId (exact, case-sensitive)
  /// Value → module settings key
  static const Map<String, String> _systemRoutineOwners = {
    'worship_debt_routine': 'module_religion_enabled',
  };

  /// Returns `true` when the routine should be shown in the UI.
  ///
  /// User-created routines (not in [_systemRoutineOwners]) are always visible.
  /// System routines are shown only when their owning module is enabled.
  static bool isVisible({
    required String routineId,
    required Map<String, String> settings,
  }) {
    final owner = _systemRoutineOwners[routineId];
    if (owner == null) return true; // user-created → always visible
    return ModuleGate.instance.isEnabledFrom(settings, owner);
  }
}
