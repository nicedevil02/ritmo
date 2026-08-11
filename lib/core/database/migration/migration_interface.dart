import 'package:sqflite/sqflite.dart';

abstract class Migration {
  int get version;
  bool get requiresTransaction => true;
  Future<void> up(covariant DatabaseExecutor db);
  Future<void> down(covariant DatabaseExecutor db);

  Future<void> safeAddColumn(DatabaseExecutor db, String table, String column, String typeDefinition) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final columnExists = columns.any((c) => c['name']?.toString().toLowerCase() == column.toLowerCase());
    if (!columnExists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $typeDefinition;');
    }
  }
}
