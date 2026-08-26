import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/upsert_helper.dart';
import 'package:ritmo/core/observability/ritmo_logger.dart';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';

/// UX-04 KickSessionTracker logic with 2-minute burst gap, 2-hour auto-end,
/// app_settings persistence, and 7-session personal baseline comparison.
class KickSessionTracker {
  static const burstGap = Duration(minutes: 2);
  static const defaultSessionLimit = Duration(hours: 2);
  static const defaultTargetCount = 10;

  // Alias constants for backward compatibility
  static const sessionLimit = defaultSessionLimit;
  static const targetCount = defaultTargetCount;

  int count = 0;
  DateTime? lastTap;
  DateTime? start;
  final int target;
  final Duration limit;

  KickSessionTracker({
    this.count = 0,
    this.start,
    this.lastTap,
    this.target = defaultTargetCount,
    this.limit = defaultSessionLimit,
  });

  /// Registers a tap at time [now]. Returns true if target count reached.
  bool registerTap(DateTime now) {
    start ??= now;
    if (lastTap == null || now.difference(lastTap!) > burstGap) {
      count++;
    }
    lastTap = now;
    return count >= target;
  }

  /// Returns total active elapsed duration.
  Duration get elapsed {
    if (start == null) return Duration.zero;
    return (lastTap ?? start!).difference(start!);
  }

  /// Checks if session has expired (> limit without completion).
  bool isExpired(DateTime now) {
    if (start == null) return false;
    return now.difference(start!) > limit;
  }

  /// Restores session state from database `app_settings`.
  static Future<KickSessionTracker?> restoreFromSettings(
    DateTime now, {
    int? target,
    Duration? limit,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        'app_settings',
        where:
            "key IN ('preg_kick_session_start', 'preg_kick_session_count', 'preg_kick_session_last_tap', 'preg_kick_target_count', 'preg_kick_window_minutes')",
      );

      final map = <String, String>{};
      for (final r in rows) {
        map[r['key'] as String] = r['value'] as String;
      }

      final startMsStr = map['preg_kick_session_start'];
      if (startMsStr == null) return null;

      final startMs = int.tryParse(startMsStr);
      if (startMs == null) return null;

      final targetVal =
          target ??
          int.tryParse(map['preg_kick_target_count'] ?? '') ??
          defaultTargetCount;
      final windowMins =
          int.tryParse(map['preg_kick_window_minutes'] ?? '') ?? 120;
      final effectiveLimit = limit ?? Duration(minutes: windowMins);

      final startDt = DateTime.fromMillisecondsSinceEpoch(startMs);
      if (now.difference(startDt) >= effectiveLimit) {
        // Session expired while app was closed
        await clearSettings();
        return null;
      }

      final countVal = int.tryParse(map['preg_kick_session_count'] ?? '0') ?? 0;
      final lastTapMsStr = map['preg_kick_session_last_tap'];
      final lastTapMs = lastTapMsStr != null ? int.tryParse(lastTapMsStr) : null;
      final lastTapDt = lastTapMs != null
          ? DateTime.fromMillisecondsSinceEpoch(lastTapMs)
          : null;

      return KickSessionTracker(
        count: countVal,
        start: startDt,
        lastTap: lastTapDt,
        target: targetVal,
        limit: effectiveLimit,
      );
    } catch (e, st) {
      RitmoLogger.error(
        '[KickSessionTracker] error restoring from settings: $e',
        error: e,
        stack: st,
      );
      return null;
    }
  }

  /// Loads persisted session state from `app_settings` table.
  static Future<KickSessionTracker?> loadFromSettings({
    int? target,
    Duration? limit,
  }) => restoreFromSettings(CycleClock.now, target: target, limit: limit);

  /// Persists session state into `app_settings`.
  Future<void> saveToSettings() async {
    if (start == null) return;
    try {
      final db = await DatabaseHelper.instance.database;
      final nowMs = CycleClock.nowMillisecondsSinceEpoch;
      await UpsertHelper.upsert(
        db,
        'app_settings',
        {
          'key': 'preg_kick_session_start',
          'value': start!.millisecondsSinceEpoch.toString(),
          'updatedAt': nowMs,
        },
        conflictColumns: const ['key'],
      );
      await UpsertHelper.upsert(
        db,
        'app_settings',
        {
          'key': 'preg_kick_session_count',
          'value': count.toString(),
          'updatedAt': nowMs,
        },
        conflictColumns: const ['key'],
      );
      if (lastTap != null) {
        await UpsertHelper.upsert(
          db,
          'app_settings',
          {
            'key': 'preg_kick_session_last_tap',
            'value': lastTap!.millisecondsSinceEpoch.toString(),
            'updatedAt': nowMs,
          },
          conflictColumns: const ['key'],
        );
      }
    } catch (e, st) {
      RitmoLogger.error(
        '[KickSessionTracker] Failed to save to settings: $e',
        error: e,
        stack: st,
      );
    }
  }

  /// Clears session keys from `app_settings`.
  static Future<void> clearSettings() async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete(
        'app_settings',
        where:
            "key IN ('preg_kick_session_start', 'preg_kick_session_count', 'preg_kick_session_last_tap')",
      );
    } catch (e, st) {
      RitmoLogger.error(
        '[KickSessionTracker] Failed to clear settings: $e',
        error: e,
        stack: st,
      );
    }
  }

  /// Saves finished kick session record into `kick_counts` table.
  Future<void> saveRecordToDb({required String pregnancyId}) async {
    if (start == null) return;
    try {
      final db = await DatabaseHelper.instance.database;
      final nowMs = CycleClock.nowMillisecondsSinceEpoch;
      await db.insert('kick_counts', {
        'id': 'kick_${CycleClock.now.microsecondsSinceEpoch}',
        'pregnancyId': pregnancyId,
        'startTime': start!.millisecondsSinceEpoch,
        'endTime': (lastTap ?? start!).millisecondsSinceEpoch,
        'kickCount': count,
        'date': _formatYmd(start!),
        'createdAt': nowMs,
      });
      await clearSettings();
    } catch (e, st) {
      RitmoLogger.error(
        '[KickSessionTracker] Failed to save record to DB: $e',
        error: e,
        stack: st,
      );
    }
  }

  /// Calculates personal baseline average duration (in seconds) over last 7 complete sessions.
  /// Returns null if fewer than 3 complete sessions exist.
  static Future<double?> getPersonalBaselineDurationSecs({
    required String pregnancyId,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        'kick_counts',
        where: 'pregnancyId = ? AND kickCount >= 10',
        whereArgs: [pregnancyId],
        orderBy: 'startTime DESC',
        limit: 7,
      );

      if (rows.length < 3) return null;

      double totalSecs = 0;
      for (final r in rows) {
        final st = (r['startTime'] as int?) ?? 0;
        final et = (r['endTime'] as int?) ?? st;
        totalSecs += (et - st) / 1000;
      }
      return totalSecs / rows.length;
    } catch (e, st) {
      RitmoLogger.error(
        '[KickSessionTracker] Failed to get personal baseline: $e',
        error: e,
        stack: st,
      );
      return null;
    }
  }

  /// Compares current session duration against personal baseline.
  /// If current duration > 1.5 * baseline, returns feedback message.
  static String? evaluatePersonalBaseline({
    required double currentDurationSecs,
    required double? baselineSecs,
  }) {
    if (baselineSecs == null) return null;
    if (currentDurationSecs > 1.5 * baselineSecs) {
      return 'این جلسه طولانی‌تر از الگوی معمول شما بود.';
    }
    return null;
  }

  static String _formatYmd(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
