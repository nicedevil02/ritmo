import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/schema/tables/konkur_tables.dart';
import 'package:ritmo/core/timer/ritmo_timer_hub.dart';
import 'package:ritmo/features/study/data/study_active_session_dao.dart';
import 'package:ritmo/features/study/data/study_repository.dart';
import 'package:ritmo/features/study/domain/study_models.dart';
import 'package:ritmo/features/study/logic/study_timer_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;
  late StudyActiveSessionDao dao;
  late StudyRepository repo;
  late StudyTimerService service;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await KonkurTables.create(db);
        },
      ),
    );

    final dbHelper = DatabaseHelper.instance;
    dbHelper.overrideDatabaseForTesting(db);

    dao = StudyActiveSessionDao(dbHelper: dbHelper);
    repo = StudyRepository(dbHelper: dbHelper);
    service = StudyTimerService(dao: dao, repo: repo);
  });

  tearDown(() async {
    service.reset();
    await db.close();
  });

  group('StudyTimerService & SQLite Schema Integration Tests', () {
    test('KonkurTables.create creates study_active_session table successfully', () async {
      final rows = await db.query('study_active_session');
      expect(rows, isEmpty);
    });

    test('KonkurTables.ensureSchema ensures study_active_session exists if missing', () async {
      await db.execute('DROP TABLE study_active_session;');
      await KonkurTables.ensureSchema(db);

      final rows = await db.query('study_active_session');
      expect(rows, isEmpty);
    });

    test('startSession inserts active session into DB and registers in RitmoTimerHub', () async {
      const subject = StudySubject(id: 'sub_math', name: 'ریاضی');
      await repo.saveSubject(subject);

      await service.startSession(
        subjectId: 'sub_math',
        mode: StudyMode.learn,
        targetSeconds: 1500,
      );

      expect(service.hasActiveSession, isTrue);
      expect(service.isRunning, isTrue);
      expect(service.currentSession?.subjectId, 'sub_math');
      expect(service.currentSession?.targetSeconds, 1500);

      // Verify in DB
      final activeInDb = await dao.getActiveSession();
      expect(activeInDb, isNotNull);
      expect(activeInDb?.subjectId, 'sub_math');

      // Verify in RitmoTimerHub
      final hubSession = RitmoTimerHub.instance.currentSession;
      expect(hubSession, isNotNull);
      expect(hubSession?.id, 'study_sub_math');
      expect(hubSession?.domain, RitmoTimerDomain.study);
      expect(hubSession?.mode, RitmoTimerMode.pomodoroFocus);
    });

    test('pauseSession and resumeSession update active state and persist to DB', () async {
      await service.startSession(
        subjectId: 'sub_physics',
        targetSeconds: 1500,
      );

      await service.pauseSession();
      expect(service.isRunning, isFalse);
      expect(service.currentSession?.isPaused, isTrue);

      final pausedInDb = await dao.getActiveSession();
      expect(pausedInDb?.isPaused, isTrue);

      await service.resumeSession();
      expect(service.isRunning, isTrue);
      expect(service.currentSession?.isPaused, isFalse);

      final resumedInDb = await dao.getActiveSession();
      expect(resumedInDb?.isPaused, isFalse);
    });

    test('switchPomodoroPhase transitions from FOCUS to BREAK cleanly', () async {
      await service.startSession(
        subjectId: 'sub_chem',
        pomodoroPhase: 'FOCUS',
        pomodoroCycle: 1,
        targetSeconds: 1500,
      );

      await service.switchPomodoroPhase(
        phase: 'BREAK',
        nextCycle: 1,
        targetSeconds: 300,
      );

      expect(service.currentSession?.pomodoroPhase, 'BREAK');
      expect(service.currentSession?.targetSeconds, 300);
      expect(service.currentSession?.isBreak, isTrue);

      final hubSession = RitmoTimerHub.instance.currentSession;
      expect(hubSession?.mode, RitmoTimerMode.pomodoroBreak);
    });

    test('stopAndSaveSession records StudySession in DB and clears active timer', () async {
      const subject = StudySubject(id: 'sub_bio', name: 'زیست');
      await repo.saveSubject(subject);

      await service.startSession(
        subjectId: 'sub_bio',
        targetSeconds: 1500,
      );

      await service.stopAndSaveSession(
        overrideDurationMinutes: 25,
        note: 'مرور فصل ۱',
        testsTotal: 10,
        testsCorrect: 8,
        testsWrong: 2,
      );

      expect(service.hasActiveSession, isFalse);
      expect(await dao.getActiveSession(), isNull);
      expect(RitmoTimerHub.instance.hasActiveSession, isFalse);

      final sessions = await repo.getSessions();
      expect(sessions.length, 1);
      expect(sessions.first.subjectId, 'sub_bio');
      expect(sessions.first.durationMinutes, 25);
      expect(sessions.first.testsTotal, 10);
      expect(sessions.first.testsCorrect, 8);
    });

    test('init restores active session and resumes ticker on startup', () async {
      const sessionState = ActiveStudySessionState(
        id: 'singleton',
        subjectId: 'sub_lit',
        startedAtMs: 1000,
        accumulatedSeconds: 50,
        isPaused: false,
        pomodoroPhase: 'FOCUS',
        pomodoroCycle: 2,
        targetSeconds: 1500,
        createdAtMs: 1000,
      );
      await dao.saveActiveSession(sessionState);

      final newService = StudyTimerService(dao: dao, repo: repo);
      await newService.init();

      expect(newService.hasActiveSession, isTrue);
      expect(newService.isRunning, isTrue);
      expect(newService.currentSession?.subjectId, 'sub_lit');
      expect(newService.currentSession?.pomodoroCycle, 2);
      expect(RitmoTimerHub.instance.hasActiveSession, isTrue);

      newService.reset();
    });
  });
}
