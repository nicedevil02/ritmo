import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';

class SsWeekResolver {
  /// هفته‌ی فعال برنامه را بر اساس تاریخ شروع برنامه محاسبه می‌کند.
  /// خروجی همیشه در بازه‌ی [1, totalWeeks] است.
  static int resolveActiveWeek({
    required DateTime programStartDate,
    required DateTime targetDate,
    required int totalWeeks,
  }) {
    if (totalWeeks <= 0) return 1;
    final start = DateTime(programStartDate.year, programStartDate.month, programStartDate.day);
    final target = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final diff = target.difference(start).inDays;
    if (diff < 0) return 1;
    return ((diff ~/ 7) % totalWeeks) + 1;
  }

  /// Helper to resolve programStartDate from DB or fallback
  static Future<DateTime> resolveProgramStartDate(Database db) async {
    try {
      final userProfile = await db.query(
        'ss_user_profile',
        columns: ['programStartDate'],
        limit: 1,
      );
      if (userProfile.isNotEmpty) {
        final startStr = userProfile.first['programStartDate'] as String?;
        if (startStr != null && startStr.isNotEmpty) {
          final dt = DateTime.tryParse(startStr);
          if (dt != null) return dt;
        }
      }
    } catch (e) { debugPrint('[ss] ss_week_resolver.dart: $e'); }

    try {
      final minCreated = await db.rawQuery(
        'SELECT MIN(createdAt) as minCreated FROM ss_workout_plan',
      );
      if (minCreated.isNotEmpty && minCreated.first['minCreated'] != null) {
        final ms = minCreated.first['minCreated'] as int;
        if (ms > 0) {
          return DateTime.fromMillisecondsSinceEpoch(ms);
        }
      }
    } catch (e) { debugPrint('[ss] ss_week_resolver.dart: $e'); }

    return DateTime.now();
  }

  /// Helper to resolve totalWeeks from DB
  static Future<int> resolveTotalWeeks(Database db) async {
    try {
      final res = await db.rawQuery(
        'SELECT COUNT(DISTINCT week) as weekCount FROM ss_workout_plan WHERE week IS NOT NULL AND week > 0',
      );
      if (res.isNotEmpty && res.first['weekCount'] != null) {
        final count = res.first['weekCount'] as int;
        if (count > 0) return count;
      }
    } catch (e) { debugPrint('[ss] ss_week_resolver.dart: $e'); }

    try {
      final plans = await db.query('ss_workout_plan', columns: ['id']);
      final weeks = <int>{};
      final reg = RegExp(r'^plan_w(\d+)_');
      for (final p in plans) {
        final id = p['id']?.toString() ?? '';
        final match = reg.firstMatch(id);
        if (match != null) {
          final w = int.tryParse(match.group(1)!);
          if (w != null && w > 0) weeks.add(w);
        }
      }
      if (weeks.isNotEmpty) return weeks.length;
    } catch (e) { debugPrint('[ss] ss_week_resolver.dart: $e'); }

    return 4;
  }

  /// Format raw muscleGroups JSON into clean Farsi title
  static String formatSportTitle(Map<String, dynamic> plan) {
    final raw = plan['muscleGroups']?.toString();
    if (raw == null || raw.trim().isEmpty) return 'تمرین ورزشی';
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List && decoded.isNotEmpty) {
        return 'تمرین ${decoded.map((e) => e.toString()).join(' و ')}';
      }
    } catch (e) { debugPrint('[ss] ss_week_resolver.dart: $e'); }
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'تمرین ورزشی';
    return 'تمرین $trimmed';
  }
}
