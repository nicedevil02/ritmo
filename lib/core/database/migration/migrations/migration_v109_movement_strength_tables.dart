import 'package:ritmo/core/database/migration/migration_interface.dart';
import 'package:ritmo/core/database/schema/tables/movement_tables.dart';
import 'package:sqflite/sqflite.dart';

/// مایگریشن ۱۰۹: تکمیل جدول برنامه‌های قدرتی و ایجاد جداول روزها، حرکات و لاگ ست‌ها
class MigrationV109MovementStrengthTables extends Migration {
  @override
  int get version => 109;

  @override
  Future<void> up(covariant DatabaseExecutor db) async {
    // ۱. ستون‌های تکمیلی جدول برنامه‌های قدرتی
    final neededColumns = {
      'goal': 'TEXT',
      'level': 'TEXT',
      'sensitiveAreasJson': 'TEXT',
      'equipmentJson': 'TEXT',
      'sessionMinutes': 'INTEGER',
      'preferredDaysJson': 'TEXT',
      'preferredTime': 'TEXT',
      'deloadWeekIndex': 'INTEGER',
      'draftStep': 'INTEGER',
      'draftDataJson': 'TEXT',
    };

    for (final entry in neededColumns.entries) {
      await safeAddColumn(
        db,
        MovementTables.tableStrengthPrograms,
        entry.key,
        entry.value,
      );
    }

    // ۲. جدول روزهای برنامهٔ قدرتی
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${MovementTables.tableStrengthDays} (
        id TEXT PRIMARY KEY,
        programId TEXT NOT NULL,
        weekIndex INTEGER NOT NULL,
        weekday INTEGER NOT NULL,
        name TEXT NOT NULL,
        targetMusclesJson TEXT,
        estimatedMinutes INTEGER NOT NULL,
        orderIndex INTEGER NOT NULL
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movement_strength_days_program
        ON ${MovementTables.tableStrengthDays} (programId);
    ''');

    // ۳. جدول حرکات روزهای تمرین قدرتی
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${MovementTables.tableStrengthExercises} (
        id TEXT PRIMARY KEY,
        dayId TEXT NOT NULL,
        orderIndex INTEGER NOT NULL,
        nameFa TEXT NOT NULL,
        muscleGroup TEXT NOT NULL,
        sets INTEGER NOT NULL,
        repsMin INTEGER NOT NULL,
        repsMax INTEGER NOT NULL,
        restSec INTEGER NOT NULL,
        formTipsJson TEXT,
        alternativesJson TEXT,
        mediaRef TEXT
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movement_strength_exercises_day
        ON ${MovementTables.tableStrengthExercises} (dayId);
    ''');

    // ۴. جدول لاگ ست‌های تمرین قدرتی
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${MovementTables.tableSetLogs} (
        id TEXT PRIMARY KEY,
        sessionId TEXT,
        occurrenceId TEXT,
        exerciseId TEXT NOT NULL,
        setIndex INTEGER NOT NULL,
        weightKg REAL,
        reps INTEGER,
        rir REAL,
        completed INTEGER NOT NULL DEFAULT 0,
        skipped INTEGER NOT NULL DEFAULT 0,
        at TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movement_set_logs_session
        ON ${MovementTables.tableSetLogs} (sessionId);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movement_set_logs_exercise
        ON ${MovementTables.tableSetLogs} (exerciseId);
    ''');
  }

  @override
  Future<void> down(covariant DatabaseExecutor db) async {
    await db.execute('DROP TABLE IF EXISTS ${MovementTables.tableSetLogs};');
    await db.execute('DROP TABLE IF EXISTS ${MovementTables.tableStrengthExercises};');
    await db.execute('DROP TABLE IF EXISTS ${MovementTables.tableStrengthDays};');
  }
}
