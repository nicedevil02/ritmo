import 'package:ritmo/core/database/migration/migration_interface.dart';
import 'package:sqflite/sqflite.dart';

/// مایگریشن ۱۱۲: ایجاد جدول پروفایل دارویی واقعی و بک‌فیل داروهای موجود (Phase 1)
class MigrationV112MedicationProfiles extends Migration {
  @override
  int get version => 112;

  @override
  Future<void> up(covariant DatabaseExecutor db) async {
    // ۱. ایجاد جدول medication_profiles
    await db.execute('''
      CREATE TABLE IF NOT EXISTS medication_profiles (
        routineId TEXT PRIMARY KEY,
        form TEXT NOT NULL,
        route TEXT,
        doseAmount REAL,
        doseUnit TEXT,
        strength TEXT,
        activeIngredient TEXT,
        foodRelation TEXT,
        startDate INTEGER,
        endDate INTEGER,
        isChronic INTEGER NOT NULL DEFAULT 0,
        durationDays INTEGER,
        prescriberName TEXT,
        instructions TEXT,
        criticality TEXT,
        packageSize REAL,
        packageUnit TEXT,
        remainingAmount REAL,
        refillThresholdAmount REAL,
        injectionSites TEXT,
        lastInjectionSite TEXT,
        needsSiteRotation INTEGER DEFAULT 0,
        FOREIGN KEY(routineId) REFERENCES routines(id) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_medication_profiles_routineId
        ON medication_profiles(routineId);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_medication_profiles_form
        ON medication_profiles(form);
    ''');

    // ۲. بک‌فیل تمام داروهای موجود
    // Decision (Clinical Backfill):
    // Map legacy routine row stock & description into medication profile with default oral tablet form.
    await db.execute('''
      INSERT OR IGNORE INTO medication_profiles (
        routineId,
        form,
        route,
        doseAmount,
        doseUnit,
        instructions,
        isChronic,
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
        medRefillThreshold,
        createdAt
      FROM routines
      WHERE itemType = 'MEDICINE';
    ''');
  }

  @override
  Future<void> down(covariant DatabaseExecutor db) async {
    await db.execute('DROP TABLE IF EXISTS medication_profiles;');
  }
}
