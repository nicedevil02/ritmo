import 'package:ritmo/core/database/migration/migration_interface.dart';
import 'package:sqflite/sqflite.dart';

/// مایگریشن ۱۱۱: بک‌فیل شناسایی قطعی دارو (Phase 0)
///
/// تمام ردیف‌های جدول routines که با منطق قدیمی دارو بوده‌اند ولی itemType آن‌ها
/// 'MEDICINE' نبوده است، به 'MEDICINE' به‌روزرسانی می‌شوند.
class MigrationV111MedicationIdentityBackfill extends Migration {
  @override
  int get version => 111;

  @override
  Future<void> up(covariant DatabaseExecutor db) async {
    // Decision (Clinical & Data Integrity):
    // Backfill legacy medication rows to explicit itemType = 'MEDICINE'
    // while protecting non-medication planner items (EVENT, TASK, REMINDER, REFLECT).
    await db.execute('''
      UPDATE routines
      SET itemType = 'MEDICINE'
      WHERE (itemType != 'MEDICINE' OR itemType IS NULL)
        AND (
          id LIKE 'routine_med_%'
          OR (
            COALESCE(itemType, '') NOT IN ('EVENT', 'TASK', 'REMINDER', 'REFLECT')
            AND (
              COALESCE(medStockCount, 0) > 0
              OR COALESCE(medRefillThreshold, 0) > 0
              OR COALESCE(minIntervalHours, 0) > 0
              OR COALESCE(maxDosesPerDay, 0) > 0
            )
          )
        );
    ''');
  }

  @override
  Future<void> down(covariant DatabaseExecutor db) async {
    // Additive non-destructive migration
  }
}
