import 'package:ritmo/core/database/migration/migration_interface.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:sqflite/sqflite.dart';

/// مایگریشن نسخهٔ ۱۲۸: جدول مسیرهای ورزشی تکرارشونده (mv_routes / S4-T7)
class MigrationV128MvRoutes extends Migration {
  @override
  int get version => 128;

  @override
  Future<void> down(covariant DatabaseExecutor db) async {
    // Non-destructive down
  }

  @override
  Future<void> up(covariant DatabaseExecutor db) async {
    RitmoLog.info('MigrationV128MvRoutes', 'Starting mv_routes migration v128...');

    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS mv_routes (
          id              INTEGER PRIMARY KEY AUTOINCREMENT,
          titleFa         TEXT    NOT NULL,
          kindCode        TEXT    NOT NULL,
          distanceM       REAL,
          elevationGainM  REAL,
          notes           TEXT,
          timesCompleted  INTEGER NOT NULL DEFAULT 0,
          bestDurationMin INTEGER,
          lastDoneAt      TEXT,
          createdAt       TEXT    NOT NULL
        );
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_mv_routes_kind ON mv_routes(kindCode);
      ''');
    } catch (e) {
      RitmoLog.warning('MigrationV128MvRoutes', 'Error applying migration v128: $e');
    }

    RitmoLog.info('MigrationV128MvRoutes', 'Migration v128 completed successfully.');
  }
}
