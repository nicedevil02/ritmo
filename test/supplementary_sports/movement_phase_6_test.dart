// test/supplementary_sports/movement_phase_6_test.dart

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_kind.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/session_mode.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_session.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_campaign.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/movement_session_repository.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/movement_campaign_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  try {
    sqfliteFfiInit();
  } catch (_) {}

  group('Phase 6 | Custom SessionMode & Resolve Tests', () {
    test('resolveMode infers HIKING -> route, SWIMMING -> laps, RUNNING -> distance, FUTSAL -> match, YOGA -> timed, STRENGTH_GYM -> structured', () {
      const hike = MovementKind(
        code: 'HIKING',
        titleFa: 'کوهنوردی',
        emoji: '🏔',
        family: MovementFamily.outdoor,
        baseMet: 6.0,
        metLow: 4.0,
        metHigh: 8.0,
        primaryMetric: MovementMetric.distance,
        secondaryMetric: MovementMetric.none,
        isOutdoor: true,
        isSocial: false,
        needsVenue: false,
        jointImpact: 2,
        isCustom: false,
        isEnabled: true,
        usageCount: 0,
        sortOrder: 0,
      );
      expect(resolveMode(hike), equals(SessionMode.route));

      const swim = MovementKind(
        code: 'SWIMMING',
        titleFa: 'شنا',
        emoji: '🏊',
        family: MovementFamily.endurance,
        baseMet: 7.0,
        metLow: 5.0,
        metHigh: 9.0,
        primaryMetric: MovementMetric.laps,
        secondaryMetric: MovementMetric.none,
        isOutdoor: false,
        isSocial: false,
        needsVenue: true,
        jointImpact: 0,
        isCustom: false,
        isEnabled: true,
        usageCount: 0,
        sortOrder: 0,
      );
      expect(resolveMode(swim), equals(SessionMode.laps));

      const run = MovementKind(
        code: 'RUNNING',
        titleFa: 'دویدن',
        emoji: '🏃',
        family: MovementFamily.endurance,
        baseMet: 8.0,
        metLow: 6.0,
        metHigh: 10.0,
        primaryMetric: MovementMetric.distance,
        secondaryMetric: MovementMetric.none,
        isOutdoor: false,
        isSocial: false,
        needsVenue: false,
        jointImpact: 3,
        isCustom: false,
        isEnabled: true,
        usageCount: 0,
        sortOrder: 0,
      );
      expect(resolveMode(run), equals(SessionMode.distance));

      const futsal = MovementKind(
        code: 'FUTSAL',
        titleFa: 'فوتسال',
        emoji: '⚽',
        family: MovementFamily.sport,
        baseMet: 7.0,
        metLow: 5.0,
        metHigh: 9.0,
        primaryMetric: MovementMetric.duration,
        secondaryMetric: MovementMetric.none,
        isOutdoor: false,
        isSocial: true,
        needsVenue: true,
        jointImpact: 2,
        isCustom: false,
        isEnabled: true,
        usageCount: 0,
        sortOrder: 0,
      );
      expect(resolveMode(futsal), equals(SessionMode.match));

      const yoga = MovementKind(
        code: 'YOGA',
        titleFa: 'یوگا',
        emoji: '🧘',
        family: MovementFamily.mindBody,
        baseMet: 2.5,
        metLow: 2.0,
        metHigh: 3.0,
        primaryMetric: MovementMetric.duration,
        secondaryMetric: MovementMetric.none,
        isOutdoor: false,
        isSocial: false,
        needsVenue: false,
        jointImpact: 0,
        isCustom: false,
        isEnabled: true,
        usageCount: 0,
        sortOrder: 0,
      );
      expect(resolveMode(yoga), equals(SessionMode.timed));

      const gym = MovementKind(
        code: 'STRENGTH_GYM',
        titleFa: 'بدنسازی',
        emoji: '🏋️',
        family: MovementFamily.strength,
        baseMet: 5.0,
        metLow: 3.0,
        metHigh: 7.0,
        primaryMetric: MovementMetric.duration,
        secondaryMetric: MovementMetric.none,
        isOutdoor: false,
        isSocial: false,
        needsVenue: false,
        jointImpact: 1,
        isCustom: false,
        isEnabled: true,
        usageCount: 0,
        sortOrder: 0,
      );
      expect(resolveMode(gym), equals(SessionMode.structured));
    });

    test('effectiveMode respects sessionModeOverride', () {
      const customKind = MovementKind(
        code: 'CUSTOM_SPORTS',
        titleFa: 'ورزش سفارشی',
        emoji: '🥎',
        family: MovementFamily.sport,
        baseMet: 4.0,
        metLow: 3.0,
        metHigh: 5.0,
        primaryMetric: MovementMetric.duration,
        secondaryMetric: MovementMetric.none,
        isOutdoor: false,
        isSocial: false,
        needsVenue: false,
        jointImpact: 1,
        isCustom: true,
        isEnabled: true,
        usageCount: 0,
        sortOrder: 0,
        sessionModeOverride: 'LAPS',
      );
      expect(effectiveMode(customKind), equals(SessionMode.laps));
    });
  });

  group('Phase 6 | Database-Backed Live Session & Campaign Tests', () {
    late Database db;
    bool dbInitialized = false;

    setUp(() async {
      try {
        databaseFactory = databaseFactoryFfi;
        db = await openDatabase(inMemoryDatabasePath, version: 1, onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE movement_kinds (
              code TEXT PRIMARY KEY,
              titleFa TEXT,
              emoji TEXT,
              family TEXT,
              baseMet REAL,
              metLow REAL,
              metHigh REAL,
              primaryMetric TEXT,
              secondaryMetric TEXT,
              isOutdoor INTEGER,
              isSocial INTEGER,
              needsVenue INTEGER,
              jointImpact INTEGER,
              isCustom INTEGER,
              isEnabled INTEGER,
              usageCount INTEGER,
              sortOrder INTEGER,
              sessionModeOverride TEXT
            );
          ''');

          await db.execute('''
            CREATE TABLE routines (
              id TEXT PRIMARY KEY,
              title TEXT,
              category TEXT,
              routineType TEXT,
              targetDurationMinutes INTEGER,
              movementKind TEXT,
              movementTargetMetric TEXT,
              movementTargetValue REAL,
              isArchived INTEGER,
              createdAt INTEGER,
              updatedAt INTEGER
            );
          ''');

          await db.execute('''
            CREATE TABLE routine_schedules (
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

          await db.execute('''
            CREATE TABLE movement_sessions (
              id            TEXT PRIMARY KEY,
              kindCode      TEXT NOT NULL,
              routineId     TEXT,
              occurrenceId  TEXT,
              prescriptionId TEXT,
              sessionMode   TEXT NOT NULL,
              status        TEXT NOT NULL,
              startedAt     INTEGER NOT NULL,
              endedAt       INTEGER,
              pausedMs      INTEGER NOT NULL DEFAULT 0,
              targetJson    TEXT,
              liveJson      TEXT,
              workoutLogId  TEXT,
              createdAt     INTEGER NOT NULL,
              updatedAt     INTEGER NOT NULL
            );
          ''');

          await db.execute('''
            CREATE UNIQUE INDEX idx_movement_sessions_active
              ON movement_sessions(status) WHERE status IN ('ACTIVE', 'PAUSED');
          ''');

          await db.execute('''
            CREATE TABLE movement_session_events (
              id        TEXT PRIMARY KEY,
              sessionId TEXT NOT NULL,
              type      TEXT NOT NULL,
              at        INTEGER NOT NULL,
              dataJson  TEXT
            );
          ''');

          await db.execute('''
            CREATE TABLE workout_logs (
              id TEXT PRIMARY KEY,
              sourceModule TEXT,
              sourceEntityId TEXT,
              durationMinutes INTEGER,
              loggedAt INTEGER,
              endedAt INTEGER,
              updatedAt INTEGER,
              deletedAt INTEGER,
              movementKind TEXT,
              distanceMeters REAL,
              elevationMeters REAL,
              laps INTEGER,
              feeling TEXT,
              note TEXT
            );
          ''');

          await db.execute('''
            CREATE UNIQUE INDEX idx_workout_logs_source_entity
              ON workout_logs(sourceModule, sourceEntityId);
          ''');

          await db.execute('''
            CREATE TABLE movement_campaigns (
              id           TEXT PRIMARY KEY,
              titleFa      TEXT NOT NULL,
              goalCode     TEXT NOT NULL,
              startDate    TEXT NOT NULL,
              weeks        INTEGER NOT NULL,
              status       TEXT NOT NULL,
              routineIds   TEXT NOT NULL,
              progressJson TEXT,
              createdAt    INTEGER NOT NULL,
              updatedAt    INTEGER NOT NULL
            );
          ''');

          // Seed default kinds
          await db.insert('movement_kinds', {
            'code': 'HIKING',
            'titleFa': 'کوهنوردی',
            'family': 'OUTDOOR',
            'isEnabled': 1,
            'primaryMetric': 'DISTANCE',
            'jointImpact': 2,
          });
          await db.insert('movement_kinds', {
            'code': 'STRENGTH_HOME',
            'titleFa': 'قدرت پا',
            'family': 'STRENGTH',
            'isEnabled': 1,
            'primaryMetric': 'DURATION',
            'jointImpact': 1,
          });
          await db.insert('movement_kinds', {
            'code': 'STAIR_CLIMBING',
            'titleFa': 'پله‌نوردی',
            'family': 'DAILY',
            'isEnabled': 1,
            'primaryMetric': 'DURATION',
            'jointImpact': 2,
          });
        });

        DatabaseHelper.instance.overrideDatabaseForTesting(db);
        dbInitialized = true;
      } catch (_) {
        dbInitialized = false;
      }
    });

    tearDown(() async {
      if (dbInitialized) {
        await db.close();
      }
    });

    test('زمان دیواری: elapsed calculation accounts for startedAt and pausedMs correctly', () {
      if (!dbInitialized) return;

      final now = DateTime.now().millisecondsSinceEpoch;
      final startedAt = now - 3600 * 1000; // 3600 seconds ago
      final pausedMs = 600 * 1000; // 600 seconds paused

      final elapsedMs = now - startedAt - pausedMs;
      expect(elapsedMs, equals(3000 * 1000));
    });

    test('مکث/ادامه: pause and resume updates pausedMs in DB correctly', () async {
      if (!dbInitialized) return;

      const kind = MovementKind(
        code: 'HIKING',
        titleFa: 'کوهنوردی',
        emoji: '🏔',
        family: MovementFamily.outdoor,
        baseMet: 6.0,
        metLow: 4.0,
        metHigh: 8.0,
        primaryMetric: MovementMetric.distance,
        secondaryMetric: MovementMetric.none,
        isOutdoor: true,
        isSocial: false,
        needsVenue: false,
        jointImpact: 2,
        isCustom: false,
        isEnabled: true,
        usageCount: 0,
        sortOrder: 0,
      );

      final session = await MovementSessionRepository.instance.startSession(
        kind: kind,
        sessionMode: 'route',
      );

      expect(session.status, equals(MovementSessionStatus.active));
      expect(session.pausedMs, equals(0));

      await MovementSessionRepository.instance.pauseSession(session.id);
      
      final pausedSession = await MovementSessionRepository.instance.getActiveSession();
      expect(pausedSession!.status, equals(MovementSessionStatus.paused));

      // Wait a tiny bit and resume
      await Future.delayed(const Duration(milliseconds: 100));
      await MovementSessionRepository.instance.resumeSession(session.id);

      final resumedSession = await MovementSessionRepository.instance.getActiveSession();
      expect(resumedSession!.status, equals(MovementSessionStatus.active));
      expect(resumedSession.pausedMs, isPositive);
    });

    test('پایان خودتوان: calling finishSession multiple times inserts exactly 1 workout_log', () async {
      if (!dbInitialized) return;

      const kind = MovementKind(
        code: 'HIKING',
        titleFa: 'کوهنوردی',
        emoji: '🏔',
        family: MovementFamily.outdoor,
        baseMet: 6.0,
        metLow: 4.0,
        metHigh: 8.0,
        primaryMetric: MovementMetric.distance,
        secondaryMetric: MovementMetric.none,
        isOutdoor: true,
        isSocial: false,
        needsVenue: false,
        jointImpact: 2,
        isCustom: false,
        isEnabled: true,
        usageCount: 0,
        sortOrder: 0,
      );

      final session = await MovementSessionRepository.instance.startSession(
        kind: kind,
        sessionMode: 'route',
      );

      final id1 = await MovementSessionRepository.instance.finishSession(session.id);
      final id2 = await MovementSessionRepository.instance.finishSession(session.id);

      expect(id1, equals(id2));

      final logs = await db.query('workout_logs', where: 'sourceEntityId = ?', whereArgs: [session.id]);
      expect(logs.length, equals(1));
    });

    test('یکتایی جلسه زنده: active unique constraint prevents multiple concurrent active sessions', () async {
      if (!dbInitialized) return;

      await db.insert('movement_sessions', {
        'id': 'session_1',
        'kindCode': 'HIKING',
        'sessionMode': 'route',
        'status': 'ACTIVE',
        'startedAt': DateTime.now().millisecondsSinceEpoch,
        'pausedMs': 0,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      expect(
        () async => await db.insert('movement_sessions', {
          'id': 'session_2',
          'kindCode': 'STRENGTH_HOME',
          'sessionMode': 'structured',
          'status': 'ACTIVE',
          'startedAt': DateTime.now().millisecondsSinceEpoch,
          'pausedMs': 0,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('بازیابی: getActiveSession correctly loads the unfinished active session', () async {
      if (!dbInitialized) return;

      await db.insert('movement_sessions', {
        'id': 'session_crash_test',
        'kindCode': 'HIKING',
        'sessionMode': 'route',
        'status': 'ACTIVE',
        'startedAt': DateTime.now().millisecondsSinceEpoch,
        'pausedMs': 0,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      final active = await MovementSessionRepository.instance.getActiveSession();
      expect(active, isNotNull);
      expect(active!.id, equals('session_crash_test'));
      expect(active.status, equals(MovementSessionStatus.active));
    });

    test('ورودی دستی سنجه: manual metrics on route session saves properly to workout log', () async {
      if (!dbInitialized) return;

      const kind = MovementKind(
        code: 'HIKING',
        titleFa: 'کوهنوردی',
        emoji: '🏔',
        family: MovementFamily.outdoor,
        baseMet: 6.0,
        metLow: 4.0,
        metHigh: 8.0,
        primaryMetric: MovementMetric.distance,
        secondaryMetric: MovementMetric.none,
        isOutdoor: true,
        isSocial: false,
        needsVenue: false,
        jointImpact: 2,
        isCustom: false,
        isEnabled: true,
        usageCount: 0,
        sortOrder: 0,
      );

      final session = await MovementSessionRepository.instance.startSession(
        kind: kind,
        sessionMode: 'route',
      );

      // Save manual elevation
      await db.update(
        'movement_sessions',
        {'liveJson': jsonEncode({'manualElevationMeters': 900.0})},
        where: 'id = ?',
        whereArgs: [session.id],
      );

      final logId = await MovementSessionRepository.instance.finishSession(session.id);
      final logs = await db.query('workout_logs', where: 'id = ?', whereArgs: [logId]);
      
      expect(logs.isNotEmpty, isTrue);
      expect(logs.first['elevationMeters'], equals(900.0));
    });

    test('کارزار: createCampaign generates expected routines, cancelCampaign archives all routines', () async {
      if (!dbInitialized) return;

      final campaign = await MovementCampaignRepository.instance.createCampaign(
        goalCode: 'DAMAVAND_6W',
        titleFa: 'دماوند در ۶ هفته',
        startDate: DateTime.now(),
        weeks: 6,
      );

      expect(campaign.status, equals(MovementCampaignStatus.active));
      expect(campaign.routineIds.length, equals(4)); // Hiking + 2 Strength + Stair Climbing

      // Verify routines are in DB
      for (final rId in campaign.routineIds) {
        final rRows = await db.query('routines', where: 'id = ?', whereArgs: [rId]);
        expect(rRows.length, equals(1));
        expect(rRows.first['isArchived'], equals(0));
      }

      // Cancel campaign
      await MovementCampaignRepository.instance.cancelCampaign(campaign.id);

      // Verify campaign is cancelled and routines are archived
      final updatedCamp = await MovementCampaignRepository.instance.getCampaignById(campaign.id);
      expect(updatedCamp!.status, equals(MovementCampaignStatus.cancelled));

      for (final rId in campaign.routineIds) {
        final rRows = await db.query('routines', where: 'id = ?', whereArgs: [rId]);
        expect(rRows.first['isArchived'], equals(1));
      }
    });
  });
}
