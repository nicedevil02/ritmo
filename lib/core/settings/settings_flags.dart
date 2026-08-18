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
    final consent = parseBool('cycle_consent', false);
    final module = parseBool('module_cycle_enabled', true);
    final proactive = parseBool('proactive_assistant_enabled', true);
    final briefing = parseBool('briefing_enabled', true);
    final energy = parseBool('energy_tuning_enabled', true);
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
}
