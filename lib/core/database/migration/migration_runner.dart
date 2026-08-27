import 'package:ritmo/core/database/migration/migration_interface.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:sqflite/sqflite.dart';

class MigrationRunner {
  /// لیست مهاجرت‌های دیتابیس (نسخه پایه: ۱)
  /// در آینده برای اضافه کردن تغییرات اسکیما، مهاجرت‌ها از نسخه ۲ به بعد در این لیست ثبت می‌شوند.
  static final List<Migration> _migrations = <Migration>[];

  static Future<void> _ensureSchemaMigrationsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS schema_migrations (
        version INTEGER PRIMARY KEY,
        appliedAt INTEGER NOT NULL
      );
    ''');
  }

  static Future<void> run(Database db, int oldVersion, int newVersion) async {
    RitmoLog.info('MigrationRunner', 'Running migrations from v$oldVersion to v$newVersion');
    await _ensureSchemaMigrationsTable(db);

    final appliedRows = await db.query('schema_migrations');
    final appliedVersions = {
      for (final r in appliedRows) r['version'] as int,
    };

    final sorted = [..._migrations]..sort((a, b) => a.version.compareTo(b.version));

    final seen = <int>{};
    for (final m in sorted) {
      if (!seen.add(m.version)) {
        throw StateError('Duplicate migration version: ${m.version}');
      }
    }

    for (final migration in sorted) {
      if (migration.version > oldVersion && migration.version <= newVersion) {
        if (appliedVersions.contains(migration.version)) {
          RitmoLog.info(
            'MigrationRunner',
            'Skipping migration v${migration.version} (already recorded in schema_migrations)',
          );
          continue;
        }
        try {
          final nowMs = DateTime.now().millisecondsSinceEpoch;
          if (migration.requiresTransaction) {
            await db.transaction((txn) async {
              await migration.up(txn);
              await txn.insert('schema_migrations', {
                'version': migration.version,
                'appliedAt': nowMs,
              }, conflictAlgorithm: ConflictAlgorithm.replace);
            });
          } else {
            await migration.up(db);
            await db.insert('schema_migrations', {
              'version': migration.version,
              'appliedAt': nowMs,
              }, conflictAlgorithm: ConflictAlgorithm.replace);
          }
          RitmoLog.info('MigrationRunner', 'Successfully applied migration v${migration.version}');
        } catch (e, st) {
          RitmoLog.error('MigrationRunner', 'Failed to apply migration v${migration.version}', e, st);
          rethrow;
        }
      }
    }
  }
}
