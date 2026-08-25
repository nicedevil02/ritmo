import 'package:ritmo/core/database/migration/migration_interface.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:sqflite/sqflite.dart';

/// مایگریشن نسخهٔ ۱۲۵: جدول تعهدهای ورزشی هفتگی ثابت (mv_commitments)
class MigrationV125MvCommitments extends Migration {
  @override
  int get version => 125;

  @override
  Future<void> down(covariant DatabaseExecutor db) async {
    // Non-destructive down
  }

  @override
  Future<void> up(covariant DatabaseExecutor db) async {
    RitmoLog.info('MigrationV125MvCommitments', 'Starting mv_commitments migration v125...');

    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS mv_commitments (
          id                INTEGER PRIMARY KEY AUTOINCREMENT,
          kindCode          TEXT    NOT NULL,
          titleFa           TEXT,
          ritmoDayOfWeek    INTEGER NOT NULL,
          timeOfDay         TEXT    NOT NULL,
          durationMinutes   INTEGER NOT NULL DEFAULT 60,
          intensityTier     TEXT    NOT NULL DEFAULT 'MODERATE',
          venueNote         TEXT,
          isAnchor          INTEGER NOT NULL DEFAULT 1,
          isActive          INTEGER NOT NULL DEFAULT 1,
          effectiveFromIso  TEXT    NOT NULL,
          effectiveUntilIso TEXT,
          createdAt         INTEGER NOT NULL,
          updatedAt         INTEGER NOT NULL
        );
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_mv_commitments_day ON mv_commitments(ritmoDayOfWeek, isActive);
      ''');
    } catch (e) {
      RitmoLog.warning('MigrationV125MvCommitments', 'Error applying migration v125: $e');
    }

    RitmoLog.info('MigrationV125MvCommitments', 'Migration v125 completed successfully.');
  }
}
