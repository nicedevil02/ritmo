import 'dart:convert';
import 'package:ritmo/core/logging/ritmo_log.dart';
import 'package:ritmo/core/settings/settings_registry.dart';
import 'package:ritmo/core/settings/settings_service.dart';

class SettingDiffItem {
  const SettingDiffItem({
    required this.key,
    required this.labelFa,
    required this.currentValue,
    required this.newValue,
  });

  final String key;
  final String labelFa;
  final Object? currentValue;
  final Object? newValue;
}

class SettingsDiffPreview {
  const SettingsDiffPreview({
    required this.schemaVersion,
    required this.exportedAt,
    required this.changed,
    required this.unchanged,
    required this.ignoredKeys,
    required this.rawSettings,
  });

  final int schemaVersion;
  final String exportedAt;
  final List<SettingDiffItem> changed;
  final List<SettingDiffItem> unchanged;
  final List<String> ignoredKeys;
  final Map<String, dynamic> rawSettings;
}

class SettingsTransferService {
  SettingsTransferService._();
  static final SettingsTransferService instance = SettingsTransferService._();

  static const int currentSchemaVersion = 1;

  String exportSettingsJson({bool includeSecure = false}) {
    final settingsMap = <String, dynamic>{};
    for (final desc in SettingsRegistry.all) {
      if (desc.scope != SettingScope.db) continue;
      if (!includeSecure && desc.isEncrypted) continue;
      if (desc.visibility == SettingVisibility.internal) continue;

      final val = SettingsService.instance.getUntyped(desc.key);
      settingsMap[desc.key] = val;
    }

    final payload = {
      'schemaVersion': currentSchemaVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'settings': settingsMap,
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  SettingsDiffPreview analyzeImport(String jsonString) {
    try {
      final map = jsonDecode(jsonString);
      if (map is! Map<String, dynamic> || !map.containsKey('settings')) {
        throw const FormatException('فرمت فایل تنظیمات نامعتبر است');
      }

      final schemaVersion = (map['schemaVersion'] as num?)?.toInt() ?? 1;
      final exportedAt = map['exportedAt'] as String? ?? '';
      final rawSettings = Map<String, dynamic>.from(map['settings'] as Map);

      final changed = <SettingDiffItem>[];
      final unchanged = <SettingDiffItem>[];
      final ignoredKeys = <String>[];

      for (final entry in rawSettings.entries) {
        final key = entry.key;
        final newVal = entry.value;
        final desc = SettingsRegistry.byKey(key);

        if (desc == null || desc.scope != SettingScope.db || desc.visibility == SettingVisibility.internal) {
          ignoredKeys.add(key);
          continue;
        }

        final currentVal = SettingsService.instance.getUntyped(key);
        final item = SettingDiffItem(
          key: key,
          labelFa: desc.labelFa,
          currentValue: currentVal,
          newValue: newVal,
        );

        if (currentVal != newVal) {
          changed.add(item);
        } else {
          unchanged.add(item);
        }
      }

      return SettingsDiffPreview(
        schemaVersion: schemaVersion,
        exportedAt: exportedAt,
        changed: changed,
        unchanged: unchanged,
        ignoredKeys: ignoredKeys,
        rawSettings: rawSettings,
      );
    } catch (e, st) {
      RitmoLog.error('Settings', 'خطا در تحلیل فایل تنظیمات', e, st);
      rethrow;
    }
  }

  Future<int> applyImport(SettingsDiffPreview diff, {List<String>? selectedKeys}) async {
    final keysToApply = selectedKeys ?? diff.changed.map((c) => c.key).toList();
    var appliedCount = 0;

    for (final key in keysToApply) {
      if (diff.rawSettings.containsKey(key)) {
        final val = diff.rawSettings[key];
        await SettingsService.instance.set(key, val);
        appliedCount++;
      }
    }

    return appliedCount;
  }
}
