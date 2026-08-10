import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/commands/catalog/planning_commands.dart';
import 'package:ritmo/core/domain/commands/ritmo_command.dart';
import 'package:ritmo/features/assistant/models/day_plan_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;

  setUp(() async {
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (d, v) async {
        await d.execute('''
          CREATE TABLE IF NOT EXISTS day_plan_commits (
            id TEXT PRIMARY KEY,
            commitDate TEXT,
            date_iso TEXT,
            plan_json TEXT,
            createdItemIds TEXT,
            createdAt INTEGER NOT NULL,
            created_at INTEGER NOT NULL DEFAULT 0,
            updatedAt INTEGER NOT NULL DEFAULT 0,
            updated_at INTEGER NOT NULL DEFAULT 0,
            groupId TEXT
          );
        ''');
        await d.execute('''
          CREATE TABLE IF NOT EXISTS routines (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            description TEXT,
            category TEXT,
            routineType TEXT,
            notificationLevel TEXT,
            isEssential INTEGER,
            isEssentialLocked INTEGER,
            energyRule TEXT,
            priority REAL,
            targetDurationMinutes INTEGER,
            lightDurationMinutes INTEGER,
            minimalDurationMinutes INTEGER,
            isArchived INTEGER,
            isPrivate INTEGER,
            displayOrder INTEGER,
            createdAt INTEGER,
            updatedAt INTEGER,
            itemType TEXT,
            reminderOffsetMinutes INTEGER
          );
        ''');
        await d.execute('''
          CREATE TABLE IF NOT EXISTS routine_schedules (
            id TEXT PRIMARY KEY,
            routineId TEXT,
            scheduleType TEXT,
            timeOfDay TEXT,
            daysOfWeek TEXT,
            recurrenceRule TEXT,
            createdAt INTEGER,
            updatedAt INTEGER
          );
        ''');
        await d.execute('''
          CREATE TABLE IF NOT EXISTS routine_occurrences (
            id TEXT PRIMARY KEY,
            routineId TEXT,
            targetDate TEXT,
            plannedTime TEXT,
            status TEXT,
            completedAt INTEGER,
            createdAt INTEGER,
            updatedAt INTEGER
          );
        ''');
        await d.execute('''
          CREATE TABLE IF NOT EXISTS worship_practices (
            id TEXT PRIMARY KEY,
            practiceType TEXT,
            subType TEXT,
            title TEXT,
            dailyTarget INTEGER,
            dailyDone INTEGER,
            reminderEnabled INTEGER,
            reminderTime TEXT,
            reminderFrequency TEXT,
            reminderAnchor TEXT,
            reminderOffsetMinutes INTEGER,
            reminderTimes TEXT,
            isActive INTEGER,
            notes TEXT,
            dailyDoneDate TEXT,
            createdAt INTEGER,
            updatedAt INTEGER
          );
        ''');
        await d.execute('''
          CREATE TABLE IF NOT EXISTS simple_tasks (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            note TEXT,
            isDone INTEGER NOT NULL DEFAULT 0,
            doneAt INTEGER,
            dueDate TEXT,
            dueTime TEXT,
            reminderAtMs INTEGER,
            reminderId TEXT,
            linkedRoutineId TEXT,
            orderIndex INTEGER NOT NULL DEFAULT 0,
            origin TEXT NOT NULL DEFAULT 'SIMPLE',
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL
          );
        ''');
        await d.execute('''
          CREATE TABLE IF NOT EXISTS app_settings (
            key TEXT PRIMARY KEY,
            value TEXT,
            updatedAt INTEGER
          );
        ''');
      },
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('Scenario 1: 7 valid drafts -> 7 commit records with one groupId -> undo reverts all', () async {
    final drafts = List.generate(7, (i) {
      final dateStr = '2026-08-0${i + 1}';
      return DayPlanDraft(
        planDate: dateStr,
        questions: const [],
        suggestions: const [],
        items: [
          DayPlanItemDraft(
            title: 'فعالیت $i',
            targetModule: 'work',
            startKind: 'clock',
            durationSource: 'user',
            category: 'work',
            recurrence: 'daily',
            durationMin: 30,
            resolvedTime: '08:00',
          ),
        ],
      );
    });

    const command = PlanningApplyWeekCommand();
    final ctx = AgentCommandContext(
      payload: {'drafts': drafts.map((d) => d.toJson()).toList()},
      source: CommandSource.user,
      personaId: 'goals',
      now: DateTime(2026, 8, 9),
      txn: db,
    );

    final result = await command.run(ctx);
    expect(result.success, isTrue);

    final commits = await db.query('day_plan_commits');
    expect(commits.length, equals(7));
    final groupId = result.inverseData!['groupId'] as String;
    expect(commits.every((c) => c['groupId'] == groupId), isTrue);

    // Perform Undo
    final undoResult = await command.undo(ctx, result.inverseData!);
    expect(undoResult?.success, isTrue);

    final commitsAfterUndo = await db.query('day_plan_commits');
    expect(commitsAfterUndo.isEmpty, isTrue);
  });

  test('Scenario 2: Transaction failure rolls back completely (0 commits remain)', () async {
    // Drop table to trigger db exception during loop
    await db.execute('DROP TABLE routines;');

    final drafts = List.generate(7, (i) {
      return DayPlanDraft(
        planDate: '2026-08-0${i + 1}',
        questions: const [],
        suggestions: const [],
        items: [
          DayPlanItemDraft(
            title: 'فعالیت $i',
            targetModule: 'work',
            startKind: 'clock',
            durationSource: 'user',
            category: 'work',
            recurrence: 'daily',
            durationMin: 30,
            resolvedTime: '08:00',
          ),
        ],
      );
    });

    const command = PlanningApplyWeekCommand();
    final ctx = AgentCommandContext(
      payload: {'drafts': drafts.map((d) => d.toJson()).toList()},
      source: CommandSource.user,
      personaId: 'goals',
      now: DateTime(2026, 8, 9),
      txn: db,
    );

    expect(() => command.run(ctx), throwsA(isA<Exception>()));

    final commitsAfterFail = await db.query('day_plan_commits');
    expect(commitsAfterFail.length, equals(0));
  });
}
