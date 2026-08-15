import 'package:ritmo/core/database/schema/tables/ai_tables.dart';
import 'package:ritmo/core/database/schema/tables/assistant_tables.dart';
import 'package:ritmo/core/database/schema/tables/course_tables.dart';
import 'package:ritmo/core/database/schema/tables/cycle_tables.dart';
import 'package:ritmo/core/database/schema/tables/day_plan_tables.dart';
import 'package:ritmo/core/database/schema/tables/goal_tables.dart';
import 'package:ritmo/core/database/schema/tables/health_tables.dart';
import 'package:ritmo/core/database/schema/tables/konkur_tables.dart';
import 'package:ritmo/core/database/schema/tables/note_tables.dart';
import 'package:ritmo/core/database/schema/tables/routine_tables.dart';
import 'package:ritmo/core/database/schema/tables/sleep_tables.dart';
import 'package:ritmo/core/database/schema/tables/sports_tables.dart';
import 'package:ritmo/core/database/schema/tables/supplementary_sports_tables.dart';
import 'package:ritmo/core/database/schema/tables/system_tables.dart';
import 'package:ritmo/core/database/schema/tables/worship_tables.dart';
import 'package:ritmo/core/database/schema/tables/zone_tables.dart';
import 'package:sqflite/sqflite.dart';

class SchemaManager {
  // ⚠️ قانون: createAll() همیشه باید آینهی دقیق آخرین نسخهی اسکیما باشد.
  // هر مهاجرتی که جدول یا ستون جدید میسازد، باید همزمان اینجا هم منعکس شود.
  // در غیر این صورت نصبهای تازه و دستگاههای ارتقایافته دو اسکیمای متفاوت خواهند داشت.
  static Future<void> createAll(Database db) async {
    await RoutineTables.create(db);
    await WorshipTables.create(db);
    await HealthTables.create(db);
    await CourseTables.create(db);
    await GoalTables.create(db);
    await ZoneTables.create(db);
    await CycleTables.create(db);
    await KonkurTables.create(db);
    await SportsTables.create(db);
    await SystemTables.create(db);
    await SupplementarySportsTables.create(db);
    await AssistantTables.create(db);
    await AiTables.create(db);
    await DayPlanTables.create(db);
    await NoteTables.create(db);
    await SleepTables.create(db);
  }

  /// Safely checks if a column exists in a given SQLite table without throwing exceptions.
  static Future<bool> columnExists(DatabaseExecutor db, String table, String column) async {
    try {
      final columns = await db.rawQuery('PRAGMA table_info($table)');
      return columns.any((c) => c['name']?.toString().toLowerCase() == column.toLowerCase());
    } catch (_) {
      return false;
    }
  }

  /// Safely adds a column to an SQLite table only if it does not already exist.
  static Future<void> safeAddColumn(DatabaseExecutor db, String table, String column, String typeDefinition) async {
    try {
      final exists = await columnExists(db, table, column);
      if (!exists) {
        await db.execute('ALTER TABLE $table ADD COLUMN $column $typeDefinition;');
      }
    } catch (_) {}
  }
}
