import 'package:ritmo/core/database/migration/migration_interface.dart';
import 'package:ritmo/core/utils/persian_text.dart';
import 'package:sqflite/sqflite.dart';

class MigrationV116TagsAndNormalizedFields extends Migration {
  @override
  int get version => 116;

  @override
  Future<void> down(DatabaseExecutor db) async {}

  @override
  Future<void> up(DatabaseExecutor db) async {
    // 1. Add tagsJson and noteNormalized to simple_tasks
    await safeAddColumn(db, 'simple_tasks', 'tagsJson', 'TEXT');
    await safeAddColumn(db, 'simple_tasks', 'noteNormalized', 'TEXT');

    // 2. Add titleNormalized to task_steps
    await safeAddColumn(db, 'task_steps', 'titleNormalized', 'TEXT');

    // 3. Create indexes for performance
    await db.execute('CREATE INDEX IF NOT EXISTS idx_simple_tasks_noteNormalized ON simple_tasks (noteNormalized);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_task_steps_titleNormalized ON task_steps (titleNormalized);');

    // 4. Backfill noteNormalized for existing simple_tasks
    final tasks = await db.query('simple_tasks', columns: ['id', 'note']);
    for (final task in tasks) {
      final id = task['id'] as String;
      final note = task['note'] as String?;
      if (note != null && note.isNotEmpty) {
        final normalized = normalizeFa(note);
        await db.update(
          'simple_tasks',
          {'noteNormalized': normalized},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    }

    // 5. Backfill titleNormalized for existing task_steps
    final steps = await db.query('task_steps', columns: ['id', 'title']);
    for (final step in steps) {
      final id = step['id'] as String;
      final title = step['title'] as String?;
      if (title != null && title.isNotEmpty) {
        final normalized = normalizeFa(title);
        await db.update(
          'task_steps',
          {'titleNormalized': normalized},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    }

    // 6. Clean up obsolete/dead settings keys (T-38)
    await db.execute('''
      DELETE FROM app_settings WHERE key IN (
        'daily_planning_nudge_enabled',
        'daily_planning_nudge_time',
        'tasks_confirm_delete'
      );
    ''');
  }
}
