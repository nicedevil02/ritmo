import 'package:ritmo/core/database/migration/migration_interface.dart';
import 'package:sqflite/sqflite.dart';

/// مایگریشن ۱۱۹: تفکیک ریشه‌ای و کامل داده‌های کنکور از ماژول مطالعه عمومی
class MigrationV119KonkurStudyIsolation extends Migration {
  @override
  int get version => 119;

  @override
  Future<void> up(covariant DatabaseExecutor db) async {
    // ۱. تصحیح و ثبت منشا دروس پیش‌فرض کنکور
    await db.execute('''
      UPDATE konkur_subjects
      SET origin = 'KONKUR_PRESET'
      WHERE isPreset = 1 OR origin = 'KONKUR' OR origin = 'PRESET';
    ''');

    await db.execute('''
      UPDATE konkur_topics
      SET origin = 'KONKUR_PRESET'
      WHERE subjectId IN (
        SELECT id FROM konkur_subjects WHERE isPreset = 1 OR origin = 'KONKUR_PRESET'
      );
    ''');

    // ۲. تصحیح دروس ایجاد شده در محیط کنکور (دارای آزمون یا گروه تخصصی)
    await db.execute('''
      UPDATE konkur_subjects
      SET origin = 'KONKUR_CUSTOM'
      WHERE (origin = 'USER' OR origin IS NULL)
        AND (subjectGroup = 'SPECIALIZED' OR examQuestionCount > 0);
    ''');

    await db.execute('''
      UPDATE konkur_topics
      SET origin = 'KONKUR_CUSTOM'
      WHERE subjectId IN (
        SELECT id FROM konkur_subjects WHERE origin = 'KONKUR_CUSTOM'
      );
    ''');

    // ۳. تضمین منشا دروس مطالعه عمومی کاربر
    await db.execute('''
      UPDATE konkur_subjects
      SET origin = 'USER'
      WHERE origin IS NULL
        OR (origin != 'KONKUR_PRESET' AND origin != 'KONKUR_CUSTOM' AND (isPreset IS NULL OR isPreset = 0));
    ''');

    await db.execute('''
      UPDATE konkur_topics
      SET origin = 'USER'
      WHERE subjectId IN (
        SELECT id FROM konkur_subjects WHERE origin = 'USER'
      );
    ''');
  }

  @override
  Future<void> down(covariant DatabaseExecutor db) async {}
}
