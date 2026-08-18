import 'package:flutter/foundation.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/services/secure_key_store.dart';
import 'package:ritmo/core/settings/settings_registry.dart';
import 'package:ritmo/core/utils/snapshot_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class SettingsService {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  final Map<String, Object> _cache = {};
  final ValueNotifier<int> revision = ValueNotifier<int>(0);
  bool _initialized = false;

  /// Coalescing window for the heavy "reload the day" refresh signal.
  static const Duration agendaSignalDebounce = Duration(milliseconds: 350);
  static bool _agendaSignalScheduled = false;

  bool get isInitialized => _initialized;

  Future<void> init() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query('app_settings');
      final dbMap = <String, String>{
        for (final r in rows) (r['key'] as String): (r['value'] as String? ?? '')
      };

      SharedPreferences? prefs;
      try {
        prefs = await SharedPreferences.getInstance();
      } catch (e, st) {
        RitmoLog.error('Settings', 'SharedPreferences init error', e, st);
      }

      for (final desc in SettingsRegistry.all) {
        if (desc.scope == SettingScope.db) {
          final raw = dbMap[desc.key];
          _cache[desc.key] = desc.parseValue(raw);
        } else if (desc.scope == SettingScope.prefs && prefs != null) {
          final raw = prefs.get(desc.key);
          _cache[desc.key] = desc.parseValue(raw);
        } else if (desc.scope == SettingScope.secure) {
          try {
            final secVal = await SecureKeyStore.getKey(desc.key);
            _cache[desc.key] = desc.parseValue(secVal != null && secVal.isNotEmpty ? secVal : null);
          } catch (e, st) {
            RitmoLog.error('Settings', 'خطا در بارگذاری کلید امن ${desc.key}', e, st);
            _cache[desc.key] = desc.defaultValue;
          }
        }
      }

      _initialized = true;
      revision.value++;
    } catch (e, st) {
      RitmoLog.error('Settings', 'init error', e, st);
      // Fallback populate all defaults
      for (final desc in SettingsRegistry.all) {
        _cache[desc.key] = desc.defaultValue;
      }
      _initialized = true;
    }
  }

  T get<T>(String key) {
    final desc = SettingsRegistry.find(key);
    final rawVal = _cache.containsKey(key) ? _cache[key] : desc?.defaultValue;

    if (rawVal == null) {
      if (T == bool) return false as T;
      if (T == int) return 0 as T;
      if (T == double) return 0.0 as T;
      if (T == String) return '' as T;
    }

    if (rawVal is T) {
      return rawVal;
    }

    if (T == bool) {
      if (rawVal is String) {
        final lower = rawVal.trim().toLowerCase();
        return (lower == 'true' || lower == '1' || lower == 'yes') as T;
      }
      if (rawVal is num) {
        return (rawVal != 0) as T;
      }
      return false as T;
    }

    if (T == int) {
      if (rawVal is String) {
        final parsed = int.tryParse(rawVal);
        if (parsed != null) return parsed as T;
      }
      if (rawVal is num) {
        return rawVal.toInt() as T;
      }
      if (rawVal is bool) {
        return (rawVal ? 1 : 0) as T;
      }
      return 0 as T;
    }

    if (T == double) {
      if (rawVal is String) {
        final parsed = double.tryParse(rawVal);
        if (parsed != null) return parsed as T;
      }
      if (rawVal is num) {
        return rawVal.toDouble() as T;
      }
      return 0.0 as T;
    }

    if (T == String) {
      return rawVal.toString() as T;
    }

    try {
      return rawVal as T;
    } catch (_) {
      if (T == bool) return false as T;
      if (T == int) return 0 as T;
      if (T == double) return 0.0 as T;
      if (T == String) return '' as T;
      rethrow;
    }
  }

  Future<bool> set(String key, Object value) async {
    final desc = SettingsRegistry.find(key);
    if (desc == null) {
      RitmoLog.warning('Settings', 'رد ذخیره‌سازی برای کلید نامشخص: $key');
      return false;
    }

    // Validation
    if (desc.type == SettingType.integer) {
      final intVal = value is int ? value : int.tryParse(value.toString());
      if (intVal == null) return false;
      if (desc.min != null && intVal < desc.min!) return false;
      if (desc.max != null && intVal > desc.max!) return false;
      value = intVal;
    } else if (desc.type == SettingType.enumeration) {
      final strVal = value.toString();
      if (desc.allowed != null) {
        final match = desc.allowed!.firstWhere(
          (a) => a.toUpperCase() == strVal.toUpperCase(),
          orElse: () => '',
        );
        if (match.isEmpty) {
          RitmoLog.warning('Settings', 'رد ذخیره‌سازی برای کلید $key: مقدار در فهرست مجاز نیست');
          return false;
        }
        value = match;
      } else {
        value = strVal;
      }
    } else if (desc.type == SettingType.boolean) {
      if (value is! bool) {
        value = value.toString() == 'true';
      }
    } else if (desc.type == SettingType.time) {
      final str = value.toString().trim();
      final match = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$').firstMatch(str);
      if (match == null) {
        RitmoLog.warning('Settings', 'مقدار زمان نامعتبر برای کلید $key: $str');
        return false;
      }
      value = str;
    }

    try {
      if (desc.scope == SettingScope.db) {
        final db = await DatabaseHelper.instance.database;
        final now = DateTime.now().millisecondsSinceEpoch;
        await db.insert(
          'app_settings',
          {
            'key': key,
            'value': value.toString(),
            'updatedAt': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } else if (desc.scope == SettingScope.prefs) {
        final prefs = await SharedPreferences.getInstance();
        if (value is bool) {
          await prefs.setBool(key, value);
        } else if (value is int) {
          await prefs.setInt(key, value);
        } else {
          await prefs.setString(key, value.toString());
        }
      } else if (desc.scope == SettingScope.secure) {
        await SecureKeyStore.setKey(key, value.toString());
      }

      _cache[key] = value;
      revision.value++;

      // A settings write used to fan out a *synchronous* routine-change
      // notification for every single key. Home, Calendar and the systems hub
      // all listen to that notifier and reload their entire day (syncAll plus
      // several agenda builds), so a burst of writes - onboarding hand-off,
      // module toggles, alarm rescheduling - multiplied into a reload storm
      // that could exhaust the Dart heap. `revision` still fires immediately
      // for settings UI; the heavy refresh is coalesced per burst.
      _scheduleAgendaRefreshSignal();

      if (desc.group == SettingsGroup.notifications) {
        try {
          final notifSettings = <String, String>{
            'digest_mode': get<String>('digest_mode'),
            'coalescing_window_minutes': get<int>('coalescing_window_minutes').toString(),
            'max_non_essential_per_hour': get<int>('max_non_essential_per_hour').toString(),
          };
          await SnapshotHelper.updateNotificationSettingsSnapshot(notifSettings);
        } catch (e, st) {
          RitmoLog.error('Settings', 'به‌روزرسانی اسنپ‌شات اعلان ناموفق بود', e, st);
        }
      }

      return true;
    } catch (e, st) {
      RitmoLog.error('Settings', 'خطا در ذخیره‌سازی کلید $key', e, st);
      return false;
    }
  }

  /// Emits at most one `notifyRoutineChanged()` per [agendaSignalDebounce]
  /// window, no matter how many settings were written in that window.
  void _scheduleAgendaRefreshSignal() {
    if (_agendaSignalScheduled) return;
    _agendaSignalScheduled = true;
    Future<void>.delayed(agendaSignalDebounce, () {
      _agendaSignalScheduled = false;
      RitmoEvents.notifyRoutineChanged();
    });
  }
}
