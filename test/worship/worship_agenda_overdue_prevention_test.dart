import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_snapshot_builder.dart';
import 'package:ritmo/core/domain/agenda/models/day_agenda_snapshot.dart';
import 'package:ritmo/core/domain/agenda/sources/agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/worship_agenda_source.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/services/end_of_day_sweep.dart';
import 'package:ritmo/features/calendar/presentation/logic/agenda_bucketing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE app_settings (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL,
              updatedAt INTEGER NOT NULL
            );
          ''');
          await db.execute('''
            CREATE TABLE worship_practices (
              id TEXT PRIMARY KEY,
              practiceType TEXT NOT NULL,
              subType TEXT,
              title TEXT NOT NULL,
              dailyTarget INTEGER NOT NULL DEFAULT 1,
              dailyDone INTEGER NOT NULL DEFAULT 0,
              reminderEnabled INTEGER DEFAULT 1,
              reminderOffsetMinutes INTEGER DEFAULT 10,
              reminderFrequency TEXT DEFAULT 'DAILY',
              reminderDaysOfWeek TEXT,
              reminderAnchor TEXT DEFAULT 'NONE',
              reminderTimes TEXT,
              reminderTime TEXT,
              showInCalendar INTEGER DEFAULT 0,
              sortOrder INTEGER DEFAULT 1,
              isActive INTEGER NOT NULL DEFAULT 1,
              userDisabledAt INTEGER,
              dailyDoneDate TEXT,
              createdAt INTEGER NOT NULL,
              updatedAt INTEGER NOT NULL
            );
          ''');
          await db.execute('''
            CREATE TABLE worship_completions (
              id TEXT PRIMARY KEY,
              practiceId TEXT NOT NULL,
              dateStr TEXT NOT NULL,
              practiceType TEXT NOT NULL,
              resultType TEXT NOT NULL,
              countDone INTEGER NOT NULL DEFAULT 1,
              countTarget INTEGER,
              quality TEXT,
              reason TEXT,
              loggedAt INTEGER NOT NULL,
              createdAt INTEGER NOT NULL
            );
          ''');
          await db.execute('''
            CREATE TABLE worship_debts (
              id TEXT PRIMARY KEY,
              debtType TEXT NOT NULL,
              sourcePracticeId TEXT,
              title TEXT NOT NULL,
              totalCount INTEGER NOT NULL DEFAULT 1,
              remainingCount INTEGER NOT NULL DEFAULT 1,
              dailyTarget INTEGER NOT NULL DEFAULT 1,
              autoCreated INTEGER NOT NULL DEFAULT 1,
              isArchived INTEGER NOT NULL DEFAULT 0,
              createdAt INTEGER NOT NULL,
              updatedAt INTEGER NOT NULL
            );
          ''');
          await db.execute('''
            CREATE TABLE worship_day_contexts (
              date TEXT PRIMARY KEY,
              isTraveller INTEGER DEFAULT 0,
              fastingExempt INTEGER DEFAULT 0,
              prayerExempt INTEGER DEFAULT 0,
              exemptPrayers TEXT,
              reason TEXT,
              createdAt TEXT NOT NULL,
              updatedAt TEXT NOT NULL
            );
          ''');
          await db.execute('''
            CREATE TABLE routine_occurrences (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              routine_id TEXT NOT NULL,
              date TEXT NOT NULL,
              scheduled_time TEXT,
              status TEXT NOT NULL DEFAULT 'pending'
            );
          ''');
          await db.execute('''
            CREATE TABLE pending_reminders (
              id TEXT PRIMARY KEY,
              routineId TEXT,
              state TEXT
            );
          ''');
          await db.execute('''
            CREATE TABLE routines (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              isEssential INTEGER DEFAULT 0,
              category TEXT
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

  group('Worship Overdue Prevention Tests', () {
    test('1. WorshipAgendaSource returns empty for dates before app_start_date', () async {
      final now = DateTime(2026, 8, 22, 10, 0);
      const todayStr = '2026-08-22';
      const pastDateStr = '2026-08-15';
      final pastDate = DateTime(2026, 8, 15);

      final settings = {
        'module_religion_enabled': 'true',
        'app_start_date': todayStr,
      };

      final source = WorshipAgendaSource(
        prayerPractices: [
          {
            'id': 'wp_fajr',
            'practiceType': 'PRAYER',
            'subType': 'FAJR',
            'title': 'نماز صبح',
            'dailyTarget': 1,
            'isActive': 1,
            'createdAt': now.millisecondsSinceEpoch,
          },
        ],
        mustahabPractices: [],
        worshipDebts: [],
        settingsMap: settings,
        religionEnabled: true,
        cachedHijriDates: {},
        statusesByDate: {},
        contextsByDate: {},
        hasLunarMonthly: false,
        db: db,
      );

      final pastCtx = AgendaDayContext(
        date: pastDate,
        dateStr: pastDateStr,
        isToday: false,
        prayerTimes: {'fajr': '05:00', 'sunrise': '06:30'},
        options: const AgendaQueryOptions(),
      );

      final items = source.itemsForDate(pastCtx);
      expect(items, isEmpty, reason: 'Must not emit prayer items for days before app_start_date');
    });

    test('2. AgendaBucketing does not place uncompleted past prayers in overdue bucket', () {
      final today = DateTime(2026, 8, 22, 10, 0);
      const yesterdayStr = '2026-08-21';

      final prayerItem = AgendaItem(
        id: 'prayer:wp_fajr:2026-08-21',
        domain: AgendaDomain.prayer,
        sourceId: 'wp_fajr',
        title: 'نماز صبح',
        dateStr: yesterdayStr,
        category: Category.religious,
        completion: AgendaCompletion.pending,
        priority: 3,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.prayer, targetId: 'wp_fajr'),
      );

      final taskItem = AgendaItem(
        id: 'task:task_1:2026-08-21',
        domain: AgendaDomain.task,
        sourceId: 'task_1',
        title: 'خرید لوازم',
        dateStr: yesterdayStr,
        category: Category.personal,
        completion: AgendaCompletion.pending,
        priority: 1,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.task, targetId: 'task_1'),
      );

      const builder = DayAgendaSnapshotBuilder();
      final dayAgenda = DayAgenda(
        dateStr: yesterdayStr,
        items: [prayerItem, taskItem],
      );
      final snapshot = builder.buildSnapshot(dayAgenda);

      final Map<String, DayAgendaSnapshot> snapshots = {
        yesterdayStr: snapshot,
      };

      final buckets = bucketRange(snapshots, now: today);

      expect(buckets[AgendaBucket.overdue]?.length, equals(1),
          reason: 'Only task item should be overdue, not prayer');
      expect(buckets[AgendaBucket.overdue]?.first.id, equals(taskItem.id));
    });

    test('3. EndOfDaySweep does not create Qada when module_religion_enabled is disabled', () async {
      await db.insert('app_settings', {
        'key': 'module_religion_enabled',
        'value': 'false',
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      await db.insert('worship_practices', {
        'id': 'wp_fajr',
        'practiceType': 'PRAYER',
        'subType': 'FAJR',
        'title': 'نماز صبح',
        'dailyTarget': 1,
        'dailyDone': 0,
        'isActive': 1,
        'createdAt': DateTime(2026, 8, 20).millisecondsSinceEpoch,
        'updatedAt': DateTime(2026, 8, 20).millisecondsSinceEpoch,
      });

      await EndOfDaySweep.runSweep(db, now: DateTime(2026, 8, 22));
      final debts = await db.query('worship_debts');
      expect(debts, isEmpty, reason: 'No worship debts should be created when module is disabled');
    });
  });
}
