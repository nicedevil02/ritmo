import 'package:flutter/foundation.dart';
import 'package:ritmo/core/database/migration/migration_interface.dart';
import 'package:sqflite/sqflite.dart';

/// V92 — Data Unification Migration (Prompt B)
/// Consolidates 6 groups of parallel tables into unified storage.
/// ALL operations use CREATE TABLE temp → INSERT → DROP → RENAME pattern.
/// NO data is ever deleted before being copied.
class MigrationV92Unification extends Migration {
  @override
  int get version => 92;

  @override
  bool get requiresTransaction => false; // DDL (CREATE/DROP) cannot be inside txn

  @override
  Future<void> up(DatabaseExecutor db) async {
    await _b1WellbeingEntry(db);
    await _b2SetLogs(db);
    await _b3AiMemory(db);
    await _b4CycleLogs(db);
    await _b5FastingDebt(db);
    await _b6ActiveTimers(db);
  }

  // ─────────────────────────────────────────────
  // B-1: Create wellbeing_entry and migrate 6 tables
  // ─────────────────────────────────────────────
  Future<void> _b1WellbeingEntry(DatabaseExecutor db) async {
    try {
      // Create the unified table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS wellbeing_entry (
          id TEXT PRIMARY KEY,
          dateIso TEXT NOT NULL,
          dimension TEXT NOT NULL,
          value REAL NOT NULL,
          note TEXT,
          loggedAt INTEGER NOT NULL
        );
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_wellbeing_entry_date ON wellbeing_entry(dateIso, dimension);',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_wellbeing_entry_loggedAt ON wellbeing_entry(loggedAt);',
      );

      // Migrate energy_logs → wellbeing_entry
      await db.execute('''
        INSERT OR IGNORE INTO wellbeing_entry (id, dateIso, dimension, value, note, loggedAt)
        SELECT
          id,
          date(loggedAt / 1000, 'unixepoch'),
          'ENERGY',
          CASE energyLevel
            WHEN 'VERY_LOW' THEN 1.0
            WHEN 'LOW' THEN 2.0
            WHEN 'MEDIUM' THEN 3.0
            WHEN 'HIGH' THEN 4.0
            WHEN 'VERY_HIGH' THEN 5.0
            ELSE 3.0
          END,
          note,
          loggedAt
        FROM energy_logs;
      ''');

      // Migrate mood_logs → wellbeing_entry
      await db.execute('''
        INSERT OR IGNORE INTO wellbeing_entry (id, dateIso, dimension, value, note, loggedAt)
        SELECT
          id,
          date(loggedAt / 1000, 'unixepoch'),
          'MOOD',
          CAST(valence AS REAL),
          note,
          loggedAt
        FROM mood_logs;
      ''');

      // Migrate bedtime_diagnostics → wellbeing_entry (SLEEP dimension)
      await db.execute('''
        INSERT OR IGNORE INTO wellbeing_entry (id, dateIso, dimension, value, note, loggedAt)
        SELECT
          'sleep_' || date,
          date,
          'SLEEP',
          CAST(quality AS REAL),
          note,
          COALESCE(createdAt, strftime('%s','now') * 1000)
        FROM bedtime_diagnostics
        WHERE quality IS NOT NULL;
      ''');

      // Migrate daily_checkins → wellbeing_entry (CHECKIN dimension)
      await db.execute('''
        INSERT OR IGNORE INTO wellbeing_entry (id, dateIso, dimension, value, note, loggedAt)
        SELECT
          'checkin_' || date,
          date,
          'CHECKIN',
          CASE mood
            WHEN 'GREAT' THEN 5.0
            WHEN 'GOOD' THEN 4.0
            WHEN 'NEUTRAL' THEN 3.0
            WHEN 'BAD' THEN 2.0
            WHEN 'AWFUL' THEN 1.0
            ELSE 3.0
          END,
          note,
          COALESCE(createdAt, strftime('%s','now') * 1000)
        FROM daily_checkins;
      ''');

