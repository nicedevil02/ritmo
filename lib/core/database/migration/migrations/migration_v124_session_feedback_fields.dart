import 'package:ritmo/core/database/migration/migration_interface.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:sqflite/sqflite.dart';

/// مایگریشن نسخهٔ ۱۲۴: افزودن ستون‌های بازخورد جلسه (overallFeeling و note) به جدول movement_sessions
class MigrationV124SessionFeedbackFields extends Migration {
  @override
  int get version => 124;

  @override
  Future<void> down(covariant DatabaseExecutor db) async {
    // Non-destructive down
  }

  @override
  Future<void> up(covariant DatabaseExecutor db) async {
    RitmoLog.info('MigrationV124SessionFeedbackFields', 'Starting session feedback fields migration v124...');

    try {
      final info = await db.rawQuery('PRAGMA table_info(movement_sessions)');
      final hasOverallFeeling = info.any((c) => c['name'] == 'overallFeeling');
      if (!hasOverallFeeling) {
        await db.execute('ALTER TABLE movement_sessions ADD COLUMN overallFeeling INTEGER;');
      }

      final hasNote = info.any((c) => c['name'] == 'note');
      if (!hasNote) {
        await db.execute('ALTER TABLE movement_sessions ADD COLUMN note TEXT;');
      }

      // Normalize existing kindCode values to UPPERCASE
      await db.execute('UPDATE movement_sessions SET kindCode = UPPER(kindCode) WHERE kindCode IS NOT NULL;');
      try {
        await db.execute('UPDATE ss_session_prescription SET kindCode = UPPER(kindCode) WHERE kindCode IS NOT NULL;');
      } catch (_) {}
    } catch (e) {
      RitmoLog.warning('MigrationV124SessionFeedbackFields', 'Error applying migration v124: $e');
    }

    RitmoLog.info('MigrationV124SessionFeedbackFields', 'Migration v124 completed successfully.');
  }
}
