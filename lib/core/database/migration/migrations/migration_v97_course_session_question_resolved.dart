import 'package:sqflite/sqflite.dart';
import 'package:ritmo/core/database/migration/migration_interface.dart';

/// Adds the `questionResolved` flag to course_sessions so that resolved
/// open-questions in the course detail debrief section persist across
/// app restarts (previously tracked only in memory).
class MigrationV97SessionQuestionResolved extends Migration {
  @override
  int get version => 97;

  @override
  bool get requiresTransaction => true;

  @override
  Future<void> up(DatabaseExecutor db) async {
    await safeAddColumn(db, 'course_sessions', 'questionResolved', 'INTEGER NOT NULL DEFAULT 0');
  }

  @override
  Future<void> down(DatabaseExecutor db) async {
    // SQLite cannot easily drop columns; no-op.
  }
}
