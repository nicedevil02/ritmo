import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/schema/tables/sleep_tables.dart';
import 'package:ritmo/features/sleep/data/sleep_program_repository.dart';
import 'package:ritmo/features/sleep/models/sleep_plan_day.dart';
import 'package:ritmo/features/sleep/models/sleep_program.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late SleepProgramRepository repo;

  // پنجشنبه ۱۳ اوت ۲۰۲۶، ساعت ۲۱:۰۰
  final now = DateTime(2026, 8, 13, 21, 0);

  Future<void> insertNight(String date, int bedMin) async {
    final day = DateTime.parse(date);
    await db.insert('bedtime_diagnostics', {
      'date': date,
      'reason': 'مناسب',
      'createdAt': 0,
      'bedtimeAt': day.add(Duration(minutes: bedMin)).millisecondsSinceEpoch,
      'wakeAt':
          day.add(const Duration(days: 1, minutes: 420)).millisecondsSinceEpoch,
      'durationMinutes': 450,
      'quality': 4,
      'awakenings': 0,
    });
  }

  Future<void> insertPlan(
    String programId,
    String date,
    int plannedMin, {
    SleepPlanOutcome outcome = SleepPlanOutcome.pending,
  }) async {
    await db.insert('sleep_plan_days', {
      'programId': programId,
      'date': date,
      'plannedBedtimeMin': plannedMin,
      'plannedWakeMin': 420,
      'outcome': outcome.name,
    });
  }

  /// ۷ شب ثبت‌شده تا برنامه از فاز گوش دادن خارج شود.
  Future<void> insertSevenNights({int bedMin = 1410}) async {
    for (var i = 7; i >= 1; i--) {
      await insertNight('2026-08-${(13 - i).toString().padLeft(2, '0')}', bedMin);
    }
  }

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await SleepTables.ensureSchema(db);
    await db.execute(
        'CREATE TABLE app_settings (key TEXT PRIMARY KEY, value TEXT, updatedAt INTEGER)');
    await db.execute('''
      CREATE TABLE bedtime_diagnostics (
        date TEXT PRIMARY KEY,
        reason TEXT NOT NULL,
        note TEXT,
        createdAt INTEGER,
        bedtimeAt INTEGER,
        wakeAt INTEGER,
        durationMinutes INTEGER,
        quality INTEGER,
        awakenings INTEGER
      )
    ''');
    repo = SleepProgramRepository(db);
  });

  tearDown(() async => db.close());

  group('ساخت برنامه و هدف', () {
    test('ensureProgram یک‌بار می‌سازد و همان را برمی‌گرداند', () async {
      final a = await repo.ensureProgram();
      final b = await repo.ensureProgram();
      expect(a.id, b.id);
      expect(a.status, SleepProgramStatus.listening);
      final rows = await db.query('sleep_programs');
      expect(rows.length, 1);
    });

    test('loadTarget از app_settings می‌خواند و پیش‌فرض دارد', () async {
      expect((await repo.loadTarget()).bedtime, '23:30');
      await db.insert('app_settings',
          {'key': 'sleep_target_bedtime', 'value': '00:15', 'updatedAt': 0});
      expect((await repo.loadTarget()).bedtime, '00:15');
    });

    test('loadSleepLogs از bedtime_diagnostics می‌خواند، نه sleep_logs', () async {
      await insertSevenNights();
      final logs = await repo.loadSleepLogs();
      expect(logs.length, 7);
      expect(logs.first.date, '2026-08-12');
    });
  });

  group('فاز و فریز کردن پلهٔ امشب', () {
    test('کمتر از ۷ شب ⇒ listening و هیچ ردیفی فریز نمی‌شود', () async {
      await insertNight('2026-08-12', 1410);
      final state = await repo.refreshAndLoadState(now: now);
      expect(state.status, SleepProgramStatus.listening);
      expect(await db.query('sleep_plan_days'), isEmpty);
    });

    test('۷ شب ⇒ anchoring در دیتابیس ذخیره و پلهٔ امشب فریز می‌شود', () async {
      await insertSevenNights();
      final state = await repo.refreshAndLoadState(now: now);

      expect(state.status, SleepProgramStatus.anchoring);
      final program = await repo.currentProgram();
      expect(program!.status, SleepProgramStatus.anchoring);

      final rows = await db.query('sleep_plan_days');
      expect(rows.length, 1);
      expect(rows.first['date'], '2026-08-13');
      expect(rows.first['plannedBedtimeMin'], 1410);
      expect(rows.first['outcome'], 'pending');
    });

    test('پلهٔ فریزشده در فراخوانی دوم جابجا نمی‌شود', () async {
      await insertSevenNights();
      await repo.refreshAndLoadState(now: now);
      await db.update('sleep_plan_days', {'plannedBedtimeMin': 1395},
          where: 'date = ?', whereArgs: ['2026-08-13']);

      await repo.refreshAndLoadState(now: now.add(const Duration(hours: 2)));
      final rows = await db.query('sleep_plan_days');
      expect(rows.length, 1);
      expect(rows.first['plannedBedtimeMin'], 1395);
    });
  });

  group('تسویهٔ شب‌های گذشته', () {
    test('در تلورانس پله ⇒ hit و خارج آن ⇒ miss', () async {
      await insertSevenNights();
      final program = await repo.ensureProgram();
      await insertNight('2026-08-11', 1415); // ۵ دقیقه اختلاف
      await insertPlan(program.id, '2026-08-11', 1410);
      await insertPlan(program.id, '2026-08-12', 1300); // لاگ ۲۳:۳۰ دارد

      await repo.refreshAndLoadState(now: now);

      final rows = await db.query('sleep_plan_days', orderBy: 'date');
      expect(rows[0]['outcome'], 'hit');
      expect(rows[0]['actualBedtimeMin'], 1415);
      expect(rows[1]['outcome'], 'miss');
    });

    test('شب بدون لاگ ⇒ noData (نه miss)', () async {
      await insertSevenNights();
      final program = await repo.ensureProgram();
      await insertPlan(program.id, '2026-07-30', 1410);

      await repo.refreshAndLoadState(now: now);

      final rows = await db.query('sleep_plan_days',
          where: 'date = ?', whereArgs: ['2026-07-30']);
      expect(rows.first['outcome'], 'noData');
    });

    test('روز شبِ آزاد ⇒ freeNight حتی با لاگ دور از پله', () async {
      await insertSevenNights();
      final program = await repo.ensureProgram();
      await repo.setFreeNightWeekday(DateTime.wednesday); // ۱۲ اوت ۲۰۲۶
      await insertPlan(program.id, '2026-08-12', 1200);

      await repo.refreshAndLoadState(now: now);

      final rows = await db.query('sleep_plan_days',
          where: 'date = ?', whereArgs: ['2026-08-12']);
      expect(rows.first['outcome'], 'freeNight');
    });

    test('شبِ تسویه‌شده دوباره بازنویسی نمی‌شود', () async {
      await insertSevenNights();
      final program = await repo.ensureProgram();
      await insertPlan(program.id, '2026-08-11', 1410,
          outcome: SleepPlanOutcome.freeNight);
      await insertNight('2026-08-11', 1410);

      await repo.refreshAndLoadState(now: now);

      final rows = await db.query('sleep_plan_days',
          where: 'date = ?', whereArgs: ['2026-08-11']);
      expect(rows.first['outcome'], 'freeNight');
    });

    test('markTonightFreeNight امشب را از پایبندی خارج می‌کند', () async {
      await insertSevenNights();
      await repo.refreshAndLoadState(now: now);
      await repo.markTonightFreeNight(now: now);

      final rows = await db.query('sleep_plan_days',
          where: 'date = ?', whereArgs: ['2026-08-13']);
      expect(rows.first['outcome'], 'freeNight');
    });

    test('قبل از ظهر، شبِ در جریان هنوز تسویه نمی‌شود', () async {
      await insertSevenNights();
      final program = await repo.ensureProgram();
      await insertPlan(program.id, '2026-08-13', 1410);

      await repo.refreshAndLoadState(now: DateTime(2026, 8, 14, 2, 30));

      final rows = await db.query('sleep_plan_days',
          where: 'date = ?', whereArgs: ['2026-08-13']);
      expect(rows.first['outcome'], 'pending');
    });
  });
}
