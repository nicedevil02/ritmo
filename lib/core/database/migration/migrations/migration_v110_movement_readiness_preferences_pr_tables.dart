import 'package:ritmo/core/database/migration/migration_interface.dart';
import 'package:ritmo/core/database/schema/tables/movement_tables.dart';
import 'package:sqflite/sqflite.dart';

/// مایگریشن ۱۱۰: ایجاد جداول چک‌این آمادگی، تنظیمات حرکت و رکوردهای شخصی (Gate 5)
class MigrationV110MovementReadinessPreferencesPrTables extends Migration {
  @override
  int get version => 110;

  @override
  Future<void> up(covariant DatabaseExecutor db) async {
    // ۱. جدول چک‌این آمادگی
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${MovementTables.tableReadinessCheckins} (
        id TEXT PRIMARY KEY,
        dateIso TEXT NOT NULL,
        sleep INTEGER,
        energy INTEGER,
        soreness INTEGER,
        stress INTEGER,
        availableMinutes INTEGER,
        createdAt TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movement_readiness_date
        ON ${MovementTables.tableReadinessCheckins} (dateIso);
    ''');

    // ۲. جدول تنظیمات و ترجیحات
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${MovementTables.tablePreferences} (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    ''');

    // ۳. جدول رکوردهای شخصی واقعی
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${MovementTables.tablePersonalRecords} (
        id TEXT PRIMARY KEY,
        activityKindId TEXT,
        exerciseId TEXT,
        recordType TEXT NOT NULL,
        value REAL NOT NULL,
        unit TEXT NOT NULL,
        achievedAt TEXT NOT NULL,
        sourceId TEXT
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movement_pr_kind
        ON ${MovementTables.tablePersonalRecords} (activityKindId);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movement_pr_exercise
        ON ${MovementTables.tablePersonalRecords} (exerciseId);
    ''');
  }

  @override
  Future<void> down(covariant DatabaseExecutor db) async {
    await db.execute('DROP TABLE IF EXISTS ${MovementTables.tablePersonalRecords};');
    await db.execute('DROP TABLE IF EXISTS ${MovementTables.tablePreferences};');
    await db.execute('DROP TABLE IF EXISTS ${MovementTables.tableReadinessCheckins};');
  }
}
