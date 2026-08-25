import 'package:ritmo/core/database/migration/migration_interface.dart';
import 'package:ritmo/core/database/schema/schema_manager.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:sqflite/sqflite.dart';

/// مایگریشن نسخهٔ ۱۲۷: افزودن ستون‌های متریک جلسه به جدول movement_sessions (S4-T1)
class MigrationV127SessionMetrics extends Migration {
  @override
  int get version => 127;

  @override
  Future<void> down(covariant DatabaseExecutor db) async {
    // Non-destructive down
  }

  @override
  Future<void> up(covariant DatabaseExecutor db) async {
    RitmoLog.info('MigrationV127SessionMetrics', 'Starting session metrics migration v127...');

    try {
      await SchemaManager.safeAddColumn(db, 'movement_sessions', 'distanceM', 'REAL');
      await SchemaManager.safeAddColumn(db, 'movement_sessions', 'elevationGainM', 'REAL');
      await SchemaManager.safeAddColumn(db, 'movement_sessions', 'laps', 'INTEGER');
      await SchemaManager.safeAddColumn(db, 'movement_sessions', 'packWeightKg', 'REAL');
      await SchemaManager.safeAddColumn(db, 'movement_sessions', 'rpe1To10', 'INTEGER');
      await SchemaManager.safeAddColumn(db, 'movement_sessions', 'effortSource', 'TEXT');
      await SchemaManager.safeAddColumn(db, 'movement_sessions', 'routeId', 'INTEGER');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_movement_sessions_kind_date
          ON movement_sessions(kindCode, startedAt);
      ''');
    } catch (e) {
      RitmoLog.warning('MigrationV127SessionMetrics', 'Error applying migration v127: $e');
    }

    RitmoLog.info('MigrationV127SessionMetrics', 'Migration v127 completed successfully.');
  }
}
