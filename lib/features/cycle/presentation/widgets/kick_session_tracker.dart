import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:ritmo/core/database/database_helper.dart';

/// UX-04 KickSessionTracker logic with 2-minute burst gap, 2-hour auto-end,
/// app_settings persistence, and 7-session personal baseline comparison.
class KickSessionTracker {
  static const burstGap = Duration(minutes: 2);
  static const sessionLimit = Duration(hours: 2);
  static const targetCount = 10;

  int count = 0;
  DateTime? lastTap;
  DateTime? start;

  KickSessionTracker({this.count = 0, this.start, this.lastTap});

  /// Registers a tap at time [now]. Returns true if target count (10) reached.
  bool registerTap(DateTime now) {
    start ??= now;
    if (lastTap == null || now.difference(lastTap!) > burstGap) {
      count++;
    }
    lastTap = now;
    return count >= targetCount;
  }

  /// Checks whether the 2-hour session limit has expired at time [now].
  bool isExpired(DateTime now) {
    if (start == null) return false;
    return now.difference(start!) >= sessionLimit;
  }

  /// Restores session state from database `app_settings`.
  static Future<KickSessionTracker?> restoreFromSettings(DateTime now) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        'app_settings',
        where:
            "key IN ('preg_kick_session_start', 'preg_kick_session_count', 'preg_kick_session_last_tap')",
      );

      final map = <String, String>{};
      for (final r in rows) {
        map[r['key'] as String] = r['value'] as String;
      }

      final startMsStr = map['preg_kick_session_start'];
      if (startMsStr == null) return null;

      final startMs = int.tryParse(startMsStr);
      if (startMs == null) return null;

      final startDt = DateTime.fromMillisecondsSinceEpoch(startMs);
      if (now.difference(startDt) >= sessionLimit) {
        // Session expired while app was closed
        await clearSettings();
        return null;
      }

      final countVal = int.tryParse(map['preg_kick_session_count'] ?? '0') ?? 0;
      final lastTapMsStr = map['preg_kick_session_last_tap'];
      final lastTapDt = lastTapMsStr != null
          ? DateTime.fromMillisecondsSinceEpoch(int.parse(lastTapMsStr))
          : null;

      return KickSessionTracker(
        count: countVal,
        start: startDt,
        lastTap: lastTapDt,
      );
    } catch (_) {
      return null;
    }
  }

  /// Persists session state into `app_settings`.
  Future<void> saveToSettings() async {
    if (start == null) return;
    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert('app_settings', {
        'key': 'preg_kick_session_start',
        'value': start!.millisecondsSinceEpoch.toString(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await db.insert('app_settings', {
        'key': 'preg_kick_session_count',
        'value': count.toString(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      if (lastTap != null) {
        await db.insert('app_settings', {
          'key': 'preg_kick_session_last_tap',
          'value': lastTap!.millisecondsSinceEpoch.toString(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    } catch (_) {}
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
    } catch (_) {}
  }

  /// Saves finished kick session record into `kick_counts` table.
  Future<void> saveRecordToDb({required String pregnancyId}) async {
    if (start == null) return;
    try {
      final db = await DatabaseHelper.instance.database;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      await db.insert('kick_counts', {
        'id': 'kick_${DateTime.now().microsecondsSinceEpoch}',
        'pregnancyId': pregnancyId,
        'startTime': start!.millisecondsSinceEpoch,
        'endTime': (lastTap ?? start!).millisecondsSinceEpoch,
        'kickCount': count,
        'date': _formatYmd(start!),
        'createdAt': nowMs,
      });
      await clearSettings();
    } catch (_) {}
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
    } catch (_) {
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
