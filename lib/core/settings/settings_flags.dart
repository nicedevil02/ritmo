import 'package:ritmo/core/settings/settings_registry.dart';

class SettingsFlags {
  SettingsFlags({
    required this.isFemale,
    required this.cycleConsent,
    required this.cycleModuleEnabled,
    required this.proactiveAssistantEnabled,
    required this.briefingEnabled,
    required this.energyTuningEnabled,
  });

  factory SettingsFlags.fromMap(Map<String, String> m) {
    bool parseBool(String key, bool defaultVal) {
      final desc = SettingsRegistry.find(key);
      if (desc != null) {
        final parsed = desc.parseValue(m[key]);
        if (parsed is bool) return parsed;
      }
      final raw = m[key];
      if (raw == null) return defaultVal;
      final s = raw.trim().toLowerCase();
      return s == 'true' || s == '1' || s == 'yes';
    }

    final genderDesc = SettingsRegistry.find('user_gender');
    final gender = genderDesc?.parseValue(m['user_gender']) as String? ?? 'UNSET';
    final female = gender.toUpperCase() == 'FEMALE';
    final consent = (m['cycle_consent_dashboard'] ?? m['cycle_consent'] ?? 'false') == 'true';
    final module = parseBool('module_cycle_enabled', true);
    final proactive = parseBool('assistant_proactive_enabled', true);
    final briefing = parseBool('calendar_morning_brief_enabled', true);
    final energy = parseBool('module_energy_enabled', true);
    return SettingsFlags(
      isFemale: female,
      cycleConsent: consent,
      cycleModuleEnabled: module,
      proactiveAssistantEnabled: proactive,
      briefingEnabled: briefing,
      energyTuningEnabled: energy,
    );
  }

  final bool isFemale;
  final bool cycleConsent;
  final bool cycleModuleEnabled;
  final bool proactiveAssistantEnabled;
  final bool briefingEnabled;
  final bool energyTuningEnabled;

  /// Rule M-12: Female ONLY + explicit consent + enabled module
  bool get canShowCycle => isFemale && cycleConsent && cycleModuleEnabled;

  Map<String, String> toSettingsMap() {
    return {
      'user_gender': isFemale ? 'FEMALE' : 'MALE',
      'cycle_consent_dashboard': cycleConsent.toString(),
      'module_cycle_enabled': cycleModuleEnabled.toString(),
      'assistant_proactive_enabled': proactiveAssistantEnabled.toString(),
      'calendar_morning_brief_enabled': briefingEnabled.toString(),
      'module_energy_enabled': energyTuningEnabled.toString(),
    };
  }
}
