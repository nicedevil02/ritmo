import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/services/secure_key_store.dart';
import 'package:ritmo/core/settings/settings_registry.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/snapshot_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

enum SettingsWriteOrigin { user, system, ai }

sealed class SettingWriteResult {
  const SettingWriteResult();
}

class SettingWriteOk extends SettingWriteResult {
  const SettingWriteOk();
}

class SettingWriteRejected extends SettingWriteResult {
  const SettingWriteRejected(this.reasonFa);
  final String reasonFa;
}

class SettingWriteFailed extends SettingWriteResult {
  const SettingWriteFailed(this.reasonFa);
  final String reasonFa;
}

class SettingsService {
  SettingsService._();
  @visibleForTesting
  SettingsService.test();
  static final SettingsService instance = SettingsService._();

  final Map<String, Object> _cache = {};
  final ValueNotifier<int> revision = ValueNotifier<int>(0);
  final _changeController = StreamController<String>.broadcast();
  bool _initialized = false;
  Object? _initError;

  /// Coalescing window for the heavy "reload the day" refresh signal.
  static const Duration agendaSignalDebounce = Duration(milliseconds: 350);
  Timer? _agendaDebounceTimer;

  bool get isInitialized => _initialized;
  Object? get initError => _initError;
  bool get hasInitError => _initError != null;
  Stream<String> get changes => _changeController.stream;

  Stream<T> watch<T>(String key) {
    return _changeController.stream
        .where((k) => k == key)
        .map((_) => get<T>(key));
  }

  Future<void> init() async {
    try {
      _initError = null;
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

      try {
        await _migrateAndPruneOrphanKeys(db, dbMap);
      } catch (e, st) {
        RitmoLog.error('Settings', 'خطا در پاک‌سازی کلیدهای یتیم', e, st);
      }
    } catch (e, st) {
      _initError = e;
      _initialized = false;
      RitmoLog.error('Settings', 'init error', e, st);
      // Fallback populate all defaults
      for (final desc in SettingsRegistry.all) {
        _cache[desc.key] = desc.defaultValue;
      }
    }
  }

  Future<void> _migrateAndPruneOrphanKeys(Database db, Map<String, String> dbMap) async {
    final knownKeys = SettingsRegistry.all.map((d) => d.key).toSet();
    final orphanKeys = dbMap.keys.where((k) => !knownKeys.contains(k)).toList();
    if (orphanKeys.isNotEmpty) {
      RitmoLog.info('Settings', 'پاک‌سازی ${orphanKeys.length} کلید یتیم از جدول تنظیمات: $orphanKeys');
      final placeholders = List.filled(orphanKeys.length, '?').join(',');
      await db.delete('app_settings', where: 'key IN ($placeholders)', whereArgs: orphanKeys);
    }
  }

  Future<bool> retryInit() async {
    await init();
    return _initialized;
  }

  /// Reloads all settings from the persistent layers (SQLite, SharedPreferences, SecureKeyStore)
  /// and updates the in-memory cache and revision without tearing down streams or controllers.
  Future<void> reload() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final dbRows = await db.query('app_settings');
      final dbMap = {
        for (final r in dbRows) r['key']! as String: r['value']! as String,
      };

