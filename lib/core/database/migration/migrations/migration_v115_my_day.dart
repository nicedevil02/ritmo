import 'package:ritmo/core/database/migration/migration_interface.dart';
import 'package:sqflite/sqflite.dart';

class MigrationV115MyDay extends Migration {
  @override
  int get version => 115;

  @override
  Future<void> up(DatabaseExecutor db) async {
    await safeAddColumn(db, 'simple_tasks', 'addedToMyDayAt', 'INTEGER');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_simple_tasks_myDay ON simple_tasks(addedToMyDayAt);',
    );
  }

  @override
  Future<void> down(DatabaseExecutor db) async {}
}
