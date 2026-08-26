import 'package:ritmo/core/database/migration/migration_interface.dart';
import 'package:sqflite/sqflite.dart';

/// مایگریشن ۱۱۸: ارتقای یکپارچگی هویت دارو، بک‌فیل موجودی و ایندکس‌های بهینه
class MigrationV118MedicationIntegrityAndSafety extends Migration {
  @override
  int get version => 118;

  @override
  Future<void> up(covariant DatabaseExecutor db) async {
    // ۱. نرمال‌سازی ستون itemType فقط برای رکوردهای قطعی دارویی
    await db.execute('''
      UPDATE routines
      SET itemType = 'MEDICINE'
      WHERE (itemType IS NULL OR itemType = '' OR itemType = 'ROUTINE')
        AND (
          id LIKE 'routine_med_%'
          OR category = 'medical'
          OR category = 'health'
          OR id IN (SELECT routineId FROM medication_profiles)
        );
    ''');

    // ۱.۵. بازگردانی روتین‌های عادی که به اشتباه به دلیل minIntervalHours یا maxDosesPerDay دارو شده بودند
    await db.execute('''
      UPDATE routines
      SET itemType = 'ROUTINE'
      WHERE itemType = 'MEDICINE'
        AND id NOT LIKE 'routine_med_%'
        AND category != 'medical'
        AND category != 'health'
        AND id NOT IN (SELECT routineId FROM medication_profiles);
    ''');

    // ۲. بک‌فیل پروفایل دارویی برای رکوردهایی که احیاناً در مایگریشن ۱۱۲ جا مانده‌اند
    await db.execute('''
      INSERT OR IGNORE INTO medication_profiles (
        routineId,
        form,
        route,
        doseAmount,
        doseUnit,
        instructions,
        isChronic,
        packageSize,
        packageUnit,
        remainingAmount,
        refillThresholdAmount,
        startDate
      )
      SELECT 
        id,
        'TABLET',
        'ORAL',
        1.0,
        'TABLET',
        description,
        1,
        medStockCount,
        'TABLET',
        medStockCount,
        medRefillThreshold,
        createdAt
      FROM routines
      WHERE itemType = 'MEDICINE';
    ''');

    // ۳. بک‌فیل فیلد packageSize برای فعال‌سازی هشدارهای موجودی
    await db.execute('''
      UPDATE medication_profiles
      SET packageSize = COALESCE(packageSize, remainingAmount)
      WHERE packageSize IS NULL AND remainingAmount IS NOT NULL;
    ''');

    // ۴. ایجاد ایندکس مرکب برای بهینه‌سازی سرعت کوئری‌های تقویم و لاگ
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_medlog_routine_time
        ON medication_logs(routineId, scheduledTime, takenTime);
    ''');
  }

  @override
  Future<void> down(covariant DatabaseExecutor db) async {
    await db.execute('DROP INDEX IF EXISTS idx_medlog_routine_time;');
  }
}
