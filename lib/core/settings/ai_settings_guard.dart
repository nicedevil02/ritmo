import 'dart:convert';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/settings/settings_registry.dart';
import 'package:ritmo/core/settings/settings_service.dart';

class AiSettingHistoryRecord {
  const AiSettingHistoryRecord({
    required this.id,
    required this.key,
    required this.labelFa,
    required this.oldValue,
    required this.newValue,
    required this.reasonFa,
    required this.timestamp,
  });

  final int id;
  final String key;
  final String labelFa;
  final Object? oldValue;
  final Object? newValue;
  final String reasonFa;
  final DateTime timestamp;

  factory AiSettingHistoryRecord.fromMap(Map<String, dynamic> map) {
    final key = map['setting_key'] as String;
    final desc = SettingsRegistry.find(key);
    return AiSettingHistoryRecord(
      id: map['id'] as int,
      key: key,
      labelFa: desc?.labelFa ?? key,
      oldValue: map['old_value'] != null ? jsonDecode(map['old_value'] as String) : null,
      newValue: map['new_value'] != null ? jsonDecode(map['new_value'] as String) : null,
      reasonFa: map['reason'] as String? ?? 'تنظیم خودکار دستیار',
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

class AiSettingsGuard {
  AiSettingsGuard._();
  static final AiSettingsGuard instance = AiSettingsGuard._();

  static const String tableName = 'ai_settings_history';

  Future<void> ensureTableExists() async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableName (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          setting_key TEXT NOT NULL,
          old_value TEXT,
          new_value TEXT,
          reason TEXT,
          timestamp INTEGER NOT NULL
        )
      ''');
    } catch (e, st) {
      RitmoLog.error('Settings', 'خطا در ایجاد جدول تاریخچه هوش مصنوعی', e, st);
    }
  }

  bool canAiModify(String key) {
    final allowAssistant = SettingsService.instance.get<bool>('assistant_can_modify_settings');
    if (!allowAssistant) return false;

    final desc = SettingsRegistry.find(key);
    if (desc == null || !desc.aiWritable) return false;

    final forbiddenKeys = SettingsService.instance.get<String>('ai_forbidden_keys');
    if (forbiddenKeys.isNotEmpty) {
      final list = forbiddenKeys.split(',').map((s) => s.trim()).toList();
      if (list.contains(key)) return false;
    }

    return true;
  }

  Future<bool> recordAndApplyChange({
    required String key,
    required Object? newValue,
    required String reasonFa,
  }) async {
    if (!canAiModify(key)) return false;

    final oldValue = SettingsService.instance.get<Object?>(key);
    final ok = await SettingsService.instance.set(
      key,
      newValue,
      origin: SettingsWriteOrigin.ai,
    );

    if (ok) {
      await recordAiChange(
        key: key,
        oldValue: oldValue,
        newValue: newValue,
        reason: reasonFa,
      );
      return true;
    }
    return false;
  }

  Future<void> recordAiChange({
    required String key,
    required Object? oldValue,
    required Object? newValue,
    required String reason,
  }) async {
    try {
      await ensureTableExists();
      final db = await DatabaseHelper.instance.database;
      await db.insert(tableName, {
        'setting_key': key,
        'old_value': oldValue != null ? jsonEncode(oldValue) : null,
        'new_value': newValue != null ? jsonEncode(newValue) : null,
        'reason': reason,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e, st) {
      RitmoLog.error('Settings', 'خطا در ثبت تاریخچه تغییر دستیار', e, st);
    }
  }

  Future<List<AiSettingHistoryRecord>> getHistory({int limit = 50}) async {
    try {
      await ensureTableExists();
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        tableName,
        orderBy: 'timestamp DESC',
        limit: limit,
      );
      return rows.map(AiSettingHistoryRecord.fromMap).toList();
    } catch (e, st) {
      RitmoLog.error('Settings', 'خطا در بازیابی تاریخچه تغییر دستیار', e, st);
      return [];
    }
  }

  Future<bool> rollbackChange(int historyId) async {
    try {
      await ensureTableExists();
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        tableName,
        where: 'id = ?',
        whereArgs: [historyId],
        limit: 1,
      );
      if (rows.isEmpty) return false;

      final record = AiSettingHistoryRecord.fromMap(rows.first);
      if (record.oldValue != null) {
        await SettingsService.instance.set(record.key, record.oldValue);
      } else {
        final desc = SettingsRegistry.find(record.key);
        if (desc != null) {
          await SettingsService.instance.resetToDefault(record.key);
        }
      }

      await db.delete(tableName, where: 'id = ?', whereArgs: [historyId]);
      return true;
    } catch (e, st) {
      RitmoLog.error('Settings', 'خطا در بازگردانی تغییر دستیار', e, st);
      return false;
    }
  }
}
