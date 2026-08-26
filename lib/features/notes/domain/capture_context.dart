import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/time/ritmo_clock.dart';
import 'package:shamsi_date/shamsi_date.dart';

@immutable
class CaptureContext {
  final String dayKey;
  final String timeOfDay; // MORNING | AFTERNOON | EVENING | NIGHT
  final int weekdayJalali; // 1..7 (1=Shanbeh)
  final int? energy;
  final int? mood;
  final int? sleepDebtMin;
  final Map<String, dynamic>? activeSession;
  final String? activeZone;

  const CaptureContext({
    required this.dayKey,
    required this.timeOfDay,
    required this.weekdayJalali,
    this.energy,
    this.mood,
    this.sleepDebtMin,
    this.activeSession,
    this.activeZone,
  });

  Map<String, dynamic> toMap() => {
    'dayKey': dayKey,
    'timeOfDay': timeOfDay,
    'weekdayJalali': weekdayJalali,
    if (energy != null) 'energy': energy,
    if (mood != null) 'mood': mood,
    if (sleepDebtMin != null) 'sleepDebtMin': sleepDebtMin,
    if (activeSession != null) 'activeSession': activeSession,
    if (activeZone != null) 'activeZone': activeZone,
  };

  String toJson() => jsonEncode(toMap());

  factory CaptureContext.fromMap(Map<String, dynamic> map) {
    return CaptureContext(
      dayKey: map['dayKey'] as String? ?? const SystemClock().today().value,
      timeOfDay: map['timeOfDay'] as String? ?? 'DAY',
      weekdayJalali: map['weekdayJalali'] as int? ?? 1,
      energy: map['energy'] as int?,
      mood: map['mood'] as int?,
      sleepDebtMin: map['sleepDebtMin'] as int?,
      activeSession: map['activeSession'] != null
          ? Map<String, dynamic>.from(map['activeSession'] as Map)
          : null,
      activeZone: map['activeZone'] as String?,
    );
  }

  factory CaptureContext.fromJson(String jsonStr) {
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return CaptureContext.fromMap(map);
    } catch (e, st) {
      RitmoLog.warning('CaptureContext', 'Failed to parse CaptureContext from JSON: $jsonStr', e, st);
      return CaptureContext(
        dayKey: const SystemClock().today().value,
        timeOfDay: 'DAY',
        weekdayJalali: 1,
      );
    }
  }

  static String _getTimeOfDayLabel(DateTime now) {
    final hour = now.hour;
    if (hour >= 5 && hour < 12) return 'MORNING';
    if (hour >= 12 && hour < 17) return 'AFTERNOON';
    if (hour >= 17 && hour < 22) return 'EVENING';
    return 'NIGHT';
  }

  /// Builds a snapshot of current system context safely (D-04).
  static Future<CaptureContext> buildCurrent({String? activeZone}) async {
    const clock = SystemClock();
    final now = clock.now();
    final dayKey = clock.today().value;
    final jalali = Jalali.fromDateTime(now);

    int? energy;
    int? mood;
    int? sleepDebtMin;
    Map<String, dynamic>? activeSession;

    try {
      final db = await DatabaseHelper.instance.database;

      // 1. Fetch energy / mood (only if logged in the last 12 hours)
      final recencyThresholdMs = now
          .subtract(const Duration(hours: 12))
          .millisecondsSinceEpoch;
      final energyRows = await db.query(
        'energy_logs',
        where: 'loggedAt >= ?',
        whereArgs: [recencyThresholdMs],
        orderBy: 'loggedAt DESC',
        limit: 1,
      );
      if (energyRows.isNotEmpty) {
        energy = (energyRows.first['level'] as num?)?.toInt();
      }

      final moodRows = await db.query(
        'mood_logs',
        where: 'loggedAt >= ?',
        whereArgs: [recencyThresholdMs],
        orderBy: 'loggedAt DESC',
        limit: 1,
      );
      if (moodRows.isNotEmpty) {
        mood = (moodRows.first['valence'] as num?)?.toInt();
      }

      // 2. Fetch active study session if exists
      final studyTimerTables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='study_active_session';",
      );
      if (studyTimerTables.isNotEmpty) {
        final activeRows = await db.query('study_active_session', limit: 1);
        if (activeRows.isNotEmpty) {
          final s = activeRows.first;
          final startMs = s['startedAt'] as int? ?? now.millisecondsSinceEpoch;
          final elapsedMin = ((now.millisecondsSinceEpoch - startMs) / 60000)
              .round();
          activeSession = {
            'module': 'study',
            'entityId': s['subjectId'] ?? s['topicId'] ?? '',
            'elapsedMin': elapsedMin,
          };
        }
      }
    } catch (e, st) {
      RitmoLog.warning('CaptureContext', 'Failed to build full current CaptureContext', e, st);
    }

    return CaptureContext(
      dayKey: dayKey,
      timeOfDay: _getTimeOfDayLabel(now),
      weekdayJalali: jalali.weekDay,
      energy: energy,
      mood: mood,
      sleepDebtMin: sleepDebtMin,
      activeSession: activeSession,
      activeZone: activeZone,
    );
  }
}
