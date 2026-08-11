import 'package:ritmo/core/database/migration/migration_interface.dart';
import 'package:sqflite/sqflite.dart';

class MigrationV94 extends Migration {
  @override
  bool get requiresTransaction => false;

  @override
  int get version => 94;

  Future<bool> _columnExists(DatabaseExecutor db, String table, String column) async {
    try {
      final info = await db.rawQuery('PRAGMA table_info($table)');
      return info.any((row) => row['name'] == column);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> up(DatabaseExecutor db) async {
    // Adding sourcePracticeId to worship_debts for users who had their database created directly at V67 or later without it
    if (!await _columnExists(db, 'worship_debts', 'sourcePracticeId')) {
      await db.execute('ALTER TABLE worship_debts ADD COLUMN sourcePracticeId TEXT;');
    }
  }

  @override
  Future<void> down(DatabaseExecutor db) async {}
}
