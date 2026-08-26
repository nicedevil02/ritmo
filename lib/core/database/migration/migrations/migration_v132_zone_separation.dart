import 'package:ritmo/core/database/migration/migration_interface.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:sqflite/sqflite.dart';

/// Migration V132: Real Separation, Zone Budgets & Schedule Profiles (F-11, F-12, F-13).
class MigrationV132ZoneSeparation extends Migration {
  MigrationV132ZoneSeparation();

  @override
  int get version => 132;

  @override
  Future<void> up(DatabaseExecutor db) async {
    RitmoLog.info('MigrationV132', 'Starting Migration V132 Zone Separation...');

    // 1. F-11: Add hideOtherRealms to zones
    await safeAddColumn(db, 'zones', 'hideOtherRealms', 'INTEGER NOT NULL DEFAULT 0');

    // 2. F-12: Create zone_budgets table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS zone_budgets (
        zoneId      TEXT PRIMARY KEY,
        minMinutes  INTEGER,
        maxMinutes  INTEGER,
        period      TEXT NOT NULL DEFAULT 'WEEK',
        updatedAt   INTEGER NOT NULL,
        FOREIGN KEY(zoneId) REFERENCES zones(id) ON DELETE CASCADE
      );
    ''');

    // 3. F-13: Create zone_profiles table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS zone_profiles (
        id        TEXT PRIMARY KEY,
        name      TEXT NOT NULL,
        isActive  INTEGER NOT NULL DEFAULT 0,
        createdAt INTEGER NOT NULL
      );
    ''');

    // 4. F-13: Add profileId & isEnabled to zone_schedules
    await safeAddColumn(db, 'zone_schedules', 'profileId', 'TEXT');
    await safeAddColumn(db, 'zone_schedules', 'isEnabled', 'INTEGER NOT NULL DEFAULT 1');

    RitmoLog.info('MigrationV132', 'Migration V132 applied successfully');
  }

  @override
  Future<void> down(DatabaseExecutor db) async {
    RitmoLog.info('MigrationV132', 'Rolling back Migration V132...');
    await db.execute('DROP TABLE IF EXISTS zone_profiles;');
    await db.execute('DROP TABLE IF EXISTS zone_budgets;');
  }
}
