import 'package:ritmo/core/database/migration/migration_interface.dart';
import 'package:ritmo/core/database/schema/tables/movement_tables.dart';
import 'package:sqflite/sqflite.dart';

/// مایگریشن نسخهٔ ۱۰۷: ساخت جداول برنامه‌ریزی حرکت (Templates, Schedules, Workout Logs)
class MigrationV107MovementPlanning extends Migration {
  @override
  int get version => 107;

  @override
  bool get requiresTransaction => true;

  @override
  Future<void> up(DatabaseExecutor db) async {
    // ۱. جدول قالب‌های برنامهٔ حرکت
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${MovementTables.tablePlanTemplates} (
        id TEXT PRIMARY KEY,
        activityKindId TEXT NOT NULL,
        sessionType TEXT NOT NULL,
        goalJson TEXT,
        reminderType TEXT NOT NULL,
        reminderOffsetMin INTEGER,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        archivedAt TEXT
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movement_plan_templates_kind
        ON ${MovementTables.tablePlanTemplates} (activityKindId);
    ''');

    // ۲. جدول زمان‌بندی‌های قالب برنامه
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${MovementTables.tablePlanSchedules} (
        id TEXT PRIMARY KEY,
        templateId TEXT NOT NULL,
        weekday INTEGER NOT NULL,
        timeOfDay TEXT NOT NULL,
        recurrence TEXT NOT NULL,
        startDateIso TEXT NOT NULL,
        weeksCount INTEGER,
        createdAt TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movement_plan_schedules_template
        ON ${MovementTables.tablePlanSchedules} (templateId);
    ''');

    // ۳. جدول تاریخچهٔ ثبت تمرین (Log)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${MovementTables.tableWorkoutLogs} (
        id TEXT PRIMARY KEY,
        occurrenceId TEXT,
        activityKindId TEXT NOT NULL,
        dateIso TEXT NOT NULL,
        startTime TEXT,
        durationSec INTEGER NOT NULL,
        metricJson TEXT,
        feeling TEXT,
        note TEXT,
        source TEXT NOT NULL,
        createdAt TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movement_workout_logs_date
        ON ${MovementTables.tableWorkoutLogs} (dateIso);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movement_workout_logs_occurrence
        ON ${MovementTables.tableWorkoutLogs} (occurrenceId);
    ''');
  }

  @override
  Future<void> down(DatabaseExecutor db) async {
    await db.execute('DROP TABLE IF EXISTS ${MovementTables.tableWorkoutLogs};');
    await db.execute('DROP TABLE IF EXISTS ${MovementTables.tablePlanSchedules};');
    await db.execute('DROP TABLE IF EXISTS ${MovementTables.tablePlanTemplates};');
  }
}
