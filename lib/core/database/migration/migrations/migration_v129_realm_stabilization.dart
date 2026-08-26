import 'package:ritmo/core/database/migration/migration_interface.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:sqflite/sqflite.dart';

/// V129: پایدارسازی قلمرو — حذف منبع حقیقت دوم و افزودن کلیدهای override
class MigrationV129RealmStabilization extends Migration {
  @override
  int get version => 129;

  @override
  Future<void> up(DatabaseExecutor db) async {
    RitmoLog.info('MigrationV129', 'Starting Migration V129 Realm Stabilization...');
    final now = DateTime.now().millisecondsSinceEpoch;

    // ۱. حذف کلیدهای یتیم که هیچ‌جا نوشته نمی‌شدند (B-01, B-03)
    await db.delete(
      'app_settings',
      where: 'key IN (?, ?)',
      whereArgs: ['active_zone_id', 'active_zone_mode'],
    );

    // ۲. کلیدهای جدید override (B-07, B-08)
    for (final e in {
      'realm_override_started_ms': '0',
      'realm_quick_override_minutes': '50',
    }.entries) {
      await db.insert(
        'app_settings',
        {'key': e.key, 'value': e.value, 'updatedAt': now},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    // ۳. نرمال‌سازی mode های نامعتبر به NORMAL (B-02, B-03)
    await db.execute('''
      UPDATE zones SET mode = 'NORMAL'
       WHERE mode NOT IN ('NORMAL', 'FOCUS', 'SILENT', 'MUTE');
    ''');
    await db.execute("UPDATE zones SET mode = 'SILENT' WHERE mode = 'MUTE';");

    // ۴. حداکثر یک قلمرو پیش‌فرض (B-12)
    final defaults = await db.query('zones',
        where: 'isDefault = 1', orderBy: 'createdAt ASC');
    if (defaults.length > 1) {
      for (final row in defaults.skip(1)) {
        await db.update('zones', {'isDefault': 0},
            where: 'id = ?', whereArgs: [row['id']]);
      }
    }
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_zones_single_default
        ON zones(isDefault) WHERE isDefault = 1;
    ''');

    RitmoLog.info('MigrationV129', 'پایدارسازی قلمرو اعمال شد');
  }

  @override
  Future<void> down(DatabaseExecutor db) async {
    await db.execute('DROP INDEX IF EXISTS idx_zones_single_default;');
  }
}
