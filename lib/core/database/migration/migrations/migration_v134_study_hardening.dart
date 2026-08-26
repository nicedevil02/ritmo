import 'package:ritmo/core/database/migration/migration_interface.dart';
import 'package:sqflite/sqflite.dart';

/// مایگریشن ۱۳۴: افزودن ستون phaseAccumulatedSeconds به جدول study_active_session جهت حفظ زمان سپری شده فاز پومودورو هنگام Pause/Resume
class MigrationV134StudyHardening extends Migration {
  @override
  int get version => 134;

  @override
  Future<void> up(covariant DatabaseExecutor db) async {
    await safeAddColumn(db, 'study_active_session', 'phaseAccumulatedSeconds', 'INTEGER DEFAULT 0');
  }

  @override
  Future<void> down(covariant DatabaseExecutor db) async {}
}
