import 'package:ritmo/core/database/migration/migration_interface.dart';
import 'package:sqflite/sqflite.dart';

class MigrationV114CycleFertilityCleanup extends Migration {
  @override
  int get version => 114;

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.rawDelete(
      "DELETE FROM app_settings WHERE key = 'cycle_fertility_visible';",
    );
  }

  @override
  Future<void> down(DatabaseExecutor db) async {}
}
