import 'package:ritmo/core/database/migration/migration_interface.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:sqflite/sqflite.dart';

/// مایگریشن نسخهٔ ۱۲۲: مقاوم‌سازی دوره‌های آموزشی و نگهداری اسنپ‌شات‌های موتور تطبیقی (H3, N1, N2, N3)
class MigrationV122CoursesHardening extends Migration {
  @override
  int get version => 122;

  @override
  Future<void> down(covariant DatabaseExecutor db) async {
    // Non-destructive down
  }

  @override
  Future<void> up(covariant DatabaseExecutor db) async {
    RitmoLog.info('MigrationV122CoursesHardening', 'Starting courses hardening migration v122...');

    // 1. Create course_adaptive_snapshots table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS course_adaptive_snapshots (
          id TEXT PRIMARY KEY,
          courseId TEXT NOT NULL,
          oldWeeklyTarget INTEGER NOT NULL,
          newWeeklyTarget INTEGER NOT NULL,
          snapshotJson TEXT NOT NULL,
          createdAt INTEGER NOT NULL,
          FOREIGN KEY(courseId) REFERENCES courses(id) ON DELETE CASCADE
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_course_adaptive_snapshots_courseId ON course_adaptive_snapshots(courseId);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_course_adaptive_snapshots_createdAt ON course_adaptive_snapshots(createdAt);');

    RitmoLog.info('MigrationV122CoursesHardening', 'Migration v122 completed successfully.');
  }
}
