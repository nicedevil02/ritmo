import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/modules/module_gate.dart';
import 'package:ritmo/core/modules/module_registry.dart';

void main() {
  group('Module Key Consistency & Orphan Key Guard (P15 / W2-5)', () {
    test('all module_* string literals in lib/ belong to ModuleRegistry or documented legacy exceptions', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue, reason: 'lib directory must exist');

      final canonicalKeys = ModuleRegistry.modules.map((m) => m.key).toSet();

      // Documented exception list with reasons
      const allowedExceptions = <String, String>{
        // Fallback reading for historical users migrated from old versions
        'module_health_enabled': 'Legacy key fallback in ModuleGate and historical migration registry',
        // Historical database migration files
        'module_konkur_enabled': 'Historical migration v73 and v78 schema key',
        // Denylist guard in AI settings assistant
        'module_medical_enabled': 'Denylist guard in AI assistant settings protection',
        // Sub-feature toggle for pregnancy section under health module
        'module_pregnancy_enabled': 'Sub-feature flag for health/pregnancy records',
      };

      final moduleKeyPattern = RegExp(r"['" r'"]' r"(module_[a-z_]+)" r"['" r'"]');
      final foundKeys = <String, Set<String>>{}; // key -> Set of file paths

      for (final file in libDir.listSync(recursive: true)) {
        if (file is File && file.path.endsWith('.dart')) {
          final content = file.readAsStringSync();
          final matches = moduleKeyPattern.allMatches(content);
          for (final m in matches) {
            final key = m.group(1)!;
            // Ignore generic regex or wildcards like 'module_%'
            if (key == 'module_' || key.endsWith('_')) continue;
            foundKeys.putIfAbsent(key, () => {}).add(file.path);
          }
        }
      }

      final invalidKeys = <String, Set<String>>{};
      for (final entry in foundKeys.entries) {
        final key = entry.key;
        if (!canonicalKeys.contains(key) && !allowedExceptions.containsKey(key)) {
          invalidKeys[key] = entry.value;
        }
      }

      expect(
        invalidKeys,
        isEmpty,
        reason: 'Found unregistered/orphan module keys in lib/ without documented exception: $invalidKeys',
      );
    });

    test('ModuleGate special-case: supplementary sports maps to module_sports_enabled when missing', () {
      final settings = <String, String>{'module_sports_enabled': 'true'};
      final isSuppEnabled = ModuleGate.instance.isEnabledFrom(
        settings,
        'module_supplementary_sports_enabled',
      );
      expect(isSuppEnabled, isTrue, reason: 'supplementary sports should fallback to module_sports_enabled');
    });

    test('ModuleGate legacy fallback: module_medicine_enabled reads module_health_enabled when missing', () {
      final settings = <String, String>{'module_health_enabled': 'true'};
      final isMedEnabled = ModuleGate.instance.isEnabledFrom(
        settings,
        'module_medicine_enabled',
      );
      expect(isMedEnabled, isTrue, reason: 'medicine should fallback to module_health_enabled if present');
    });
  });
}
