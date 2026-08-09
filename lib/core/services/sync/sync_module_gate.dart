import 'package:ritmo/core/modules/module_gate.dart';
import 'package:ritmo/core/domain/models.dart';

class SyncModuleGate {
  static bool isModuleEnabled(Category category, Map<String, String> settings) {
    switch (category) {
      case Category.religious:
        return ModuleGate.instance.isEnabledFrom(settings, 'module_religion_enabled');
      case Category.medical:
        return ModuleGate.instance.isEnabledFrom(settings, 'module_medicine_enabled');
      case Category.learning:
        return ModuleGate.instance.isEnabledFrom(settings, 'module_courses_enabled');
      case Category.konkur:
        return ModuleGate.instance.isEnabledFrom(settings, 'module_study_enabled');
      case Category.custom:
        return true;
      default:
        return true;
    }
  }
}
