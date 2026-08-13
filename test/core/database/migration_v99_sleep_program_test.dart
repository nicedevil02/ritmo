import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v100_sleep_program.dart';
import 'package:ritmo/features/sleep/data/sleep_program_repository.dart';
import 'package:ritmo/features/sleep/models/sleep_program.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  /// دیتابیس in-memory با دو پیش‌نیاز واقعی اپ: app_settings و bedtime_diagnostics.
  Future<Database> migratedDb() async {
    final db = await openDatabase(inMemoryDatabasePath);
    await db.execute(
        'CREATE TABLE app_settings (key TEXT PRIMARY KEY, value TEXT, updatedAt INTEGER);');
    await db.execute('''
      CREATE TABLE bedtime_diagnostics (
        date TEXT PRIMARY KEY,
        reason TEXT NOT NULL DEFAULT '',
        note TEXT,
        createdAt INTEGER NOT NULL DEFAULT 0,
        bedtimeAt INTEGER,
        wakeAt INTEGER,
        durationMinutes INTEGER,
        quality INTEGER NOT NULL DEFAULT 3,
        awakenings INTEGER NOT NULL DEFAULT 0
      );
    ''');
    await MigrationV100SleepProgram().up(db);
    return db;
  }

  test('v100 creates sleep program tables and is idempotent', () async {
    final migration = MigrationV100SleepProgram();
    expect(migration.version, equals(100));

    final db = await migratedDb();
    // self-healing: اجرای دوم هم باید بدون خطا باشد
    await migration.up(db);

    final tables = (await db
            .rawQuery("SELECT name FROM sqlite_master WHERE type='table';"))
        .map((t) => t['name'] as String)
        .toList();
    expect(tables, containsAll(<String>['sleep_programs', 'sleep_plan_days']));

    final indices = (await db
            .rawQuery("SELECT name FROM sqlite_master WHERE type='index';"))
        .map((i) => i['name'] as String)
        .toList();
    expect(indices,
        containsAll(<String>['idx_sleep_program_active', 'idx_plan_days_date']));

    await db.close();
  });

  test('only one active program is allowed (partial unique index)', () async {
    final db = await migratedDb();
    final now = DateTime.now().millisecondsSinceEpoch;

    Map<String, Object?> row(String id, String status) => {
          'id': id,
          'status': status,
          'createdAt': now,
          'updatedAt': now,
        };

    await db.insert('sleep_programs', row('a', 'active'));
    // دومین برنامهٔ active باید خطا بدهد
    await expectLater(
      db.insert('sleep_programs', row('b', 'active')),
      throwsA(isA<DatabaseException>()),
    );
    // ولی paused دوم مجاز است
    await db.insert('sleep_programs', row('c', 'paused'));

    await db.close();
  });

  test('listening advances to anchoring after 7 logged nights', () async {
    final db = await migratedDb();
    final repo = SleepProgramRepository(db);

    var program = await repo.ensureProgram();
    expect(program.status, SleepProgramStatus.listening);
    // idempotency: دوباره همان برنامه برمی‌گردد
    expect((await repo.ensureProgram()).id, program.id);

    for (var i = 1; i <= 6; i++) {
      await db.insert('bedtime_diagnostics',
          {'date': '2026-08-0$i', 'createdAt': 0, 'durationMinutes': 420});
    }
    program = await repo.refreshPhase();
    expect(program.status, SleepProgramStatus.listening);

    await db.insert('bedtime_diagnostics',
        {'date': '2026-08-07', 'createdAt': 0, 'durationMinutes': 420});
    program = await repo.refreshPhase();
    expect(program.status, SleepProgramStatus.anchoring);

    // anchoring دیگر به عقب برنمی‌گردد
    program = await repo.refreshPhase();
    expect(program.status, SleepProgramStatus.anchoring);

    await db.close();
  });
}
