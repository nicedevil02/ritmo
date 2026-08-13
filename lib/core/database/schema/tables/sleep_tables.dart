import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

/// جداول برنامهٔ خواب — قدم ۲ سند «مسیر خواب».
///
/// - `sleep_programs`: در هر لحظه حداکثر یک برنامهٔ `active` (partial unique index).
/// - `sleep_plan_days`: یک ردیف به ازای هر شب؛ به‌جای سه فلگ هم‌پوشانِ نسخهٔ
///   اولیهٔ سند، یک ستون `outcome` با مقادیر بسته دارد.
///
/// نکتهٔ مهم دربارهٔ لاگ خواب: منبع واقعی دادهٔ ثبت‌شده در کد فعلی جدول
/// `bedtime_diagnostics` است. `sleep_logs` هیچ نویسنده‌ای در کد ندارد و فقط در
/// چند خوانندهٔ قدیمی (با catchError) query می‌شود؛ یکی‌سازیِ آن مسیر به
/// فاز A موکول شده است.
class SleepTables {
  static Future<void> create(DatabaseExecutor db) async {
    await ensureSchema(db);
  }

  /// Self-healing schema check for sleep program tables (idempotent).
  static Future<void> ensureSchema(DatabaseExecutor db) async {
    try {
      // 1. sleep_programs
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sleep_programs (
          id TEXT PRIMARY KEY,
          stepMinutes INTEGER NOT NULL DEFAULT 15,
          minNightsPerStep INTEGER NOT NULL DEFAULT 2,
          freeNightWeekday INTEGER,
          status TEXT NOT NULL DEFAULT 'listening',
          cycleSyncEnabled INTEGER NOT NULL DEFAULT 0,
          createdAt INTEGER NOT NULL,
          updatedAt INTEGER NOT NULL
        );
      ''');
      await db.execute('''
        CREATE UNIQUE INDEX IF NOT EXISTS idx_sleep_program_active
          ON sleep_programs(status) WHERE status = 'active';
      ''');

      // 2. sleep_plan_days — date هم‌کنوانسیون با لاگ خواب: dayKey روزی که شبش خوابیده‌ای
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sleep_plan_days (
          programId TEXT NOT NULL,
          date TEXT NOT NULL,
          plannedBedtimeMin INTEGER NOT NULL,
          plannedWakeMin INTEGER NOT NULL,
          actualBedtimeMin INTEGER,
          actualWakeMin INTEGER,
          outcome TEXT NOT NULL DEFAULT 'pending',
          PRIMARY KEY (programId, date),
          FOREIGN KEY(programId) REFERENCES sleep_programs(id) ON DELETE CASCADE
        );
      ''');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_plan_days_date ON sleep_plan_days(date);');
    } catch (e, st) {
      debugPrint('[SLEEP_TABLES] Error in ensureSchema: $e\n$st');
    }
  }
}