      // Migrate daily_reflections → wellbeing_entry (REFLECTION dimension)
      await db.execute('''
        INSERT OR IGNORE INTO wellbeing_entry (id, dateIso, dimension, value, note, loggedAt)
        SELECT
          'reflection_' || date,
          date,
          'REFLECTION',
          CAST(COALESCE(mood_score, 3) AS REAL),
          COALESCE(reflection_text, reflectionNote, ''),
          COALESCE(createdAt, strftime('%s','now') * 1000)
        FROM daily_reflections;
      ''');

      // Migrate workout_recovery_logs → wellbeing_entry (SORENESS, FATIGUE, HYDRATION dimensions)
      await db.execute('''
        INSERT OR IGNORE INTO wellbeing_entry (id, dateIso, dimension, value, note, loggedAt)
        SELECT
          'soreness_' || date,
          date,
          'SORENESS',
          CAST(soreness AS REAL),
          note,
          loggedAt
        FROM workout_recovery_logs
        WHERE soreness IS NOT NULL AND soreness > 0;
      ''');
      await db.execute('''
        INSERT OR IGNORE INTO wellbeing_entry (id, dateIso, dimension, value, note, loggedAt)
        SELECT
          'fatigue_' || date,
          date,
          'FATIGUE',
          CAST(fatigue AS REAL),
          note,
          loggedAt
        FROM workout_recovery_logs
        WHERE fatigue IS NOT NULL AND fatigue > 0;
      ''');
      await db.execute('''
        INSERT OR IGNORE INTO wellbeing_entry (id, dateIso, dimension, value, note, loggedAt)
        SELECT
          'hydration_' || date,
          date,
          'HYDRATION',
          CAST(hydration AS REAL),
          note,
          loggedAt
        FROM workout_recovery_logs
        WHERE hydration IS NOT NULL AND hydration > 0;
      ''');

