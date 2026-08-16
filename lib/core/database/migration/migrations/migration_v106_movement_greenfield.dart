import 'package:ritmo/core/database/migration/migration_interface.dart';
import 'package:ritmo/core/database/schema/tables/movement_tables.dart';
import 'package:sqflite/sqflite.dart';

/// مایگریشن نسخه ۱۰۶: ساخت جداول ۴گانه و داده‌های پایهٔ ماژول حرکت (Movement Greenfield)
class MigrationV106MovementGreenfield extends Migration {
  @override
  int get version => 106;

  @override
  bool get requiresTransaction => true;

  @override
  Future<void> up(DatabaseExecutor db) async {
    await MovementTables.create(db);
    await MovementTables.seedInitialData(db);
  }

  @override
  Future<void> down(DatabaseExecutor db) async {
    await db.execute('DROP TABLE IF EXISTS ${MovementTables.tableStrengthPrograms};');
    await db.execute('DROP TABLE IF EXISTS ${MovementTables.tableLiveSessions};');
    await db.execute('DROP TABLE IF EXISTS ${MovementTables.tableOccurrences};');
    await db.execute('DROP TABLE IF EXISTS ${MovementTables.tableActivityKinds};');
  }
}
