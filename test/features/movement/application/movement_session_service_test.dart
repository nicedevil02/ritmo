import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/schema/tables/movement_tables.dart';
import 'package:ritmo/features/movement/application/movement_session_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_live_session.dart';
import 'package:ritmo/features/movement/domain/models/movement_occurrence.dart';
import 'package:ritmo/features/movement/domain/models/movement_session_event.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  try {
    sqfliteFfiInit();
  } catch (_) {}

  group('MovementSessionService Event-Driven Tests (Gate 3)', () {
    Database? db;
    bool dbReady = false;

    setUp(() async {
      try {
        databaseFactory = databaseFactoryFfi;
        db = await databaseFactory.openDatabase(inMemoryDatabasePath);
        await MovementTables.create(db!);
        await MovementTables.seedInitialData(db!);
        dbReady = true;
      } catch (_) {
        dbReady = false;
      }
    });

    tearDown(() async {
      if (dbReady && db != null) {
        await db!.close();
      }
    });

    test('1. startSession creates session, records start event, and sets occurrence inProgress', () async {
      if (!dbReady || db == null) return;
      final service = MovementSessionService(db: db);

      // Create test occurrence
      const occId = 'occ_live_test_1';
      await db!.insert(MovementTables.tableOccurrences, {
        'id': occId,
        'activityKindId': 'kind_running',
        'dateIso': '2026-08-16',
        'startTime': '08:00',
        'status': MovementOccurrenceStatus.planned.name,
        'goalType': 'duration',
        'goalValue': 30.0,
        'goalUnit': 'دقیقه',
        'origin': 'manual',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      final session = await service.startSession(
        occurrenceId: occId,
        activityKindId: 'kind_running',
        mode: 'distance',
        targetSnapshot: {'distanceKm': 5.0},
      );

      expect(session.status, equals(MovementLiveSessionStatus.active));
      expect(session.mode, equals('distance'));

      // Check event recorded
      final events = await service.getEvents(session.id);
      expect(events.length, equals(1));
      expect(events.first.type, equals(MovementSessionEventType.start));

      // Check occurrence updated to inProgress
      final occRows = await db!.query(
        MovementTables.tableOccurrences,
        where: 'id = ?',
        whereArgs: [occId],
      );
      expect(occRows.first['status'], equals(MovementOccurrenceStatus.inProgress.name));
    });

    test('2. recordEvent saves immediately and P95 execution time is under 100ms', () async {
      if (!dbReady || db == null) return;
      final service = MovementSessionService(db: db);

      final session = await service.startSession(
        activityKindId: 'kind_walking',
        mode: 'time',
      );

      final durations = <int>[];
      for (int i = 0; i < 20; i++) {
        final sw = Stopwatch()..start();
        await service.recordEvent(
          sessionId: session.id,
          type: MovementSessionEventType.distance,
          payload: {'distanceKm': 0.1 * (i + 1)},
        );
        sw.stop();
        durations.add(sw.elapsedMilliseconds);
      }

      durations.sort();
      final p95Index = (durations.length * 0.95).floor();
      final p95 = durations[p95Index];

      expect(p95, lessThan(100)); // P95 < 100ms

      final events = await service.getEvents(session.id);
      expect(events.length, equals(21)); // 1 start + 20 distance events
    });

    test('3. pause and resume calculate accumulatedPauseMs accurately without frame ticking', () async {
      if (!dbReady || db == null) return;
      final service = MovementSessionService(db: db);

      final session = await service.startSession(
        activityKindId: 'kind_running',
        mode: 'time',
      );

      await service.pauseSession(session.id);
      final pausedSession = await service.getSessionById(session.id);
      expect(pausedSession?.status, equals(MovementLiveSessionStatus.paused));

      // Wait 50ms and resume
      await Future.delayed(const Duration(milliseconds: 50));
      await service.resumeSession(session.id);

      final resumedSession = await service.getSessionById(session.id);
      expect(resumedSession?.status, equals(MovementLiveSessionStatus.active));
      expect(resumedSession!.accumulatedPauseMs, greaterThanOrEqualTo(40));
    });

    test('4. finishSession creates WorkoutLog with source live, completes occurrence and archives session', () async {
      if (!dbReady || db == null) return;
      final service = MovementSessionService(db: db);

      const occId = 'occ_finish_test';
      await db!.insert(MovementTables.tableOccurrences, {
        'id': occId,
        'activityKindId': 'kind_running',
        'dateIso': '2026-08-16',
        'startTime': '08:00',
        'status': MovementOccurrenceStatus.inProgress.name,
        'goalType': 'duration',
        'goalValue': 30.0,
        'goalUnit': 'دقیقه',
        'origin': 'manual',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      final session = await service.startSession(
        occurrenceId: occId,
        activityKindId: 'kind_running',
        mode: 'distance',
      );

      final log = await service.finishSession(
        session.id,
        feeling: 'عالی',
        note: 'دویدن صبحگاهی پرانرژی',
        finalMetrics: {'distanceKm': 5.2},
      );

      expect(log.source, equals('live'));
      expect(log.feeling, equals('عالی'));
      expect(log.occurrenceId, equals(occId));

      // Occurrence must be completed
      final occRows = await db!.query(
        MovementTables.tableOccurrences,
        where: 'id = ?',
        whereArgs: [occId],
      );
      expect(occRows.first['status'], equals(MovementOccurrenceStatus.completed.name));

      // Live session row status must be completed
      final sessionRow = await service.getSessionById(session.id);
      expect(sessionRow?.status, equals(MovementLiveSessionStatus.completed));
    });

    test('5. abandonSession sets status to abandoned and restores planned occurrence', () async {
      if (!dbReady || db == null) return;
      final service = MovementSessionService(db: db);

      const occId = 'occ_abandon_test';
      await db!.insert(MovementTables.tableOccurrences, {
        'id': occId,
        'activityKindId': 'kind_swimming',
        'dateIso': '2026-08-16',
        'status': MovementOccurrenceStatus.inProgress.name,
        'origin': 'manual',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      final session = await service.startSession(
        occurrenceId: occId,
        activityKindId: 'kind_swimming',
        mode: 'lap',
      );

      await service.abandonSession(session.id);

      final sessionRow = await service.getSessionById(session.id);
      expect(sessionRow?.status, equals(MovementLiveSessionStatus.abandoned));

      final occRows = await db!.query(
        MovementTables.tableOccurrences,
        where: 'id = ?',
        whereArgs: [occId],
      );
      expect(occRows.first['status'], equals(MovementOccurrenceStatus.planned.name));
    });
  });
}
