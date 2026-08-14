import 'package:flutter/foundation.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/modules/module_content_map.dart';
import 'package:ritmo/core/modules/module_registry.dart';
import 'package:ritmo/core/observability/ritmo_logger.dart';
import 'package:ritmo/core/services/feature_limits.dart';

class ModuleGate {
  ModuleGate._();
  static final ModuleGate instance = ModuleGate._();

  /// تنها نقطهٔ حقیقت. همیشه در‌دسترس، بدون await.
  final ValueNotifier<Map<String, bool>> states =
      ValueNotifier(const <String, bool>{});

  Future<void> load() async {
    await refresh();
  }

  Future<void> refresh() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'app_settings',
      where: 'key LIKE ?',
      whereArgs: ['module_%'],
    );
    final rawMap = <String, String>{};
    for (final row in rows) {
      rawMap[row['key'] as String] = row['value'] as String;
    }
    
    final newStates = <String, bool>{};
    for (final desc in ModuleRegistry.modules) {
      String? rawVal;
      if (desc.key == 'module_medicine_enabled') {
        rawVal = rawMap['module_medicine_enabled'] ?? rawMap['module_health_enabled'];
      } else if (desc.key == 'module_supplementary_sports_enabled') {
        rawVal = rawMap['module_supplementary_sports_enabled'] ?? rawMap['module_sports_enabled'];
      } else {
        rawVal = rawMap[desc.key];
      }
      newStates[desc.key] = _resolve(desc, rawVal);
    }
    
    states.value = newStates;
  }

  bool isEnabled(String moduleKey) {
    if (!states.value.containsKey(moduleKey)) {
      RitmoLogger.error('ModuleGate: Unknown module key "$moduleKey" requested.');
      return false;
    }
    return states.value[moduleKey]!;
  }

  bool isEnabledFrom(Map<String, String> settings, String moduleKey) {
    final desc = ModuleRegistry.findByKey(moduleKey);
    if (desc == null) {
      RitmoLogger.error('ModuleGate: Unknown module key "$moduleKey" requested from settings.');
      return false;
    }
    String? rawVal;
    if (moduleKey == 'module_medicine_enabled') {
      rawVal = settings['module_medicine_enabled'] ?? settings['module_health_enabled'];
    } else if (moduleKey == 'module_supplementary_sports_enabled') {
      rawVal = settings['module_supplementary_sports_enabled'] ?? settings['module_sports_enabled'];
    } else {
      rawVal = settings[moduleKey];
    }
    return _resolve(desc, rawVal);
  }

  bool isDomainEnabled(AgendaDomain domain) {
    final owner = ModuleContentMap.ownerOfDomain(domain);
    if (owner == null) return true; // Unmapped domains are assumed enabled
    return isEnabled(owner);
  }

  bool isCategoryEnabled(String routineCategory) {
    final owner = ModuleContentMap.ownerOfCategory(routineCategory);
    if (owner == null) return true; // Unmapped categories are assumed enabled
    return isEnabled(owner);
  }

  Set<String> get enabledKeys {
    return states.value.entries.where((e) => e.value).map((e) => e.key).toSet();
  }

  Set<String> get disabledKeys {
    return states.value.entries.where((e) => !e.value).map((e) => e.key).toSet();
  }

  /// تعداد ماژول‌های اختیاری فعال فعلی
  int get activeOptionalModuleCount {
    return states.value.entries
        .where((e) => e.value && !ModuleRegistry.isCoreModule(e.key))
        .length;
  }

  /// آیا ظرفیت فعال‌سازی ماژول جدید وجود دارد؟
  bool get canActivateMoreModules {
    return activeOptionalModuleCount < FeatureLimits.current.maxActiveModules;
  }

  bool _resolve(ModuleDescriptor d, String? raw) {
    if (d.isCore) return true;
    if (raw == null) return d.defaultEnabled;
    return raw == 'true';
  }
}