      SharedPreferences? prefs;
      try {
        prefs = await SharedPreferences.getInstance();
        await prefs.reload();
      } catch (e, st) {
        RitmoLog.error('Settings', 'SharedPreferences reload error', e, st);
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
          }
        }
      }

      _initialized = true;
      revision.value++;
    } catch (e, st) {
      RitmoLog.error('Settings', 'خطا در بارگذاری مجدد تنظیمات (reload)', e, st);
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

  String? getString(String key) {
    if (!_cache.containsKey(key)) {
      final desc = SettingsRegistry.find(key);
      return desc?.defaultValue.toString();
    }
    return get<String>(key);
  }

  Future<bool> setString(String key, String value) => set(key, value);

  Object? _validateAndNormalize(SettingDescriptor desc, Object rawValue) {
    if (desc.type == SettingType.integer) {
      final intVal = rawValue is int ? rawValue : int.tryParse(rawValue.toString());
      if (intVal == null) return null;
      if (desc.min != null && intVal < desc.min!) return null;
      if (desc.max != null && intVal > desc.max!) return null;
      return intVal;
    } else if (desc.type == SettingType.enumeration) {
      final strVal = rawValue.toString();
      if (desc.allowed != null) {
        final match = desc.allowed!.firstWhere(
          (a) => a.toUpperCase() == strVal.toUpperCase(),
          orElse: () => '',
        );
        if (match.isEmpty) {
          RitmoLog.warning('Settings', 'رد ذخیره‌سازی برای کلید ${desc.key}: مقدار در فهرست مجاز نیست');
          return null;
        }
        return match;
      }
      return strVal;
    } else if (desc.type == SettingType.boolean) {
      if (rawValue is bool) return rawValue;
      return rawValue.toString() == 'true';
    } else if (desc.type == SettingType.time) {
      final str = rawValue.toString().trim();
      final match = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$').firstMatch(str);
      if (match == null) {
        RitmoLog.warning('Settings', 'مقدار زمان نامعتبر برای کلید ${desc.key}: $str');
        return null;
      }
      return str;
    } else if (desc.type == SettingType.text) {
      final str = rawValue.toString();
      if (str.length > 4096) {
        RitmoLog.warning('Settings', 'طول متن برای کلید ${desc.key} فراتر از سقف ۴۰۹۶ است');
        return null;
      }
      return str;
    }
    return rawValue;
  }

  Future<SettingWriteResult> setChecked(
    String key,
    Object value, {
    SettingsWriteOrigin origin = SettingsWriteOrigin.user,
  }) async {
    if (!_initialized) {
      final ok = await retryInit();
      if (!ok) {
        RitmoLog.warning('Settings', 'عدم امکان ذخیره‌سازی کلید $key به دلیل عدم راه‌اندازی موفق سرویس تنظیمات');
        return const SettingWriteFailed('عدم امکان راه‌اندازی سرویس تنظیمات');
      }
    }

    final desc = SettingsRegistry.find(key);
    if (desc == null) {
      RitmoLog.warning('Settings', 'رد ذخیره‌سازی برای کلید نامشخص: $key');
      return SettingWriteRejected('تنظیم نامشخص: $key');
    }

    if (origin == SettingsWriteOrigin.ai && !desc.aiWritable) {
      RitmoLog.warning('Settings', 'AI مجاز به تغییر تنظیم غیرقابل‌دسترس $key نیست');
      return const SettingWriteRejected('این تنظیم فقط توسط خود شما قابل تغییر است.');
    }

    final normalized = _validateAndNormalize(desc, value);
    if (normalized == null) {
      if (desc.type == SettingType.integer && (desc.min != null || desc.max != null)) {
        final min = desc.min;
        final max = desc.max;
        final minStr = min != null ? toPersianDigits(min) : '۰';
        final maxStr = max != null ? toPersianDigits(max) : 'نامحدود';
        return SettingWriteRejected('مقدار باید بین $minStr تا $maxStr باشد.');
      }
      return const SettingWriteRejected('مقدار وارد شده برای این تنظیم معتبر نیست.');
    }

    final currentVal = _cache[key];
    if (currentVal == normalized) {
      return const SettingWriteOk();
    }

    try {
      if (desc.scope == SettingScope.db) {
        final db = await DatabaseHelper.instance.database;
        final now = DateTime.now().millisecondsSinceEpoch;
        await db.insert(
          'app_settings',
          {
            'key': key,
            'value': normalized.toString(),
            'updatedAt': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } else if (desc.scope == SettingScope.prefs) {
        final prefs = await SharedPreferences.getInstance();
        if (normalized is bool) {
          await prefs.setBool(key, normalized);
        } else if (normalized is int) {
          await prefs.setInt(key, normalized);
        } else {
          await prefs.setString(key, normalized.toString());
        }
      } else if (desc.scope == SettingScope.secure) {
        await SecureKeyStore.setKey(key, normalized.toString());
      }

      _cache[key] = normalized;
      revision.value++;
      _changeController.add(key);

      if (desc.affectsAgenda) {
        _scheduleAgendaRefreshSignal();
      }

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

      return const SettingWriteOk();
    } catch (e, st) {
      RitmoLog.error('Settings', 'خطا در ذخیره‌سازی کلید $key', e, st);
      return const SettingWriteFailed('خطا در ثبت تغییرات در پایگاه داده');
    }
  }

  Future<bool> set(String key, Object value) async {
    final result = await setChecked(key, value);
    return result is SettingWriteOk;
  }

  Future<bool> setMany(Map<String, Object> values) async {
    if (!_initialized) {
      final ok = await retryInit();
      if (!ok) {
        RitmoLog.warning('Settings', 'عدم امکان ذخیره‌سازی دسته‌ای به دلیل عدم راه‌اندازی موفق سرویس تنظیمات');
        return false;
      }
    }

    final dbEntries = <String, Object>{};
    final prefsEntries = <String, (SettingDescriptor, Object)>{};
    final secureEntries = <String, Object>{};
    bool affectsAgendaAny = false;
    bool hasNotifChange = false;

    for (final entry in values.entries) {
      final key = entry.key;
      final rawVal = entry.value;
      final desc = SettingsRegistry.find(key);
      if (desc == null) {
        RitmoLog.warning('Settings', 'رد ذخیره‌سازی دسته‌ای برای کلید نامشخص: $key');
        continue;
      }

      final normalized = _validateAndNormalize(desc, rawVal);
      if (normalized == null) continue;

      final currentVal = _cache[key];
      if (currentVal == normalized) continue;

      if (desc.scope == SettingScope.db) {
        dbEntries[key] = normalized;
      } else if (desc.scope == SettingScope.prefs) {
        prefsEntries[key] = (desc, normalized);
      } else if (desc.scope == SettingScope.secure) {
        secureEntries[key] = normalized;
      }

      if (desc.affectsAgenda) {
        affectsAgendaAny = true;
      }
      if (desc.group == SettingsGroup.notifications) {
        hasNotifChange = true;
      }
    }

    if (dbEntries.isEmpty && prefsEntries.isEmpty && secureEntries.isEmpty) {
      return true;
    }

    try {
      if (dbEntries.isNotEmpty) {
        final db = await DatabaseHelper.instance.database;
        final now = DateTime.now().millisecondsSinceEpoch;
        final batch = db.batch();
        for (final entry in dbEntries.entries) {
          batch.insert(
            'app_settings',
            {
              'key': entry.key,
              'value': entry.value.toString(),
              'updatedAt': now,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      }

      if (prefsEntries.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        for (final item in prefsEntries.values) {
          final desc = item.$1;
          final val = item.$2;
          if (val is bool) {
            await prefs.setBool(desc.key, val);
          } else if (val is int) {
            await prefs.setInt(desc.key, val);
          } else {
            await prefs.setString(desc.key, val.toString());
          }
        }
      }

      if (secureEntries.isNotEmpty) {
        for (final entry in secureEntries.entries) {
          await SecureKeyStore.setKey(entry.key, entry.value.toString());
        }
      }

      // Update cache
      dbEntries.forEach((k, v) => _cache[k] = v);
      prefsEntries.forEach((k, pair) => _cache[k] = pair.$2);
      secureEntries.forEach((k, v) => _cache[k] = v);

      revision.value++;

      for (final k in dbEntries.keys) {
        _changeController.add(k);
      }
      for (final k in prefsEntries.keys) {
        _changeController.add(k);
      }
      for (final k in secureEntries.keys) {
        _changeController.add(k);
      }

      if (affectsAgendaAny) {
        _scheduleAgendaRefreshSignal();
      }

      if (hasNotifChange) {
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
      RitmoLog.error('Settings', 'خطا در ذخیره‌سازی دسته‌ای تنظیمات', e, st);
      return false;
    }
  }

  Future<bool> reset(String key) async {
    final desc = SettingsRegistry.find(key);
    if (desc == null) return false;
    return set(key, desc.defaultValue);
  }

  Future<bool> resetGroup(SettingsGroup group) async {
    final descriptors = SettingsRegistry.byGroup(group);
    final batch = <String, Object>{
      for (final d in descriptors) d.key: d.defaultValue,
    };
    return setMany(batch);
  }

  Future<bool> resetAll({bool includeSecure = false}) async {
    final batch = <String, Object>{
      for (final d in SettingsRegistry.all)
        if (includeSecure || d.scope != SettingScope.secure)
          d.key: d.defaultValue,
    };
    return setMany(batch);
  }

  Future<bool> setFromAi(String key, Object value) async {
    final desc = SettingsRegistry.find(key);
    if (desc == null) {
      RitmoLog.warning('Settings', 'AI تلاش کرد کلید نامشخص $key را تغییر دهد');
      return false;
    }
    if (!desc.aiWritable) {
      RitmoLog.warning('Settings', 'AI مجاز به تغییر تنظیم غیرقابل‌دسترس $key نیست');
      return false;
    }
    return set(key, value);
  }

  Future<bool> setManyFromAi(Map<String, Object> values) async {
    final filtered = <String, Object>{};
    for (final entry in values.entries) {
      final desc = SettingsRegistry.find(entry.key);
      if (desc == null) {
        RitmoLog.warning('Settings', 'AI تلاش کرد کلید نامشخص ${entry.key} را تغییر دهد');
        continue;
      }
      if (!desc.aiWritable) {
        RitmoLog.warning('Settings', 'AI مجاز به تغییر تنظیم غیرقابل‌دسترس ${entry.key} نیست');
        continue;
      }
      filtered[entry.key] = entry.value;
    }
    if (filtered.isEmpty && values.isNotEmpty) {
      return false;
    }
    return setMany(filtered);
  }

  /// Emits at most one `notifyRoutineChanged()` per [agendaSignalDebounce]
  /// window, coalescing repeated writes into a single refresh.
  void _scheduleAgendaRefreshSignal() {
    _agendaDebounceTimer?.cancel();
    _agendaDebounceTimer = Timer(agendaSignalDebounce, () {
      _agendaDebounceTimer = null;
      RitmoEvents.notifyRoutineChanged();
    });
  }

  @visibleForTesting
  void cancelPendingSignals() {
    _agendaDebounceTimer?.cancel();
    _agendaDebounceTimer = null;
  }
}
