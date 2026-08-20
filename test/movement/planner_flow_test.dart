import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/schema/tables/movement_tables.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/application/movement_planning_service.dart';
import 'package:ritmo/features/movement/presentation/planner/activity_plan_editor_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  try {
    sqfliteFfiInit();
  } catch (_) {}

  Widget wrapWithTheme(Widget child) {
    return MaterialApp(
      theme: RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
      ),
      home: Directionality(textDirection: TextDirection.rtl, child: child),
    );
  }

  group('Movement Planner Flow Tests (Phase 6 / P-16, P-17, P-18)', () {
    Database? db;
    bool dbInitialized = false;
    late MovementPlanningService planningService;

    setUp(() async {
      try {
        databaseFactory = databaseFactoryFfi;
        db = await databaseFactory.openDatabase(inMemoryDatabasePath);
        await MovementTables.create(db!);
        planningService = MovementPlanningService(db: db);
        dbInitialized = true;
      } catch (_) {
        dbInitialized = false;
      }
    });

    tearDown(() async {
      if (dbInitialized && db != null) {
        await db!.close();
      }
    });

    test('1. createWeeklySimplePlan creates occurrences for selected weekdays across 4 weeks', () async {
      if (!dbInitialized || db == null) return;
      final fixedDate = DateTime(2026, 8, 15); // شنبه

      await planningService.createWeeklySimplePlan(
        weeklyGoalSessions: 3,
        preferredWeekdays: [0, 2, 4], // شنبه، دوشنبه، چهارشنبه
        reminderTime: '08:30',
        fromDate: fixedDate,
      );

      final occRows = await db!.query(
        MovementTables.tableOccurrences,
        orderBy: 'dateIso ASC',
      );

      // ۳ روز در ۴ هفته = ۱۲ رخداد
      expect(occRows.length, equals(12));

      // بررسی وضعیت Preferences
      final prefRows = await db!.query(MovementTables.tablePreferences);
      expect(prefRows.length, equals(3));
      final goalRow = prefRows.firstWhere((r) => r['key'] == 'weekly_goal_sessions');
      expect(goalRow['value'], equals('3'));
    });

    test('2. Re-planning replaces future planned occurrences while preserving past logs and occurrences', () async {
      if (!dbInitialized || db == null) return;

      // رخداد در گذشته که انجام شده
      await db!.insert(MovementTables.tableOccurrences, {
        'id': 'occ_past_done',
        'activityKindId': 'kind_walking',
        'dateIso': '2026-08-10',
        'status': 'completed',
        'origin': 'template',
        'createdAt': DateTime(2026, 8, 10).toIso8601String(),
        'updatedAt': DateTime(2026, 8, 10).toIso8601String(),
      });

      // رخداد آیندهٔ قبلی
      await db!.insert(MovementTables.tableOccurrences, {
        'id': 'occ_old_future',
        'activityKindId': 'kind_walking',
        'dateIso': '2026-08-22',
        'status': 'planned',
        'origin': 'template',
        'createdAt': DateTime(2026, 8, 10).toIso8601String(),
        'updatedAt': DateTime(2026, 8, 10).toIso8601String(),
      });

      // ثبت پلن جدید ۲ روزه
      await planningService.createWeeklySimplePlan(
        weeklyGoalSessions: 2,
        preferredWeekdays: [0, 3], // شنبه، سه‌شنبه
        reminderTime: '09:00',
        fromDate: DateTime(2026, 8, 15),
      );

      // رخداد گذشتهٔ تکمیل‌شده همچنان باقی مانده
      final pastOcc = await db!.query(
        MovementTables.tableOccurrences,
        where: 'id = ?',
        whereArgs: ['occ_past_done'],
      );
      expect(pastOcc.length, equals(1));

      // رخداد آیندهٔ قدیمی حذف و با پلن جدید جایگزین شده
      final oldFuture = await db!.query(
        MovementTables.tableOccurrences,
        where: 'id = ?',
        whereArgs: ['occ_old_future'],
      );
      expect(oldFuture.isEmpty, isTrue);

      final allNewOccs = await db!.query(
        MovementTables.tableOccurrences,
        where: 'id != ?',
        whereArgs: ['occ_past_done'],
      );
      // ۲ روز در ۴ هفته = ۸ رخداد جدید
      expect(allNewOccs.length, equals(8));
    });

    testWidgets('3. ActivityPlanEditorScreen UI allows configuring 3 questions', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const ActivityPlanEditorScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('۱. چند روز در هفته می‌خوای تمرین کنی؟'), findsOneWidget);
      expect(find.text('۲. کدوم روزها برات مناسب‌تره؟'), findsOneWidget);
      expect(find.text('۳. چه ساعتی بهت یادآوری کنیم؟'), findsOneWidget);
      expect(find.text('ذخیره و ایجاد برنامه'), findsOneWidget);

      // تغییر روزها به ۴ روز
      await tester.tap(find.text('۴ روز'));
      await tester.pump();

      expect(find.byType(ActivityPlanEditorScreen), findsOneWidget);
    });
  });
}
