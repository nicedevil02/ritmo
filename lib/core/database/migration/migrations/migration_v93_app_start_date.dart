import 'package:sqflite/sqflite.dart';
import 'package:ritmo/core/database/migration/migration_interface.dart';

class MigrationV93AppStartDate extends Migration {
  @override
  int get version => 93;

  @override
  bool get requiresTransaction => true;

  @override
  Future<void> up(DatabaseExecutor db) async {
    final rows = await db.query('app_settings', where: "key = 'app_start_date'");
    if (rows.isEmpty) {
      await db.insert('app_settings', {
        'key': 'app_start_date',
        'value': DateTime.now().toIso8601String().substring(0, 10),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  @override
  Future<void> down(DatabaseExecutor db) async {
    // No down migration needed for this.
  }
}
