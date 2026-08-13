import 'package:sqflite/sqflite.dart';
import 'package:ritmo/core/database/migration/migration_interface.dart';

/// Tab 1 week planner: this-week exceptions for movement routines.
///
/// Template stays in `routine_schedules`. A row here means SKIP / MOVE /
/// RETIME / LIGHT for a single `dateIso` without mutating the weekly template.
class MigrationV98MovementSlotOverrides extends Migration {
  @override
  int get version => 98;

  @override
  bool get requiresTransaction => true;

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS movement_slot_overrides (
        id TEXT PRIMARY KEY,
        routineId TEXT NOT NULL,
        dateIso TEXT NOT NULL,
        action TEXT NOT NULL,
        newDateIso TEXT,
        newTime TEXT,
        createdAt INTEGER NOT NULL,
        UNIQUE(routineId, dateIso)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_mso_date ON movement_slot_overrides(dateIso)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_mso_routine ON movement_slot_overrides(routineId)',
    );
  }

  @override
  Future<void> down(DatabaseExecutor db) async {
    await db.execute('DROP TABLE IF EXISTS movement_slot_overrides');
  }
}
