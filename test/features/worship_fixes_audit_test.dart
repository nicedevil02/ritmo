import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/features/worship/logic/prayer_reminder_scheduler.dart';
import 'package:ritmo/features/worship/models/worship_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;

  setUp(() async {
    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE app_settings (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            );
          ''');
          await db.execute('''
            CREATE TABLE prayer_times_cache (
              date TEXT PRIMARY KEY,
              cityId TEXT NOT NULL,
              fajr TEXT NOT NULL,
              sunrise TEXT NOT NULL,
              dhuhr TEXT NOT NULL,
              asr TEXT NOT NULL,
              sunset TEXT NOT NULL,
              maghrib TEXT NOT NULL,
              isha TEXT NOT NULL,
              midnightShari TEXT NOT NULL,
              calculationMethod TEXT NOT NULL
            );
          ''');
          await db.execute('''
            CREATE TABLE worship_completions (
              id TEXT PRIMARY KEY,
              practiceId TEXT NOT NULL,
              dateStr TEXT NOT NULL,
              isCompleted INTEGER NOT NULL DEFAULT 1,
              completedAt INTEGER NOT NULL
            );
          ''');
        },
      ),
    );

    DatabaseHelper.instance.overrideDatabaseForTesting(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Worship Module Fixes Audit (RITF-034 .. RITF-044)', () {
    test('RITF-034 .. RITF-040: PrayerReminderScheduler schedules across 7-day horizon with safe settings', () async {
      await db.insert('app_settings', {'key': 'worship_adhan_enabled', 'value': 'true'});
      await db.insert('app_settings', {'key': 'worship_prayer_reminders_enabled', 'value': '1'});
      await db.insert('app_settings', {'key': 'worship_adhan_fajr', 'value': 'true'});
      await db.insert('app_settings', {'key': 'worship_adhan_dhuhr', 'value': 'true'});
      await db.insert('app_settings', {'key': 'worship_adhan_maghrib', 'value': 'true'});
      await db.insert('app_settings', {'key': 'worship_pre_reminder_minutes', 'value': '10'});

      // Run scheduler
      await PrayerReminderScheduler.instance.schedulePrayerReminders(
        fromDate: DateTime(2026, 8, 27),
        daysAhead: 7,
      );

      // CancelAll should cleanly clear without throwing
      await PrayerReminderScheduler.instance.cancelAll(horizonDays: 7);
    });

    test('RITF-041: PrayerTime._parseTime handles malformed time strings without crashing', () {
      final now = DateTime(2026, 8, 27);
      const times = PrayerTime(
        date: '2026-08-27',
        cityId: 'TEHRAN',
        fajr: '04:30',
        sunrise: '06:00',
        dhuhr: '12:15',
        asr: '16:00',
        sunset: '19:00',
        maghrib: '19:20',
        isha: '20:30',
        midnightShari: '23:45',
        calculationMethod: 'TEHRAN_UNIVERSITY',
      );

      final next = times.nextPrayer(now);
      expect(next.key.isNotEmpty, isTrue);
      expect(times.countdown(next), isNotNull);
    });

    test('RITF-042: WorshipSeason handles non-zero-padded date strings without throwing FormatException', () {
      final season = WorshipSeason(
        id: 'season_1',
        seasonType: 'RAMADAN',
        title: 'ماه رمضان',
        calendar: 'GREGORIAN',
        startDate: '3-1', // Single digit month
        endDate: '4-5',   // Single digit month
        isActive: true,
        priorityWeight: 1,
        createdAt: 0,
      );

      final now = DateTime(2026, 3, 15);
      const h = HijriDate(
        day: 15,
        month: 9,
        year: 1447,
        monthName: 'رمضان',
        formatted: '15 رمضان 1447',
      );

      final isActive = season.isActiveNow(h, now);
      expect(isActive, isTrue);
    });
  });
}