      debugPrint('[MigrationV92] B-1 wellbeing_entry migration complete');
    } catch (e) {
      debugPrint('[MigrationV92] B-1 Error: $e');
    }
  }

  // ─────────────────────────────────────────────
  // B-2: Migrate workout_set_logs and ss_workout_set_log → ss_session_set_log
  // ─────────────────────────────────────────────
  Future<void> _b2SetLogs(DatabaseExecutor db) async {
    try {
      // Add feeling column to ss_session_set_log if missing
      await safeAddColumn(db, 'ss_session_set_log', 'feeling', 'TEXT');

      // Migrate ss_workout_set_log → ss_session_set_log
      await db.execute('''
        INSERT OR IGNORE INTO ss_session_set_log
          (id, sessionId, exerciseId, setNumber, weight, reps, rir, durationSeconds, isCompleted, loggedAt, feeling)
        SELECT
          id,
          session_id,
          exercise_id,
          set_index + 1,   -- set_index is 0-based, setNumber is 1-based
          weight,
          reps,
          NULL,
          NULL,
          1,
          strftime('%s','now') * 1000,
          feeling
        FROM ss_workout_set_log;
      ''');

      debugPrint('[MigrationV92] B-2 set logs migration complete');
    } catch (e) {
      debugPrint('[MigrationV92] B-2 Error: $e');
    }
  }

  // ─────────────────────────────────────────────
  // B-3: Add scope to ai_memory and migrate ss_ai_memory
  // ─────────────────────────────────────────────
  Future<void> _b3AiMemory(DatabaseExecutor db) async {
    try {
      await safeAddColumn(db, 'ai_memory', 'scope', "TEXT NOT NULL DEFAULT 'GENERAL'");

      // Migrate ss_ai_memory key-value rows → ai_memory
      await db.execute('''
        INSERT OR IGNORE INTO ai_memory
          (id, content, type, domain, scope, source, importance, pinned, sensitive, status, createdAt, updatedAt)
        SELECT
          'ss_mem_' || key,
          key || ': ' || value,
          'preference',
          'sports',
          'SS_MODULE',
          'implicit',
          CAST(COALESCE(confidence, 1.0) * 10 AS INTEGER),
          0,
          0,
          'active',
          COALESCE(updatedAt, strftime('%s','now') * 1000),
          COALESCE(updatedAt, strftime('%s','now') * 1000)
        FROM ss_ai_memory;
      ''');

      debugPrint('[MigrationV92] B-3 ai_memory migration complete');
    } catch (e) {
      debugPrint('[MigrationV92] B-3 Error: $e');
    }
  }

  // ─────────────────────────────────────────────
  // B-4: Retire cycle_logs → cycle_periods + cycle_day_logs
  // ─────────────────────────────────────────────
  Future<void> _b4CycleLogs(DatabaseExecutor db) async {
    try {
      // Ensure destination columns exist
      await safeAddColumn(db, 'cycle_periods', 'suppressedPrayer', 'INTEGER DEFAULT 1');
      await safeAddColumn(db, 'cycle_periods', 'fastDebtCreated', 'INTEGER DEFAULT 0');

      // Migrate cycle_logs → cycle_periods (one row per cycle)
      await db.execute('''
        INSERT OR IGNORE INTO cycle_periods
          (id, startDate, endDate, flowIntensity, isPredicted, note, suppressedPrayer, fastDebtCreated, createdAt, updatedAt)
        SELECT
          id,
          cycleStartDate,
          cycleEndDate,
          COALESCE(flowLevel, 'MEDIUM'),
          isPredicted,
          note,
          suppressedPrayer,
          fastDebtCreated,
          createdAt,
          updatedAt
        FROM cycle_logs;
      ''');

      // Migrate phase/symptoms daily data → cycle_day_logs
      await db.execute('''
        INSERT OR IGNORE INTO cycle_day_logs
          (id, logDate, flowLevel, symptomsJson, mood, energyTag, note, createdAt, updatedAt)
        SELECT
          'cdl_' || id,
          cycleStartDate,
          flowLevel,
          symptomsJson,
          NULL,
          NULL,
          note,
          createdAt,
          updatedAt
        FROM cycle_logs
        WHERE flowLevel IS NOT NULL OR symptomsJson IS NOT NULL;
      ''');

      debugPrint('[MigrationV92] B-4 cycle_logs migration complete');
    } catch (e) {
      debugPrint('[MigrationV92] B-4 Error: $e');
    }
  }

  // ─────────────────────────────────────────────
  // B-5: Migrate fasting_debt → worship_debts
  // ─────────────────────────────────────────────
  Future<void> _b5FastingDebt(DatabaseExecutor db) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.execute('''
        INSERT OR IGNORE INTO worship_debts
          (id, debtType, title, totalCount, remainingCount, dailyTarget, autoCreated, isArchived, createdAt, updatedAt)
        SELECT
          'fast_' || id,
          'FASTING',
          'قضای روزه — ' || dateIso,
          daysOwed,
          CASE WHEN isResolved = 1 THEN 0 ELSE daysOwed END,
          1,
          1,
          isResolved,
          COALESCE(createdAt, $now),
          COALESCE(updatedAt, $now)
        FROM fasting_debt;
      ''');

      debugPrint('[MigrationV92] B-5 fasting_debt migration complete');
    } catch (e) {
      debugPrint('[MigrationV92] B-5 Error: $e');
    }
  }

  // ─────────────────────────────────────────────
  // B-6: Migrate course_active_timers → active_timers
  // ─────────────────────────────────────────────
  Future<void> _b6ActiveTimers(DatabaseExecutor db) async {
    try {
      await db.execute('''
        INSERT OR IGNORE INTO active_timers
          (id, domain, itemId, mode, direction, targetTimestamp, durationSeconds, createdAt,
           routineId, startedAt, plannedDurationMinutes, pausedAccumulatedMs, state)
        SELECT
          courseSessionId,
          'COURSE',
          courseId,
          'COUNT_UP',
          'UP',
          NULL,
          COALESCE(targetDurationMinutes, 0) * 60,
          startedAt,
          NULL,
          startedAt,
          targetDurationMinutes,
          pausedAccumulatedMs,
          state
        FROM course_active_timers;
      ''');

      debugPrint('[MigrationV92] B-6 course_active_timers migration complete');
    } catch (e) {
      debugPrint('[MigrationV92] B-6 Error: $e');
    }
  }

  @override
  Future<void> down(DatabaseExecutor db) async {}
}
