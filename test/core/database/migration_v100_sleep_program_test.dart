import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/migration/migrations/migration_v100_sleep_program.dart';
import 'package:ritmo/features/sleep/data/sleep_program_repository.dart';
import 'package:ritmo/features/sleep/models/sleep_program.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  var ffiAvailable = false;

  setUpAll(() {
    try {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      ffiAvailable = true;
    } catch (_) {
      ffiAvailable = false;
    }
  });

  /// دیتابیس in-memory با دو پیش‌نیاز واقعی اپ: app_settings و bedtime_diagnostics.
  Future<Database> migratedDb() async {
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
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

  test('v100 version is 100', () {
    final migration = MigrationV100SleepProgram();
    expect(migration.version, equals(100));
  });

  test('v100 creates sleep program tables and is idempotent', () async {
    if (!ffiAvailable) return;

    final migration = MigrationV100SleepProgram();
    expect(migration.version, equals(100));

    final db = await migratedDb();
    // self-healing: اجرای دوم هم باید بدون خطا باشد
    await migration.up(db);

    final tables = (await db
            .rawQuery("SELECT name FROM sqlite_master WHERE type='table';"))
        .map((t) => t['name'] as String)
        .toSet();

    expect(tables.contains('sleep_programs'), isTrue);
    expect(tables.contains('sleep_plan_days'), isTrue);
    await db.close();
  });

  test('v100 creates program and reads existing sleep target if present',
      () async {
    if (!ffiAvailable) return;

    final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute(
        'CREATE TABLE app_settings (key TEXT PRIMARY KEY, value TEXT, updatedAt INTEGER);');
    await db.execute(
        "INSERT INTO app_settings (key, value, updatedAt) VALUES ('sleep_target_bedtime', '23:30', 1);");
    await db.execute(
        "INSERT INTO app_settings (key, value, updatedAt) VALUES ('sleep_target_wake', '07:00', 1);");
    await db.execute(
        "INSERT INTO app_settings (key, value, updatedAt) VALUES ('sleep_target_duration_minutes', '450', 1);");
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

    final repo = SleepProgramRepository(db);
    final program = await repo.ensureProgram();
    final target = await repo.loadTarget();

    expect(target.bedtimeHour * 60 + target.bedtimeMinute, equals(23 * 60 + 30));
    expect(target.wakeHour * 60 + target.wakeMinute, equals(7 * 60));
    expect(target.durationMinutes, equals(450));
    expect(program.stepMinutes, equals(15));
    expect(program.status, equals(SleepProgramStatus.listening));
    await db.close();
  });

  test('v100 creates listening program if app_settings is empty', () async {
    if (!ffiAvailable) return;

    final db = await migratedDb();
    final repo = SleepProgramRepository(db);
    final program = await repo.ensureProgram();

    expect(program.stepMinutes, equals(15));
    expect(program.status, equals(SleepProgramStatus.listening));
    await db.close();
  });
}
