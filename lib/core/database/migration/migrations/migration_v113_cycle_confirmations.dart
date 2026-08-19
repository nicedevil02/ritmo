import 'package:ritmo/core/database/migration/migration_interface.dart';
import 'package:sqflite/sqflite.dart';

/// مایگریشن ۱۱۳: ایجاد جدول تأییدهای چرخه و ثبت کلیدهای تنظیمات جدید
class MigrationV113CycleConfirmations extends Migration {
  @override
  int get version => 113;

  @override
  Future<void> up(covariant DatabaseExecutor db) async {
    // ۱. ایجاد جدول cycle_confirmations
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cycle_confirmations (
        id TEXT PRIMARY KEY,
        kind TEXT NOT NULL,
        targetDate TEXT NOT NULL,
        answer TEXT,
        answeredAt INTEGER,
        askCount INTEGER NOT NULL DEFAULT 0,
        lastAskedAt INTEGER,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_cycle_confirm_kind_date
        ON cycle_confirmations(kind, targetDate);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_cycle_confirm_answer
        ON cycle_confirmations(answer);
    ''');

    // ۲. ثبت کلیدهای جدید تنظیمات چرخه
    final now = DateTime.now().millisecondsSinceEpoch;
    final defaults = {
      'cycle_reminder_lead_days': '3,1',
      'cycle_reminder_hour': '10',
      'cycle_confirm_start_enabled': 'true',
      'cycle_confirm_end_enabled': 'true',
      'cycle_inbox_mask_enabled': 'true',
      'cycle_confirm_snooze_until': '',
      'cycle_biometric_enabled': 'false',
    };

    for (final entry in defaults.entries) {
      await db.insert('app_settings', {
        'key': entry.key,
        'value': entry.value,
        'updatedAt': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  @override
  Future<void> down(covariant DatabaseExecutor db) async {
    await db.execute('DROP TABLE IF EXISTS cycle_confirmations;');
  }
}
