import 'package:ritmo/core/database/migration/migration_interface.dart';
import 'package:sqflite/sqflite.dart';

/// مایگریشن ۱۲۰: ایجاد جدول ددلاین‌ها، امتحانات و تکالیف مطالعه و فیلدهای کمکی پومودورو
class MigrationV120StudyDeadlinesAndPomodoro extends Migration {
  @override
  int get version => 120;

  @override
  Future<void> up(covariant DatabaseExecutor db) async {
    // ۱. ایجاد جدول امتحانات، تکالیف و ددلاین‌های درسی
    await db.execute('''
      CREATE TABLE IF NOT EXISTS study_deadlines (
        id TEXT PRIMARY KEY,
        subjectId TEXT,
        title TEXT NOT NULL,
        deadlineType TEXT NOT NULL DEFAULT 'EXAM',
        dueDateIso TEXT NOT NULL,
        dueTime TEXT,
        priority TEXT NOT NULL DEFAULT 'MEDIUM',
        isCompleted INTEGER NOT NULL DEFAULT 0,
        weight REAL DEFAULT 1.0,
        note TEXT,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        FOREIGN KEY(subjectId) REFERENCES konkur_subjects(id) ON DELETE SET NULL
      );
    ''');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_study_deadlines_due ON study_deadlines(dueDateIso, isCompleted);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_study_deadlines_subject ON study_deadlines(subjectId);');

    // ۲. افزودن ستون‌های پایدارسازی پومودورو به جدول جلسه فعال
    await safeAddColumn(db, 'study_active_session', 'pomodoroPhase', "TEXT DEFAULT 'FOCUS'");
    await safeAddColumn(db, 'study_active_session', 'pomodoroCycle', 'INTEGER DEFAULT 1');
    await safeAddColumn(db, 'study_active_session', 'targetSeconds', 'INTEGER DEFAULT 1500');
  }

  @override
  Future<void> down(covariant DatabaseExecutor db) async {}
}
