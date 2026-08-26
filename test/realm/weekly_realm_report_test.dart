import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/realm/active_realm_resolver.dart';
import 'package:ritmo/features/today/presentation/widgets/dashboard/weekly_realm_report_card.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Weekly Realm Report (F-15) Domain & Repository Tests', () {
    late Database db;
    late ZoneReportRepository reportRepo;
    late ZoneBudgetRepository budgetRepo;

    setUp(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE zones (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              color TEXT NOT NULL,
              icon TEXT NOT NULL,
              mode TEXT NOT NULL DEFAULT 'NORMAL',
              isDefault INTEGER NOT NULL DEFAULT 0,
              createdAt INTEGER NOT NULL,
              updatedAt INTEGER NOT NULL
            );
          ''');
          await db.execute('''
            CREATE TABLE zone_sessions (
              id TEXT PRIMARY KEY,
              zoneId TEXT NOT NULL,
              startedAt INTEGER NOT NULL,
              plannedEndAt INTEGER,
              endedAt INTEGER,
              completionReason TEXT NOT NULL DEFAULT 'NORMAL',
              createdAt INTEGER NOT NULL,
              updatedAt INTEGER NOT NULL,
              FOREIGN KEY(zoneId) REFERENCES zones(id) ON DELETE CASCADE
            );
          ''');
          await db.execute('''
            CREATE TABLE zone_budgets (
              zoneId TEXT PRIMARY KEY,
              minMinutes INTEGER,
              maxMinutes INTEGER,
              period TEXT NOT NULL DEFAULT 'WEEK',
              updatedAt INTEGER NOT NULL,
              FOREIGN KEY(zoneId) REFERENCES zones(id) ON DELETE CASCADE
            );
          ''');
        },
      );

      budgetRepo = ZoneBudgetRepository();
      reportRepo = ZoneReportRepository(budgetRepo: budgetRepo);
    });

    tearDown(() async {
      await db.close();
    });

    test('1. Aggregates current week sessions, previous week comparison, and budgets', () async {
      final now = DateTime(2026, 8, 26, 12, 0);
      final currentWeekStart = now.subtract(const Duration(days: 7));
      final prevWeekStart = currentWeekStart.subtract(const Duration(days: 7));

      // Insert zones
      await db.insert('zones', {
        'id': 'work_zone',
        'name': 'کار و پروژه‌ها',
        'color': '#3B82F6',
        'icon': '💼',
        'createdAt': 1,
        'updatedAt': 1,
      });
      await db.insert('zones', {
        'id': 'family_zone',
        'name': 'خانواده',
        'color': '#10B981',
        'icon': '👨‍👩‍👧',
        'createdAt': 1,
        'updatedAt': 1,
      });

      // Insert budgets: Max 40h (2400 min) for work, Min 10h (600 min) for family
      await budgetRepo.saveBudget(
        const ZoneBudget(
          zoneId: 'work_zone',
          maxMinutes: 2400,
          period: 'WEEK',
        ),
        executor: db,
      );
      await budgetRepo.saveBudget(
        const ZoneBudget(
          zoneId: 'family_zone',
          minMinutes: 600,
          period: 'WEEK',
        ),
        executor: db,
      );

      // Previous week sessions:
      // Work: 30 hours (1800 min)
      await db.insert('zone_sessions', {
        'id': 's_prev_work',
        'zoneId': 'work_zone',
        'startedAt': prevWeekStart.add(const Duration(hours: 10)).millisecondsSinceEpoch,
        'endedAt': prevWeekStart.add(const Duration(hours: 40)).millisecondsSinceEpoch,
        'createdAt': 1,
        'updatedAt': 1,
      });

      // Current week sessions:
      // Work: 45 hours (2700 min) -> Exceeds max budget of 40h!
      await db.insert('zone_sessions', {
        'id': 's_curr_work',
        'zoneId': 'work_zone',
        'startedAt': currentWeekStart.add(const Duration(hours: 10)).millisecondsSinceEpoch,
        'endedAt': currentWeekStart.add(const Duration(hours: 55)).millisecondsSinceEpoch,
        'createdAt': 1,
        'updatedAt': 1,
      });
      // Family: 8 hours (480 min) -> 80% of min budget of 10h
      await db.insert('zone_sessions', {
        'id': 's_curr_family',
        'zoneId': 'family_zone',
        'startedAt': currentWeekStart.add(const Duration(hours: 60)).millisecondsSinceEpoch,
        'endedAt': currentWeekStart.add(const Duration(hours: 68)).millisecondsSinceEpoch,
        'createdAt': 1,
        'updatedAt': 1,
      });

      final report = await reportRepo.generateWeeklyReport(
        now: now,
        startRange: currentWeekStart,
        endRange: now,
        executor: db,
      );

      expect(report.items.length, 2);

      // Work zone assertions
      final workItem = report.items.firstWhere((i) => i.zoneId == 'work_zone');
      expect(workItem.totalMinutes, 2700);
      expect(workItem.previousWeekMinutes, 1800);
      expect(workItem.diffMinutesFromPreviousWeek, 900); // +15 hours
      expect(workItem.isMaxBudgetExceeded, isTrue); // Exceeded 2400 min

      // Family zone assertions
      final familyItem = report.items.firstWhere((i) => i.zoneId == 'family_zone');
      expect(familyItem.totalMinutes, 480);
      expect(familyItem.previousWeekMinutes, isNull);
      expect(familyItem.minBudgetProgress, closeTo(0.8, 0.01)); // 8h / 10h = 80%

      // Report overview
      expect(report.totalTrackedMinutes, 3180);
      expect(report.totalSessions, 2);
      expect(report.topRealm?.zoneId, 'work_zone');
    });
  });

  group('WeeklyRealmReportCard UI Widget Tests (F-15)', () {
    testWidgets('2. Renders weekly report card with distribution bar and budget indicators', (tester) async {
      final now = DateTime(2026, 8, 26, 12, 0);
      final report = WeeklyRealmReport(
        startRange: now.subtract(const Duration(days: 7)),
        endRange: now,
        items: const [
          ZoneReportItem(
            zoneId: 'work_zone',
            name: 'کار و پروژه‌ها',
            colorHex: '#3B82F6',
            icon: '💼',
            totalMinutes: 2700,
            sessionCount: 12,
            previousWeekMinutes: 1800,
            budget: ZoneBudget(
              zoneId: 'work_zone',
              maxMinutes: 2400,
              period: 'WEEK',
            ),
          ),
          ZoneReportItem(
            zoneId: 'family_zone',
            name: 'خانواده',
            colorHex: '#10B981',
            icon: '👨‍👩‍👧',
            totalMinutes: 480,
            sessionCount: 5,
            budget: ZoneBudget(
              zoneId: 'family_zone',
              minMinutes: 600,
              period: 'WEEK',
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: WeeklyRealmReportCard(report: report),
            ),
          ),
        ),
      );

      // Verify header texts
      expect(find.text('گزارش هفتگی قلمروها'), findsOneWidget);
      expect(find.text('کار و پروژه‌ها'), findsOneWidget);
      expect(find.text('خانواده'), findsOneWidget);

      // Verify badges
      expect(find.text('⚠️ فراتر از سقف (40س)'), findsOneWidget);
      expect(find.text('هدف 10س: 80٪'), findsOneWidget);
      expect(find.text('+15س و 0د نسبت به هفته قبل'), findsOneWidget);
    });
  });
}
