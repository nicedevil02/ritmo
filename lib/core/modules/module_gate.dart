import 'package:flutter/foundation.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/modules/module_content_map.dart';
import 'package:ritmo/core/modules/module_registry.dart';
import 'package:ritmo/core/services/feature_limits.dart';
import 'package:ritmo/core/settings/settings_service.dart';

class ModuleGate {
  ModuleGate._();
  static final ModuleGate instance = ModuleGate._();

  final ValueNotifier<Map<String, bool>> states =
      ValueNotifier(const <String, bool>{});

  Future<void> load() async {
    await refresh();
  }

  Future<void> refresh() async {
    final newStates = <String, bool>{};
    for (final desc in ModuleRegistry.modules) {
      if (desc.isCore) {
        newStates[desc.key] = true;
      } else {
        newStates[desc.key] = SettingsService.instance.get<bool>(desc.key);
      }
    }
    states.value = newStates;
  }

  bool isEnabled(String moduleKey) {
    var effectiveKey = moduleKey;
    if (moduleKey == 'module_sports_enabled' ||
        moduleKey == 'module_movement_enabled') {
      effectiveKey = 'module_supplementary_sports_enabled';
    } else if (moduleKey == 'module_health_enabled') {
      effectiveKey = 'module_medicine_enabled';
    }

    final desc = ModuleRegistry.findByKey(effectiveKey);
    if (desc != null) {
      if (desc.isCore) return true;
      return SettingsService.instance.get<bool>(desc.key);
    }
    RitmoLog.warning('Modules', 'درخواست وضعیت برای ماژول ناشناخته "$moduleKey"');
    return false;
  }

  bool isEnabledFrom(Map<String, String> settings, String moduleKey) {
    var effectiveKey = moduleKey;
    if (moduleKey == 'module_sports_enabled' ||
        moduleKey == 'module_movement_enabled') {
      effectiveKey = 'module_supplementary_sports_enabled';
    } else if (moduleKey == 'module_health_enabled') {
      effectiveKey = 'module_medicine_enabled';
    }

    final desc = ModuleRegistry.findByKey(effectiveKey);
    if (desc == null) {
      RitmoLog.warning('Modules', 'ماژول ناشناخته "$moduleKey" در نقشه تنظیمات');
      return false;
    }
    if (desc.isCore) return true;
    final rawVal = settings[effectiveKey];
    if (rawVal == null) return desc.defaultEnabled;
    return rawVal == 'true' || rawVal == '1' || rawVal == 'yes';
  }

  bool isDomainEnabled(AgendaDomain domain) {
    final owner = ModuleContentMap.ownerOfDomain(domain);
    if (owner == null) return true;
    return isEnabled(owner);
  }

  bool isCategoryEnabled(String routineCategory) {
    final owner = ModuleContentMap.ownerOfCategory(routineCategory);
    if (owner == null) return true;
    return isEnabled(owner);
  }

  Set<String> get enabledKeys {
    return ModuleRegistry.modules
        .where((m) => isEnabled(m.key))
        .map((m) => m.key)
        .toSet();
  }

  Set<String> get disabledKeys {
    return ModuleRegistry.modules
        .where((m) => !isEnabled(m.key))
        .map((m) => m.key)
        .toSet();
  }

  int get activeOptionalModuleCount {
    return ModuleRegistry.modules
        .where((m) => !m.isCore && isEnabled(m.key))
        .length;
  }

  bool get canActivateMoreModules {
    return activeOptionalModuleCount < FeatureLimits.current.maxActiveModules;
  }
}
