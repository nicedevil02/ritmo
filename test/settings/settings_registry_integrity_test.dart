import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/settings/settings_registry.dart';

void main() {
  group('Settings Registry Integrity Tests (SET-64)', () {
    test('No duplicate keys in registry', () {
      final keys = <String>{};
      for (final desc in SettingsRegistry.all) {
        expect(
          keys.contains(desc.key),
          isFalse,
          reason: 'Duplicate key found in registry: ${desc.key}',
        );
        keys.add(desc.key);
      }
    });

    test('Every setting has a non-empty Persian label and valid key format', () {
      for (final desc in SettingsRegistry.all) {
        expect(desc.key.trim(), isNotEmpty, reason: 'Key cannot be empty');
        expect(desc.labelFa.trim(), isNotEmpty, reason: 'LabelFa cannot be empty for ${desc.key}');
        expect(
          desc.key,
          matches(RegExp(r'^[a-z0-9_]+$')),
          reason: 'Key "${desc.key}" must be snake_case',
        );
      }
    });

    test('Default values match their declared SettingType', () {
      for (final desc in SettingsRegistry.all) {
        switch (desc.type) {
          case SettingType.boolean:
            expect(
              desc.defaultValue is bool,
              isTrue,
              reason: 'Default value for boolean key "${desc.key}" must be bool, got ${desc.defaultValue.runtimeType}',
            );
          case SettingType.integer:
            expect(
              desc.defaultValue is int,
              isTrue,
              reason: 'Default value for integer key "${desc.key}" must be int, got ${desc.defaultValue.runtimeType}',
            );
          case SettingType.text:
            expect(
              desc.defaultValue is String,
              isTrue,
              reason: 'Default value for text key "${desc.key}" must be String, got ${desc.defaultValue.runtimeType}',
            );
          case SettingType.enumeration:
            expect(
              desc.defaultValue is String,
              isTrue,
              reason: 'Default value for enum key "${desc.key}" must be String, got ${desc.defaultValue.runtimeType}',
            );
            expect(
              desc.allowed,
              isNotNull,
              reason: 'allowed list must not be null for enum key "${desc.key}"',
            );
            expect(
              desc.allowed!.isNotEmpty,
              isTrue,
              reason: 'allowed list must not be empty for enum key "${desc.key}"',
            );
            expect(
              desc.allowed!.contains(desc.defaultValue),
              isTrue,
              reason: 'Default value "${desc.defaultValue}" for "${desc.key}" must be present in allowed (${desc.allowed})',
            );
          case SettingType.time:
            expect(
              desc.defaultValue is String,
              isTrue,
              reason: 'Default value for time key "${desc.key}" must be String, got ${desc.defaultValue.runtimeType}',
            );
            expect(
              desc.defaultValue as String,
              matches(RegExp(r'^\d{2}:\d{2}$')),
              reason: 'Time default value for "${desc.key}" must match HH:mm pattern, got "${desc.defaultValue}"',
            );
        }
      }
    });

    test('Integer bounds are consistent (min <= defaultValue <= max)', () {
      for (final desc in SettingsRegistry.all) {
        if (desc.type == SettingType.integer) {
          final val = desc.defaultValue as int;
          if (desc.min != null && desc.max != null) {
            expect(
              desc.min! <= desc.max!,
              isTrue,
              reason: 'min (${desc.min}) must be <= max (${desc.max}) for key "${desc.key}"',
            );
          }
          if (desc.min != null) {
            expect(
              val >= desc.min!,
              isTrue,
              reason: 'defaultValue ($val) must be >= min (${desc.min}) for key "${desc.key}"',
            );
          }
          if (desc.max != null) {
            expect(
              val <= desc.max!,
              isTrue,
              reason: 'defaultValue ($val) must be <= max (${desc.max}) for key "${desc.key}"',
            );
          }
        }
      }
    });

    test('Every SettingsGroup has at least one registered setting', () {
      for (final group in SettingsGroup.values) {
        final groupSettings = SettingsRegistry.byGroup(group);
        expect(
          groupSettings.isNotEmpty,
          isTrue,
          reason: 'SettingsGroup "${group.name}" has no registered settings in SettingsRegistry',
        );
      }
    });

    test('SettingsRegistry.find returns the exact descriptor or null', () {
      for (final desc in SettingsRegistry.all) {
        final found = SettingsRegistry.find(desc.key);
        expect(found, isNotNull);
        expect(found!.key, equals(desc.key));
      }

      expect(SettingsRegistry.find('non_existent_key_xyz_123'), isNull);
    });
  });
}
