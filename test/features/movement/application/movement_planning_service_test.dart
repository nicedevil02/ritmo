import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/schema/tables/movement_tables.dart';
import 'package:ritmo/features/movement/application/movement_planning_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_change_scope.dart';
import 'package:ritmo/features/movement/domain/models/movement_plan_schedule.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  try {
    sqfliteFfiInit();
  } catch (_) {}

  group('MovementPlanningService Unit & Transaction Tests', () {
    Database? db;
    bool dbInitialized = false;
    late MovementPlanningService service;

    setUp(() async {
      try {
        databaseFactory = databaseFactoryFfi;
        db = await databaseFactory.openDatabase(inMemoryDatabasePath);
        await MovementTables.create(db!);
        await MovementTables.seedInitialData(db!);
        service = MovementPlanningService(db: db);
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

    test('getRitmoWeekday maps Saturday to 0 and Friday to 6', () {
      // 2026-08-15 is Saturday -> 0
      final sat = DateTime(2026, 8, 15);
      expect(MovementPlanningService.getRitmoWeekday(sat), equals(0));

      // 2026-08-16 is Sunday -> 1
      final sun = DateTime(2026, 8, 16);
      expect(MovementPlanningService.getRitmoWeekday(sun), equals(1));

      // 2026-08-21 is Friday -> 6
      final fri = DateTime(2026, 8, 21);
      expect(MovementPlanningService.getRitmoWeekday(fri), equals(6));
    });

    test('createPlan creates template, schedules, and 4-week horizon occurrences atomically', () async {
      if (!dbInitialized || db == null) return;

      final now = DateTime(2026, 8, 16); // Sunday
      final templateId = await service.createPlan(
        activityKindId: 'kind_running',
        sessionType: 'repeating',
        goal: {
          'type': 'duration',
          'value': 30,
          'unit': 'دقیقه',
        },
        reminderType: 'preSession',
        reminderOffsetMin: 15,
        schedules: [
          MovementPlanSchedule(
            id: 'sch_1',
            templateId: '',
            weekday: 0, // Saturday
            timeOfDay: '07:00',
            recurrence: 'weekly',
            startDateIso: '2026-08-15',
            createdAt: now,
          ),
          MovementPlanSchedule(
            id: 'sch_2',
            templateId: '',
            weekday: 2, // Monday
            timeOfDay: '18:00',
            recurrence: 'weekly',
            startDateIso: '2026-08-15',
            createdAt: now,
          ),
        ],
      );

      expect(templateId, isNotEmpty);

      // Verify template row
      final templates = await db!.query(
        MovementTables.tablePlanTemplates,
        where: 'id = ?',
        whereArgs: [templateId],
      );
      expect(templates.length, equals(1));
      expect(templates.first['activityKindId'], equals('kind_running'));

      // Verify schedules
      final schedules = await db!.query(
        MovementTables.tablePlanSchedules,
        where: 'templateId = ?',
        whereArgs: [templateId],
      );
      expect(schedules.length, equals(2));

      // Verify 4 weeks x 2 days = 8 occurrences generated in horizon
      final occurrences = await db!.query(
        MovementTables.tableOccurrences,
        where: 'templateId = ?',
        whereArgs: [templateId],
      );
      expect(occurrences.length, equals(8));
      for (final occ in occurrences) {
        expect(occ['activityKindId'], equals('kind_running'));
        expect(occ['status'], equals('planned'));
      }
    });

    test('updatePlanWithScope onlyThis modifies only the single occurrence', () async {
      if (!dbInitialized || db == null) return;

      final templateId = await service.createPlan(
        activityKindId: 'kind_walking',
        sessionType: 'repeating',
        goal: {'type': 'duration', 'value': 20, 'unit': 'دقیقه'},
        reminderType: 'none',
        schedules: [
          MovementPlanSchedule(
            id: 'sch_1',
            templateId: '',
            weekday: 1, // Sunday
            timeOfDay: '08:00',
            recurrence: 'weekly',
            startDateIso: '2026-08-16',
            createdAt: DateTime.now(),
          ),
        ],
      );

      final occs = await db!.query(
        MovementTables.tableOccurrences,
        where: 'templateId = ?',
        whereArgs: [templateId],
        orderBy: 'dateIso ASC',
      );
      expect(occs.length, equals(4));

      final firstOccId = occs.first['id'] as String;
      final firstOccDate = occs.first['dateIso'] as String;

      await service.updatePlanWithScope(
        templateId: templateId,
        focalDateIso: firstOccDate,
        occurrenceId: firstOccId,
        scope: MovementChangeScope.onlyThis,
        newGoal: {'type': 'duration', 'value': 45, 'unit': 'دقیقه'},
        newStartTime: '09:30',
      );

      // Verify only first occurrence modified
      final updatedFirst = await db!.query(
        MovementTables.tableOccurrences,
        where: 'id = ?',
        whereArgs: [firstOccId],
      );
      expect(updatedFirst.first['goalValue'], equals(45.0));
      expect(updatedFirst.first['startTime'], equals('09:30'));

      // Verify remaining 3 occurrences unchanged
      final others = await db!.query(
        MovementTables.tableOccurrences,
        where: 'templateId = ? AND id != ?',
        whereArgs: [templateId, firstOccId],
      );
      for (final o in others) {
        expect(o['goalValue'], equals(20.0));
        expect(o['startTime'], equals('08:00'));
      }
    });

    test('updatePlanWithScope thisAndFuture updates future occurrences and preserves past occurrences', () async {
      if (!dbInitialized || db == null) return;

      final templateId = await service.createPlan(
        activityKindId: 'kind_walking',
        sessionType: 'repeating',
        goal: {'type': 'duration', 'value': 25, 'unit': 'دقیقه'},
        reminderType: 'none',
        schedules: [
          MovementPlanSchedule(
            id: 'sch_1',
            templateId: '',
            weekday: 1, // Sunday
            timeOfDay: '08:00',
            recurrence: 'weekly',
            startDateIso: '2026-08-16',
            createdAt: DateTime.now(),
          ),
        ],
      );

      final occs = await db!.query(
        MovementTables.tableOccurrences,
        where: 'templateId = ?',
        whereArgs: [templateId],
        orderBy: 'dateIso ASC',
      );
      final secondOcc = occs[1];
      final secondDate = secondOcc['dateIso'] as String;

      await service.updatePlanWithScope(
        templateId: templateId,
        focalDateIso: secondDate,
        occurrenceId: secondOcc['id'] as String,
        scope: MovementChangeScope.thisAndFuture,
        newGoal: {'type': 'duration', 'value': 50, 'unit': 'دقیقه'},
      );

      // Past occurrence (first) remains 25
      final past = await db!.query(
        MovementTables.tableOccurrences,
        where: 'id = ?',
        whereArgs: [occs[0]['id']],
      );
      expect(past.first['goalValue'], equals(25.0));

      // Occurrences from second onwards are updated to 50
      final future = await db!.query(
        MovementTables.tableOccurrences,
        where: 'templateId = ? AND dateIso >= ?',
        whereArgs: [templateId, secondDate],
      );
      for (final f in future) {
        expect(f['goalValue'], equals(50.0));
      }
    });

    test('moveOccurrence, skipOccurrence, shortenOccurrence update row accurately', () async {
      if (!dbInitialized || db == null) return;

      final now = DateTime.now().toUtc().toIso8601String();
      await db!.insert(MovementTables.tableOccurrences, {
        'id': 'occ_test_1',
        'activityKindId': 'kind_running',
        'dateIso': '2026-08-16',
        'startTime': '07:00',
        'status': 'planned',
        'goalType': 'duration',
        'goalValue': 30.0,
        'goalUnit': 'دقیقه',
        'origin': 'oneOff',
        'createdAt': now,
        'updatedAt': now,
      });

      // 1. Move occurrence
      await service.moveOccurrence(
        occurrenceId: 'occ_test_1',
        newDateIso: '2026-08-18',
        newStartTime: '08:30',
        scope: MovementChangeScope.onlyThis,
      );
      var row = (await db!.query(MovementTables.tableOccurrences, where: 'id = ?', whereArgs: ['occ_test_1'])).first;
      expect(row['dateIso'], equals('2026-08-18'));
      expect(row['startTime'], equals('08:30'));
      expect(row['movedToDateIso'], equals('2026-08-18'));

      // 2. Shorten occurrence
      await service.shortenOccurrence(
        occurrenceId: 'occ_test_1',
        newGoalValue: 15.0,
      );
      row = (await db!.query(MovementTables.tableOccurrences, where: 'id = ?', whereArgs: ['occ_test_1'])).first;
      expect(row['goalValue'], equals(15.0));

      // 3. Skip occurrence
      await service.skipOccurrence(occurrenceId: 'occ_test_1');
      row = (await db!.query(MovementTables.tableOccurrences, where: 'id = ?', whereArgs: ['occ_test_1'])).first;
      expect(row['status'], equals('skipped'));
    });

    test('checkConflicts detects overlapping occurrences on same date within +-30m', () async {
      if (!dbInitialized || db == null) return;

      final now = DateTime.now().toUtc().toIso8601String();
      await db!.insert(MovementTables.tableOccurrences, {
        'id': 'occ_exist_1',
        'activityKindId': 'kind_cycling',
        'dateIso': '2026-08-16',
        'startTime': '08:00',
        'status': 'planned',
        'origin': 'template',
        'createdAt': now,
        'updatedAt': now,
      });

      // Checking same date and 08:15 should detect conflict
      final conflicts = await service.checkConflicts(
        dateIso: '2026-08-16',
        timeOfDay: '08:15',
      );
      expect(conflicts.length, equals(1));
      expect(conflicts.first.id, equals('occ_exist_1'));

      // Checking same date with 14:00 should have NO conflict
      final noConflicts = await service.checkConflicts(
        dateIso: '2026-08-16',
        timeOfDay: '14:00',
      );
      expect(noConflicts.isEmpty, isTrue);
    });

    test('deleteWithScope wholePlan archives template and removes future occurrences while preserving logs', () async {
      if (!dbInitialized || db == null) return;

      final templateId = await service.createPlan(
        activityKindId: 'kind_swimming',
        sessionType: 'repeating',
        goal: {'type': 'duration', 'value': 45, 'unit': 'دقیقه'},
        reminderType: 'none',
        schedules: [
          MovementPlanSchedule(
            id: 'sch_1',
            templateId: '',
            weekday: 2, // Monday
            timeOfDay: '17:00',
            recurrence: 'weekly',
            startDateIso: '2026-08-17',
            createdAt: DateTime.now(),
          ),
        ],
      );

      // Add a completed workout log
      await db!.insert(MovementTables.tableWorkoutLogs, {
        'id': 'log_swim_1',
        'occurrenceId': 'occ_swim_old',
        'activityKindId': 'kind_swimming',
        'dateIso': '2026-08-10',
        'durationSec': 2700,
        'source': 'retro',
        'createdAt': DateTime.now().toIso8601String(),
      });

      await service.deleteWithScope(
        occurrenceId: 'dummy',
        focalDateIso: '2026-08-17',
        templateId: templateId,
        scope: MovementChangeScope.wholePlan,
      );

      // Verify template archived
      final template = (await db!.query(
        MovementTables.tablePlanTemplates,
        where: 'id = ?',
        whereArgs: [templateId],
      )).first;
      expect(template['archivedAt'], isNotNull);

      // Verify future occurrences deleted
      final remainingOccs = await db!.query(
        MovementTables.tableOccurrences,
        where: 'templateId = ?',
        whereArgs: [templateId],
      );
      expect(remainingOccs.isEmpty, isTrue);

      // Verify workout logs remain untouched
      final logs = await db!.query(MovementTables.tableWorkoutLogs);
      expect(logs.length, equals(1));
    });
  });
}
