import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/features/routines/domain/strategies/planner_save_context.dart';
import 'package:ritmo/features/routines/domain/strategies/reflection_strategy.dart';
import 'package:ritmo/features/routines/domain/strategies/task_strategy.dart';
import 'package:ritmo/features/routines/presentation/quick_add_parser.dart';
import 'package:ritmo/features/routines/shared/routine_category_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakeBuildContext extends Fake implements BuildContext {}

PlannerSaveContext createFakeContext({
  String title = 'کار تستی',
  String description = 'توضیحات تستی',
  String itemType = 'TASK',
  double priority = 2.0,
}) {
  return PlannerSaveContext(
    title: title,
    description: description,
    notes: '',
    selectedDate: DateTime(2026, 8, 27),
    selectedTime: const TimeOfDay(hour: 14, minute: 30),
    isEditing: false,
    routineToEdit: null,
    selectedCategory: Category.work,
    itemType: itemType,
    recurrenceType: 'EVERY_DAY',
    targetDuration: 45,
    reminderOffsetMinutes: 15,
    priority: priority,
    energyRule: 'ALWAYS',
    dependsOnRoutineId: null,
    selectedZoneId: null,
    worshipType: 'MUSTAHAB',
    worshipDebtType: 'PRAYER',
    worshipTotalCount: 10,
    worshipDailyTarget: 1,
    worshipReminderAnchor: 'NONE',
    worshipOffsetMinutes: 0,
    worshipSelectedDays: [6, 7, 1, 2, 3, 4, 5],
    worshipRepeatType: 'RECURRING',
    sportsOpType: 'ROUTINE',
    sportsType: 'STRENGTH',
    sportsDuration: 45,
    sportsIntensity: 'MEDIUM',
    sportsLocation: 'GYM',
    sportsFeeling: 'خوب',
    medicalMode: 'FIXED',
    medicalTimes: [const TimeOfDay(hour: 8, minute: 0)],
    medicalStockCount: 30,
    medicalRefillWarning: 5,
    medicalMinIntervalHours: 4,
    medicalMaxDosesPerDay: 4,
    courseType: 'VIDEO',
    courseTotalSessions: 10,
    courseWeeklyTarget: 3,
    courseSessionDuration: 45,
    coursePreferredDays: [6, 1, 3],
    coursePreferredTime: const TimeOfDay(hour: 18, minute: 0),
    goalType: 'DAILY',
    goalTargetDate: DateTime(2026, 9, 27),
    goalSteps: [''],
    reflectionMood: 4,
    reflectionWins: 'انجام کارها',
    reflectionGratitude: 'سلامتی',
    reflectionLearnings: 'تست‌نویسی',
    reflectionIsPrivate: false,
  );
}

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
            CREATE TABLE simple_tasks (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              note TEXT,
              isDone INTEGER NOT NULL DEFAULT 0,
              dueDate TEXT NOT NULL,
              dueTime TEXT,
              isImportant INTEGER NOT NULL DEFAULT 0,
              createdAt INTEGER NOT NULL,
              updatedAt INTEGER NOT NULL
            );
          ''');
          await db.execute('''
            CREATE TABLE daily_reflections (
              id TEXT PRIMARY KEY,
              date TEXT NOT NULL,
              mood_score INTEGER NOT NULL,
              reflection_text TEXT NOT NULL,
              learnings TEXT,
              gratitude TEXT,
              wins TEXT,
              challenges TEXT,
              tomorrowFocus TEXT,
              isPrivate INTEGER NOT NULL DEFAULT 0,
              createdAt INTEGER NOT NULL
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

  group('Routines Module Fixes Audit (RITF-049 .. RITF-056)', () {
    test('RITF-050 & RITF-051: RoutineCategoryHelper calculates streaks safely with malformed dates', () {
      final completions = [
        {'completionDate': '2026-08-27'},
        {'completionDate': 'invalid-date'},
        {'completionDate': '2026-08-26'},
        {'completionDate': '2026-08-25'},
      ];

      final streak = RoutineCategoryHelper.calculateStreak(completions);
      expect(streak, isNonNegative);
    });

    test('RITF-056: QuickAddParser parses abnormal and large numbers without throwing', () {
      final res1 = QuickAddParser.parse('هر 99999999999999999 روز مطالعه 99999999999999 دقیقه');
      expect(res1.title, isNotNull);
      expect(res1.targetDurationMinutes, isNotNull);
      expect(res1.intervalDays, isNotNull);

      final res2 = QuickAddParser.parse('ساعت 25:99 کار مهم');
      expect(res2.timeOfDay, isNotNull);
      expect(res2.timeOfDay!.hour, inInclusiveRange(0, 23));
      expect(res2.timeOfDay!.minute, inInclusiveRange(0, 59));
    });

    test('RITF-054: TaskStrategy and ReflectionStrategy update without ConflictAlgorithm.replace', () async {
      final fakeCtx = FakeBuildContext();
      final ctx = createFakeContext();

      const taskStrategy = TaskStrategy();
      await taskStrategy.save(ctx, fakeCtx);

      const refStrategy = ReflectionStrategy();
      await refStrategy.save(ctx, fakeCtx);

      final tasks = await db.query('simple_tasks');
      expect(tasks.length, 1);
      expect(tasks.first['title'], 'کار تستی');

      final reflections = await db.query('daily_reflections');
      expect(reflections.length, 1);
      expect(reflections.first['mood_score'], 4);
    });
  });
}
