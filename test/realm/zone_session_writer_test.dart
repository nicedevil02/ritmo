import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/realm/active_realm_resolver.dart';
import 'package:ritmo/core/domain/realm/sessions/zone_session.dart';
import 'package:ritmo/core/domain/realm/sessions/zone_session_repository.dart';
import 'package:ritmo/core/domain/realm/sessions/zone_session_writer.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late ZoneSessionRepository repo;
  late ZoneSessionWriter writer;

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
            id            TEXT PRIMARY KEY,
            zoneId        TEXT NOT NULL,
            startedAt     INTEGER NOT NULL,
            endedAt       INTEGER,
            plannedEndAt  INTEGER,
            source        TEXT NOT NULL DEFAULT 'SCHEDULE',
            endReason     TEXT,
            createdAt     INTEGER NOT NULL,
            FOREIGN KEY(zoneId) REFERENCES zones(id) ON DELETE CASCADE
          );
        ''');

        await db.execute('CREATE INDEX idx_zone_sessions_started ON zone_sessions(startedAt);');
        await db.execute('CREATE INDEX idx_zone_sessions_zone ON zone_sessions(zoneId, startedAt);');
        await db.execute('''
          CREATE UNIQUE INDEX idx_zone_sessions_single_open
            ON zone_sessions((1)) WHERE endedAt IS NULL;
        ''');

        await db.insert('zones', {
          'id': 'work_zone',
          'name': 'قلمرو کار',
          'color': '#3B82F6',
          'icon': '💼',
          'mode': 'FOCUS',
          'isDefault': 0,
          'createdAt': 1000,
          'updatedAt': 1000,
        });

        await db.insert('zones', {
          'id': 'family_zone',
          'name': 'قلمرو خانواده',
          'color': '#10B981',
          'icon': '👨‍👩‍👧',
          'mode': 'SILENT',
          'isDefault': 0,
          'createdAt': 1000,
          'updatedAt': 1000,
        });
      },
    );

    repo = ZoneSessionRepository();
    writer = ZoneSessionWriter(repository: repo);
  });

  tearDown(() async {
    await db.close();
  });

  const workRealm = RealmData(
    id: 'work_zone',
    name: 'قلمرو کار',
    colorHex: '#3B82F6',
    icon: '💼',
    mode: RealmMode.focus,
  );

  const familyRealm = RealmData(
    id: 'family_zone',
    name: 'قلمرو خانواده',
    colorHex: '#10B981',
    icon: '👨‍👩‍👧',
    mode: RealmMode.silent,
  );

  group('ZoneSessionWriter & Session History (F-01, F-02, F-03)', () {
    test('1. Opening a scheduled realm session writes a record with plannedEndAt', () async {
      final now = DateTime(2026, 8, 26, 9, 0);
      final endsAt = DateTime(2026, 8, 26, 12, 0);

      final scheduledState = ScheduledRealmState(
        realm: workRealm,
        schedule: const RealmScheduleData(
          id: 's_work',
          zoneId: 'work_zone',
          daysOfWeek: {1, 2, 3, 4, 5, 6, 7},
          startTime: '09:00',
          endTime: '12:00',
        ),
        startsAt: now,
        endsAt: endsAt,
        remaining: const Duration(hours: 3),
        progress: 0.0,
        explanation: 'بر اساس زمان‌بندی',
      );

      await writer.reconcile(
        scheduledState,
        source: ZoneSource.schedule,
        now: now,
        executor: db,
      );

      final openSession = await repo.getOpenSession(executor: db);
      expect(openSession, isNotNull);
      expect(openSession!.zoneId, 'work_zone');
      expect(openSession.startedAt, now.millisecondsSinceEpoch);
      expect(openSession.plannedEndAt, endsAt.millisecondsSinceEpoch);
      expect(openSession.source, ZoneSource.schedule);
      expect(openSession.isOpen, isTrue);
    });

    test('2. Reconcile is strictly idempotent (multiple calls with same state produce single session)', () async {
      final now = DateTime(2026, 8, 26, 9, 0);
      final endsAt = DateTime(2026, 8, 26, 12, 0);

      final scheduledState = ScheduledRealmState(
        realm: workRealm,
        schedule: const RealmScheduleData(
          id: 's_work',
          zoneId: 'work_zone',
          daysOfWeek: {1, 2, 3, 4, 5, 6, 7},
          startTime: '09:00',
          endTime: '12:00',
        ),
        startsAt: now,
        endsAt: endsAt,
        remaining: const Duration(hours: 3),
        progress: 0.0,
        explanation: 'بر اساس زمان‌بندی',
      );

      // Call 5 times in a row
      for (int i = 0; i < 5; i++) {
        await writer.reconcile(
          scheduledState,
          source: ZoneSource.schedule,
          now: now.add(Duration(minutes: i)),
          executor: db,
        );
      }

      final allSessions = await repo.getSessionsForRange(
        start: now.subtract(const Duration(hours: 1)),
        end: now.add(const Duration(hours: 5)),
        executor: db,
      );

      expect(allSessions.length, 1);
      expect(allSessions.first.zoneId, 'work_zone');
      expect(allSessions.first.isOpen, isTrue);
    });

    test('3. Switching to a manual override closes previous session with OVERRIDDEN', () async {
      final t1 = DateTime(2026, 8, 26, 9, 0);
      final scheduledState = ScheduledRealmState(
        realm: workRealm,
        schedule: const RealmScheduleData(
          id: 's_work',
          zoneId: 'work_zone',
          daysOfWeek: {1, 2, 3, 4, 5, 6, 7},
          startTime: '09:00',
          endTime: '12:00',
        ),
        startsAt: t1,
        endsAt: t1.add(const Duration(hours: 3)),
        remaining: const Duration(hours: 3),
        progress: 0.0,
        explanation: 'بر اساس زمان‌بندی',
      );

      await writer.reconcile(scheduledState, source: ZoneSource.schedule, now: t1, executor: db);

      // At 10:00, user manually switches to family realm for 50 minutes
      final t2 = DateTime(2026, 8, 26, 10, 0);
      final manualState = ManualRealmState(
        realm: familyRealm,
        expireAt: t2.add(const Duration(minutes: 50)),
        remaining: const Duration(minutes: 50),
        progress: 0.0,
        explanation: 'دستی',
      );

      await writer.reconcile(manualState, source: ZoneSource.manual, now: t2, executor: db);

      // Verify previous session is closed
      final allSessions = await repo.getSessionsForRange(
        start: t1.subtract(const Duration(hours: 1)),
        end: t2.add(const Duration(hours: 2)),
        executor: db,
      );

      expect(allSessions.length, 2);

      final closedSession = allSessions.firstWhere((s) => s.zoneId == 'work_zone');
      expect(closedSession.isOpen, isFalse);
      expect(closedSession.endedAt, t2.millisecondsSinceEpoch);
      expect(closedSession.endReason, ZoneEndReason.overridden);

      final activeSession = allSessions.firstWhere((s) => s.zoneId == 'family_zone');
      expect(activeSession.isOpen, isTrue);
      expect(activeSession.source, ZoneSource.manual);
      expect(activeSession.plannedEndAt, t2.add(const Duration(minutes: 50)).millisecondsSinceEpoch);
    });

    test('4. Entering FreeRealmState closes active session with COMPLETED', () async {
      final t1 = DateTime(2026, 8, 26, 9, 0);
      final scheduledState = ScheduledRealmState(
        realm: workRealm,
        schedule: const RealmScheduleData(
          id: 's_work',
          zoneId: 'work_zone',
          daysOfWeek: {1, 2, 3, 4, 5, 6, 7},
          startTime: '09:00',
          endTime: '12:00',
        ),
        startsAt: t1,
        endsAt: t1.add(const Duration(hours: 3)),
        remaining: const Duration(hours: 3),
        progress: 0.0,
        explanation: 'بر اساس زمان‌بندی',
      );

      await writer.reconcile(scheduledState, source: ZoneSource.schedule, now: t1, executor: db);

      // Move to free time at 12:00
      final t2 = DateTime(2026, 8, 26, 12, 0);
      const freeState = FreeRealmState();

      await writer.reconcile(freeState, source: ZoneSource.schedule, now: t2, executor: db);

      final openSession = await repo.getOpenSession(executor: db);
      expect(openSession, isNull);

      final todaySessions = await repo.getSessionsForRange(
        start: t1.subtract(const Duration(hours: 1)),
        end: t2.add(const Duration(hours: 1)),
        executor: db,
      );
      expect(todaySessions.length, 1);
      expect(todaySessions.first.isOpen, isFalse);
      expect(todaySessions.first.endReason, ZoneEndReason.completed);
    });

    test('5. recoverAbandonedSessions closes expired open sessions with ABANDONED (F-03)', () async {
      final yesterdayStart = DateTime(2026, 8, 25, 10, 0).millisecondsSinceEpoch;
      final yesterdayPlannedEnd = DateTime(2026, 8, 25, 12, 0).millisecondsSinceEpoch;

      // Insert an abandoned session from yesterday
      await db.insert('zone_sessions', {
        'id': 'abandoned_1',
        'zoneId': 'work_zone',
        'startedAt': yesterdayStart,
        'endedAt': null, // Left open when app was killed!
        'plannedEndAt': yesterdayPlannedEnd,
        'source': 'SCHEDULE',
        'createdAt': yesterdayStart,
      });

      final todayNow = DateTime(2026, 8, 26, 8, 0);
      final recoveredCount = await writer.recoverAbandonedSessions(now: todayNow, executor: db);

      expect(recoveredCount, 1);

      final session = await repo.getSessionById('abandoned_1', executor: db);
      expect(session, isNotNull);
      expect(session!.isOpen, isFalse);
      expect(session.endedAt, yesterdayPlannedEnd);
      expect(session.endReason, ZoneEndReason.abandoned);
    });
  });
}
