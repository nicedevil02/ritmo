import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/features/simple_tasks/domain/task_bucket.dart';
import 'package:sqflite/sqflite.dart';

class TaskPreferences {
  static const String keyCompletionSound = 'tasks_completion_sound_enabled';
  static const String keyDailyNudgeEnabled = 'tasks_daily_nudge_enabled';
  static const String keyDailyNudgeTime = 'tasks_daily_nudge_time';
  static const String keySortMode = 'tasks_sort_mode';
  static const String keyHideCompleted = 'tasks_hide_completed';

  static String _bucketExpandedKey(TaskBucket bucket) =>
      'tasks_bucket_expanded_${bucket.name}';

  static Future<String?> _getSetting(String key) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: [key],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return rows.first['value'] as String?;
    } catch (e, st) {
      RitmoLog.warning('TaskPreferences', 'Failed to get setting $key', e, st);
      return null;
    }
  }

  static Future<void> _setSetting(String key, String value) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      await db.insert(
        'app_settings',
        {'key': key, 'value': value, 'updatedAt': nowMs},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e, st) {
      RitmoLog.error('TaskPreferences', 'Failed to set setting $key', e, st);
    }
  }

  static Future<bool> isBucketExpanded(TaskBucket bucket) async {
    final raw = await _getSetting(_bucketExpandedKey(bucket));
    if (raw == null) {
      return bucket != TaskBucket.doneToday;
    }
    return raw == '1' || raw.toLowerCase() == 'true';
  }

  static Future<void> setBucketExpanded(TaskBucket bucket, bool expanded) async {
    await _setSetting(_bucketExpandedKey(bucket), expanded ? '1' : '0');
  }

  static Future<bool> isCompletionSoundEnabled() async {
    final raw = await _getSetting(keyCompletionSound);
    if (raw == null) return true;
    return raw == '1' || raw.toLowerCase() == 'true';
  }

  static Future<void> setCompletionSoundEnabled(bool enabled) async {
    await _setSetting(keyCompletionSound, enabled ? '1' : '0');
  }

  static Future<bool> isDailyNudgeEnabled() async {
    final raw = await _getSetting(keyDailyNudgeEnabled);
    if (raw == null) return false;
    return raw == '1' || raw.toLowerCase() == 'true';
  }

  static Future<void> setDailyNudgeEnabled(bool enabled) async {
    await _setSetting(keyDailyNudgeEnabled, enabled ? '1' : '0');
  }

  static Future<String> getDailyNudgeTime() async {
    final raw = await _getSetting(keyDailyNudgeTime);
    return raw ?? '08:30';
  }

  static Future<void> setDailyNudgeTime(String time) async {
    await _setSetting(keyDailyNudgeTime, time);
  }

  static Future<String> getSortMode() async {
    final raw = await _getSetting(keySortMode);
    return raw ?? 'smart';
  }

  static Future<void> setSortMode(String mode) async {
    await _setSetting(keySortMode, mode);
  }

  static Future<bool> isHideCompleted() async {
    final raw = await _getSetting(keyHideCompleted);
    if (raw == null) return false;
    return raw == '1' || raw.toLowerCase() == 'true';
  }

  static Future<void> setHideCompleted(bool hide) async {
    await _setSetting(keyHideCompleted, hide ? '1' : '0');
  }
}
