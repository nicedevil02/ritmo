import 'package:ritmo/core/database/migration/migration_interface.dart';
import 'package:sqflite/sqflite.dart';
import 'package:ritmo/core/utils/persian_text.dart';

class MigrationV85 extends Migration {
  @override
  int get version => 85;

  @override
  Future<void> up(DatabaseExecutor db) async {
    try {
      await safeAddColumn(db, 'simple_tasks', 'titleNormalized', 'TEXT');
      
      final rows = await db.query('simple_tasks');
      for (final row in rows) {
        final id = row['id'] as String;
        final title = row['title'] as String;
        final normalized = normalizeFa(title);
        await db.update(
          'simple_tasks',
          {'titleNormalized': normalized},
          where: 'id = ?',
          whereArgs: [id],
        );
      }

      await db.execute('CREATE INDEX IF NOT EXISTS idx_simple_tasks_isdone_duedate ON simple_tasks(isDone, dueDate);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_simple_tasks_isdone_doneat ON simple_tasks(isDone, doneAt);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_simple_tasks_titlenormalized ON simple_tasks(titleNormalized);');
    } catch (_) {}
  }

  @override
  Future<void> down(DatabaseExecutor db) async {}
}
