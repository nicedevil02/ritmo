import 'package:ritmo/core/database/migration/migration_interface.dart';
import 'package:ritmo/core/database/schema/tables/movement_tables.dart';
import 'package:sqflite/sqflite.dart';

/// مایگریشن نسخهٔ ۱۰۸: تکمیل جدول جلسات زنده و افزودن جدول رویدادهای زنده (movement_session_events)
class MigrationV108MovementLiveEvents extends Migration {
  @override
  int get version => 108;

  @override
  Future<void> up(covariant DatabaseExecutor db) async {
    // ۱. افزودن ستون finishedAt به جدول movement_live_sessions در صورت عدم وجود
    await safeAddColumn(
      db,
      MovementTables.tableLiveSessions,
      'finishedAt',
      'TEXT',
    );

    // ۲. ایجاد جدول رویدادهای زنده
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${MovementTables.tableSessionEvents} (
        id TEXT PRIMARY KEY,
        sessionId TEXT NOT NULL,
        type TEXT NOT NULL,
        payloadJson TEXT,
        at TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movement_session_events_session
        ON ${MovementTables.tableSessionEvents} (sessionId);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movement_session_events_at
        ON ${MovementTables.tableSessionEvents} (at);
    ''');
  }

  @override
  Future<void> down(covariant DatabaseExecutor db) async {
    await db.execute('DROP TABLE IF EXISTS ${MovementTables.tableSessionEvents};');
  }
}
