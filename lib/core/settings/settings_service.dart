import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ritmo/core/app_mode/app_mode_service.dart';
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

enum SettingsLoadState { notLoaded, loaded, degraded }

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
  final Set<String> _pendingRestartKeys = {};

  bool get isInitialized => _initialized;
  Object? get initError => _initError;
  bool get hasInitError => _initError != null;
  SettingsLoadState get loadState {
    if (_initError != null) return SettingsLoadState.degraded;
    if (!_initialized) return SettingsLoadState.notLoaded;
    return SettingsLoadState.loaded;
  }
  bool get isDegraded => loadState == SettingsLoadState.degraded;
  Stream<String> get changes => _changeController.stream;

  bool get hasPendingRestartSettings => _pendingRestartKeys.isNotEmpty;
  Set<String> get pendingRestartKeys => Set.unmodifiable(_pendingRestartKeys);
  void markRestartHandled() => _pendingRestartKeys.clear();

  int get cachedCount => _cache.length;
  Map<String, Object> get cachedEntries => Map.unmodifiable(_cache);

  /// Inspector helper: retrieves raw database rows for diagnostics.
  Future<List<Map<String, dynamic>>> getRawDatabaseRows() async {
    final db = await DatabaseHelper.instance.database;
    return db.query('app_settings', orderBy: 'key ASC');
  }

  /// Inspector helper: permanently deletes orphan keys from database.
  Future<int> deleteOrphanKeys(List<String> keys) async {
    if (keys.isEmpty) return 0;
    final db = await DatabaseHelper.instance.database;
    final placeholders = List.filled(keys.length, '?').join(',');
    final count = await db.delete('app_settings', where: 'key IN ($placeholders)', whereArgs: keys);
    await reload();
    return count;
  }

  Stream<T> watch<T>(String key) {
    return _changeController.stream
        .where((k) => k == key)
        .map((_) => get<T>(key));
  }

  Future<void>? _initFuture;

  Future<void> init() {
    if (_initialized) return Future.value();
    return _initFuture ??= _doInit().whenComplete(() => _initFuture = null);
  }

  Future<void> _doInit() async {
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

      if (_cache['app_mode'] == 'simple' || _cache['app_mode'] == 'SIMPLE') {
        _cache['show_advanced_settings'] = false;
      } else if (_cache['app_mode'] == 'full' || _cache['app_mode'] == 'FULL') {
        _cache['show_advanced_settings'] = true;
      }

      _initialized = true;
      revision.value++;
    } catch (e, st) {
      _initError = e;
      _initialized = false;
      RitmoLog.error('Settings', 'init error', e, st);
      // Fallback populate all defaults
      for (final desc in SettingsRegistry.all) {
        _cache[desc.key] = desc.defaultValue;
      }
      revision.value++;
    }
  }

  @visibleForTesting
  void resetForTesting() {
    _initialized = false;
    _initFuture = null;
    _initError = null;
    _cache.clear();
    _pendingRestartKeys.clear();
    _agendaDebounceTimer?.cancel();
    _agendaDebounceTimer = null;
  }

  Future<bool> retryInit() async {
    _initialized = false;
    _initFuture = null;
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
    } catch (e, st) {
      RitmoLog.warning('SettingsService', 'Failed to cast setting $key as $T', e, st);
      if (T == bool) return false as T;
      if (T == int) return 0 as T;
      if (T == double) return 0.0 as T;
      if (T == String) return '' as T;
      rethrow;
    }
  }

  Map<String, String> getAllStringMap() {
    final map = <String, String>{};
    for (final entry in _cache.entries) {
      map[entry.key] = entry.value.toString();
    }
    return map;
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

    final oldVal = _cache[key];
    _cache[key] = normalized;
    if (desc.requiresRestart) {
      _pendingRestartKeys.add(key);
    }
    revision.value++;
    _changeController.add(key);

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

      if (key == 'app_mode') {
        final modeLower = normalized.toString().toLowerCase();
        final shouldShowAdvanced = modeLower == 'full';
        AppModeService.instance.syncFromSettings(modeLower);
        _cache['show_advanced_settings'] = shouldShowAdvanced;
        final db = await DatabaseHelper.instance.database;
        await db.insert('app_settings', {
          'key': 'show_advanced_settings',
          'value': shouldShowAdvanced.toString(),
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      } else if (key == 'show_advanced_settings') {
        final targetMode = (normalized == true) ? 'full' : 'simple';
        AppModeService.instance.syncFromSettings(targetMode);
        _cache['app_mode'] = targetMode;
        final db = await DatabaseHelper.instance.database;
        await db.insert('app_settings', {
          'key': 'app_mode',
          'value': targetMode,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      return const SettingWriteOk();
    } catch (e, st) {
      if (oldVal != null) {
        _cache[key] = oldVal;
      } else {
        _cache.remove(key);
      }
      revision.value++;
      _changeController.add(key);
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

  /// بررسی آیا این تنظیم نسبت به مقدار پیش‌فرض تغییر کرده است
  bool isModifiedFromDefault(String key) {
    final desc = SettingsRegistry.find(key);
    if (desc == null) return false;
    final current = get<Object?>(key);
    return current != desc.defaultValue;
  }

  /// بازگردانی یک تنظیم به مقدار پیش‌فرض خود
  Future<void> resetToDefault(String key) async {
    final desc = SettingsRegistry.find(key);
    if (desc == null) return;
    await set(key, desc.defaultValue);
  }

  /// دریافت لیست کلیدهای تغییریافته نسبت به پیش‌فرض
  List<String> getModifiedKeys({SettingsGroup? group}) {
    return SettingsRegistry.all
        .where((d) => group == null || d.group == group)
        .where((d) => isModifiedFromDefault(d.key))
        .map((d) => d.key)
        .toList();
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

  /// اعمال دسته‌ای مجموعه‌ای از تنظیمات با اعتبارسنجی و تحریک فقط یک بار رویداد تغییر
  Future<int> setBatch(
    Map<String, Object> newValues, {
    SettingsWriteOrigin origin = SettingsWriteOrigin.user,
  }) async {
    if (!_initialized) {
      final ok = await retryInit();
      if (!ok) {
        RitmoLog.warning('Settings', 'عدم امکان ذخیره‌سازی دسته‌ای به دلیل عدم راه‌اندازی موفق سرویس تنظیمات');
        return 0;
      }
    }

    final dbEntries = <String, String>{};
    final prefEntries = <String, Object>{};
    final secureEntries = <String, String>{};
    final changedKeys = <String>[];
    bool hasAgendaAffecting = false;
    bool hasNotifGroup = false;

    for (final entry in newValues.entries) {
      final key = entry.key;
      final rawVal = entry.value;

      final desc = SettingsRegistry.find(key);
      if (desc == null) {
        RitmoLog.warning('Settings', 'رد ذخیره‌سازی دسته‌ای برای کلید نامشخص: $key');
        continue;
      }

      if (origin == SettingsWriteOrigin.ai && !desc.aiWritable) {
        RitmoLog.warning('Settings', 'AI مجاز به تغییر تنظیم غیرقابل‌دسترس $key نیست');
        continue;
      }

      final normalized = _validateAndNormalize(desc, rawVal);
      if (normalized == null) {
        RitmoLog.warning('Settings', 'مقدار نامعتبر در ذخیره‌سازی دسته‌ای برای $key: $rawVal');
        continue;
      }

      final currentVal = _cache[key];
      if (currentVal == normalized) continue;

      _cache[key] = normalized;
      changedKeys.add(key);

      if (desc.requiresRestart) {
        _pendingRestartKeys.add(key);
      }
      if (desc.affectsAgenda) {
        hasAgendaAffecting = true;
      }
      if (desc.group == SettingsGroup.notifications) {
        hasNotifGroup = true;
      }

      if (desc.scope == SettingScope.db) {
        dbEntries[key] = normalized.toString();
      } else if (desc.scope == SettingScope.prefs) {
        prefEntries[key] = normalized;
      } else if (desc.scope == SettingScope.secure) {
        secureEntries[key] = normalized.toString();
      }
    }

    if (changedKeys.isEmpty) return 0;

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
              'value': entry.value,
              'updatedAt': now,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      }

      if (prefEntries.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        for (final entry in prefEntries.entries) {
          final val = entry.value;
          if (val is bool) {
            await prefs.setBool(entry.key, val);
          } else if (val is int) {
            await prefs.setInt(entry.key, val);
          } else {
            await prefs.setString(entry.key, val.toString());
          }
        }
      }

      if (secureEntries.isNotEmpty) {
        for (final entry in secureEntries.entries) {
          await SecureKeyStore.setKey(entry.key, entry.value);
        }
      }

      revision.value++;
      for (final k in changedKeys) {
        _changeController.add(k);
      }

      if (hasAgendaAffecting) {
        _scheduleAgendaRefreshSignal();
      }

      if (hasNotifGroup) {
        try {
          final notifSettings = <String, String>{
            'digest_mode': get<String>('digest_mode'),
            'coalescing_window_minutes': get<int>('coalescing_window_minutes').toString(),
            'max_non_essential_per_hour': get<int>('max_non_essential_per_hour').toString(),
          };
          await SnapshotHelper.updateNotificationSettingsSnapshot(notifSettings);
        } catch (e, st) {
          RitmoLog.error('Settings', 'Notification snapshot error in setBatch', e, st);
        }
      }

      RitmoLog.info('Settings', 'ذخیره‌سازی دسته‌ای موفق: ${changedKeys.length} کلید تغییر یافت.');
      return changedKeys.length;
    } catch (e, st) {
      RitmoLog.error('Settings', 'خطا در ذخیره‌سازی دسته‌ای تنظیمات', e, st);
      return changedKeys.length;
    }
  }

  @visibleForTesting
  void cancelPendingSignals() {
    _agendaDebounceTimer?.cancel();
    _agendaDebounceTimer = null;
  }
}
