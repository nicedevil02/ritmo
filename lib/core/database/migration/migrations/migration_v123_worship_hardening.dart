import 'package:ritmo/core/database/migration/migration_interface.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:sqflite/sqflite.dart';

/// مایگریشن نسخهٔ ۱۲۳: مقاوم‌سازی ماژول عبادت، پشتیبانی از موقعیت جایگزین و اسکیما بدون DDL در زمان اجرا (C5, C6, H4, M8)
class MigrationV123WorshipHardening extends Migration {
  @override
  int get version => 123;

  @override
  Future<void> down(covariant DatabaseExecutor db) async {
    // Non-destructive down
  }

  @override
  Future<void> up(covariant DatabaseExecutor db) async {
    RitmoLog.info('MigrationV123WorshipHardening', 'Starting worship hardening migration v123...');

    // 1. Ensure isFallbackLocation column exists in prayer_times_cache
    try {
      final info = await db.rawQuery('PRAGMA table_info(prayer_times_cache)');
      final hasFallback = info.any((c) => c['name'] == 'isFallbackLocation');
      if (!hasFallback) {
        await db.execute('ALTER TABLE prayer_times_cache ADD COLUMN isFallbackLocation INTEGER NOT NULL DEFAULT 0;');
      }
    } catch (e) {
      RitmoLog.warning('MigrationV123WorshipHardening', 'Error adding isFallbackLocation to prayer_times_cache: ');
    }

    // 2. Ensure worship_day_context table and exemptPrayers column exist
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS worship_day_context (
          date TEXT PRIMARY KEY,
          isTraveller INTEGER NOT NULL DEFAULT 0,
          fastingExempt INTEGER NOT NULL DEFAULT 0,
          prayerExempt INTEGER NOT NULL DEFAULT 0,
          exemptPrayers TEXT,
          reason TEXT,
          createdAt TEXT NOT NULL,
          updatedAt TEXT NOT NULL
        );
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_worship_day_context_date ON worship_day_context(date);');

      final ctxInfo = await db.rawQuery('PRAGMA table_info(worship_day_context)');
      final hasExemptPrayers = ctxInfo.any((c) => c['name'] == 'exemptPrayers');
      if (!hasExemptPrayers) {
        await db.execute('ALTER TABLE worship_day_context ADD COLUMN exemptPrayers TEXT;');
      }
    } catch (e) {
      RitmoLog.warning('MigrationV123WorshipHardening', 'Error ensuring worship_day_context: ');
    }

    // 3. Invalidate stale prayer times cache to guarantee consistent calculation methods
    try {
      await db.delete('prayer_times_cache');
    } catch (_) {}

    RitmoLog.info('MigrationV123WorshipHardening', 'Migration v123 completed successfully.');
  }
}
