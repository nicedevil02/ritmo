import 'package:sqflite/sqflite.dart';
import 'package:ritmo/core/database/migration/migration_interface.dart';

/// Phase 2: Add nullable movementMuscleFocus to routines table.
class MigrationV99MovementMuscleFocus extends Migration {
  @override
  int get version => 99;

  @override
  bool get requiresTransaction => true;

  @override
  Future<void> up(DatabaseExecutor db) async {
    await safeAddColumn(db, 'routines', 'movementMuscleFocus', 'TEXT');
  }

  @override
  Future<void> down(DatabaseExecutor db) async {
    // SQLite doesn't easily drop columns without table rebuild; safe to keep as no-op.
  }
}
