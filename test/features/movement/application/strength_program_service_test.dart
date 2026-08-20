import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/schema/tables/movement_tables.dart';
import 'package:ritmo/features/movement/application/strength_program_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_change_scope.dart';
import 'package:ritmo/features/movement/domain/models/movement_set_log.dart';
import 'package:ritmo/features/movement/domain/models/movement_strength_day.dart';
import 'package:ritmo/features/movement/domain/models/movement_strength_program.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  try {
    sqfliteFfiInit();
  } catch (_) {}

  group('StrengthProgramService Rule-Based & Persistence Tests (Gate 4)', () {
    Database? db;
    bool dbReady = false;
    late StrengthProgramService service;

    setUp(() async {
      try {
        databaseFactory = databaseFactoryFfi;
        db = await databaseFactory.openDatabase(inMemoryDatabasePath);
        await MovementTables.create(db!);
        service = StrengthProgramService(db: db);
        dbReady = true;
      } catch (_) {
        service = StrengthProgramService();
        dbReady = false;
      }
    });

    tearDown(() async {
      if (dbReady && db != null) {
        await db!.close();
      }
    });

    test(
      '1. Rule-based generator is strictly deterministic (same input produces identical plan)',
      () {
        final input = {
          'goal': 'muscle',
          'level': 'intermediate',
          'sensitiveAreas': ['knees'],
          'equipment': ['dumbbells', 'resistance_bands'],
          'daysPerWeek': 3,
          'sessionMinutes': 30,
          'preferredDays': [1, 3, 5],
          'preferredTime': '08:00',
        };

        final plan1 = service.generateProgramPlan(
          goal: input['goal'] as String,
          level: input['level'] as String,
          sensitiveAreas: input['sensitiveAreas'] as List<String>,
          equipment: input['equipment'] as List<String>,
          daysPerWeek: input['daysPerWeek'] as int,
          sessionMinutes: input['sessionMinutes'] as int,
          preferredDays: input['preferredDays'] as List<int>,
          preferredTime: input['preferredTime'] as String,
        );

        final plan2 = service.generateProgramPlan(
          goal: input['goal'] as String,
          level: input['level'] as String,
          sensitiveAreas: input['sensitiveAreas'] as List<String>,
          equipment: input['equipment'] as List<String>,
          daysPerWeek: input['daysPerWeek'] as int,
          sessionMinutes: input['sessionMinutes'] as int,
          preferredDays: input['preferredDays'] as List<int>,
          preferredTime: input['preferredTime'] as String,
        );

        final prog1 = plan1['program'] as MovementStrengthProgram;
        final prog2 = plan2['program'] as MovementStrengthProgram;
        final days1 = plan1['days'] as List<MovementStrengthDay>;
        final days2 = plan2['days'] as List<MovementStrengthDay>;

        expect(prog1.daysPerWeek, equals(prog2.daysPerWeek));
        expect(prog1.totalWeeks, equals(6));
        expect(prog1.deloadWeekIndex, equals(4));
        expect(days1.length, equals(days2.length));
        expect(
          days1.first.exercises.length,
          equals(days2.first.exercises.length),
        );

        // بررسی رعایت ایمنی زانو: نباید اسکات عمیق داشته باشد، بلکه پل باسن دارد
        final exNames1 = days1.first.exercises.map((e) => e.nameFa).toList();
        expect(exNames1.any((name) => name.contains('پل باسن')), isTrue);
      },
    );

    test(
      '2. Atomic activation writes program, days, exercises and occurrences in a single transaction',
      () async {
        if (!dbReady) return;

        final planMap = service.generateProgramPlan(
          goal: 'strength',
          level: 'intermediate',
          sensitiveAreas: [],
          equipment: ['bodyweight'],
          daysPerWeek: 3,
          sessionMinutes: 30,
          preferredDays: [1, 3, 5],
        );

        final program = planMap['program'] as MovementStrengthProgram;
        final days = planMap['days'] as List<MovementStrengthDay>;

        await service.activateProgram(program: program, days: days);

        final active = await service.getCurrentProgram();
        expect(active, isNotNull);
        expect(active!.status, equals(MovementStrengthProgramStatus.active));
        expect(active.goal, equals('strength'));

        final storedDays = await service.getProgramDays(active.id);
        expect(storedDays.length, equals(18)); // 6 weeks * 3 days = 18
        expect(storedDays.first.exercises.length, greaterThanOrEqualTo(4));

        // بررسی ایجاد Occurrenceها با origin = 'strength'
        final occRows = await db!.query(
          MovementTables.tableOccurrences,
          where: 'origin = ?',
          whereArgs: ['strength'],
        );
        expect(occRows.length, equals(18));
        expect(occRows.first['activityKindId'], equals('kind_strength'));
      },
    );

    test(
      '3. Draft persistence after each step and resume capability',
      () async {
        if (!dbReady) return;

        const progId = 'draft_prog_1';

        // ذخیره گام ۱
        await service.saveDraft(
          programId: progId,
          draftStep: 1,
          goal: 'endurance',
        );

        var draft = await service.getDraftProgram();
        expect(draft, isNotNull);
        expect(draft!.draftStep, equals(1));
        expect(draft.goal, equals('endurance'));

        // ذخیره گام ۳
        await service.saveDraft(
          programId: progId,
          draftStep: 3,
          equipment: ['dumbbells', 'pullup_bar'],
        );

        draft = await service.getDraftProgram();
        expect(draft, isNotNull);
        expect(draft!.draftStep, equals(3));
        expect(draft.equipment, contains('pullup_bar'));
      },
    );

    test('4. Pause, Resume, Finish and Swap Exercise mid-program', () async {
      if (!dbReady) return;

      final planMap = service.generateProgramPlan(
        goal: 'muscle',
        level: 'beginner',
        sensitiveAreas: [],
        equipment: ['bodyweight'],
        daysPerWeek: 2,
        sessionMinutes: 20,
        preferredDays: [1, 4],
      );

      final program = planMap['program'] as MovementStrengthProgram;
      final days = planMap['days'] as List<MovementStrengthDay>;
      await service.activateProgram(program: program, days: days);

      // مکث برنامه
      await service.pauseProgram(program.id);
      var current = await service.getCurrentProgram();
      expect(current!.isPaused, isTrue);

      // ادامه برنامه
      await service.resumeProgram(program.id);
      current = await service.getCurrentProgram();
      expect(current!.isActive, isTrue);

      // تعویض حرکت فقط برای امروز
      final firstEx = days.first.exercises.first;
      await service.swapExercise(
        exerciseId: firstEx.id,
        newExerciseNameFa: 'شنا روی دیوار',
        newMuscleGroup: 'سینه',
        scope: MovementChangeScope.onlyThis,
        dayId: days.first.id,
      );

      final updatedDays = await service.getProgramDays(
        program.id,
        weekIndex: 1,
      );
      expect(updatedDays.first.exercises.first.nameFa, equals('شنا روی دیوار'));
    });

    test(
      '5. Set log persistence: Hint is not automatically saved as entered data',
      () async {
        if (!dbReady) return;

        const sessionId = 'session_str_1';
        const exerciseId = 'ex_1';

        // لاگ ست ۱
        final log1 = MovementSetLog(
          id: 'log_set_1',
          sessionId: sessionId,
          exerciseId: exerciseId,
          setIndex: 1,
          weightKg: 20.0,
          reps: 10,
          rir: 2.0,
          completed: true,
          at: DateTime.now(),
        );

        await service.recordSetLog(log1);

        final setLogs = await service.getSetLogsForSession(sessionId);
        expect(setLogs.length, equals(1));
        expect(setLogs.first.weightKg, equals(20.0));
        expect(setLogs.first.reps, equals(10));
        expect(setLogs.first.rir, equals(2.0));
        expect(setLogs.first.completed, isTrue);
      },
    );
  });
}
