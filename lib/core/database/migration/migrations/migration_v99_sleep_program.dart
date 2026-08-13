import 'package:ritmo/core/database/migration/migration_interface.dart';
import 'package:ritmo/core/database/schema/tables/sleep_tables.dart';
import 'package:sqflite/sqflite.dart';

/// قدم ۲ سند «مسیر خواب»: جداول sleep_programs و sleep_plan_days.
class MigrationV99SleepProgram extends Migration {
  @override
  int get version => 99;

  @override
  Future<void> up(DatabaseExecutor db) async {
    await SleepTables.ensureSchema(db);
  }

  @override
  Future<void> down(DatabaseExecutor db) async {}
}
