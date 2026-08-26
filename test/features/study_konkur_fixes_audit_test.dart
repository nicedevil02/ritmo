import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/features/goals/logic/goals_repository.dart';
import 'package:ritmo/features/study/data/study_repository.dart';
import 'package:ritmo/features/study/domain/study_models.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  final goalsRepo = GoalsRepository.instance;
  final studyRepo = StudyRepository.instance;

  setUp(() async {
    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE app_settings (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            );
          ''');
          await db.execute('''
            CREATE TABLE konkur_subjects (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              emoji TEXT,
              colorHex TEXT,
              weeklyTargetMinutes INTEGER NOT NULL DEFAULT 0,
              origin TEXT NOT NULL DEFAULT 'USER',
              isArchived INTEGER NOT NULL DEFAULT 0,
              orderIndex INTEGER NOT NULL DEFAULT 0,
              importanceFactor REAL NOT NULL DEFAULT 1.0,
              examQuestionCount INTEGER NOT NULL DEFAULT 0,
              subjectGroup TEXT NOT NULL DEFAULT 'SPECIALIZED',
              isPreset INTEGER NOT NULL DEFAULT 0,
              createdAt INTEGER NOT NULL,
              updatedAt INTEGER NOT NULL
            );
          ''');
          await db.execute('''
            CREATE TABLE konkur_topics (
              id TEXT PRIMARY KEY,
              subjectId TEXT NOT NULL,
              parentTopicId TEXT,
              name TEXT NOT NULL,
              masteryLevel TEXT NOT NULL DEFAULT 'NOT_STARTED',
              studyCompletedMinutes INTEGER NOT NULL DEFAULT 0,
              lastStudiedAt INTEGER,
              nextReviewDate TEXT,
              plannedDate TEXT,
              orderIndex INTEGER NOT NULL DEFAULT 0,
              origin TEXT NOT NULL DEFAULT 'USER',
              chapter TEXT,
              reviewCount INTEGER NOT NULL DEFAULT 0,
              createdAt INTEGER,
              updatedAt INTEGER
            );
          ''');
          await db.execute('''
            CREATE TABLE konkur_plan_items (
              id TEXT PRIMARY KEY,
              subjectId TEXT NOT NULL,
              topicId TEXT,
              title TEXT NOT NULL,
              isCompleted INTEGER NOT NULL DEFAULT 0,
              dateStr TEXT NOT NULL
            );
          ''');
          await db.execute('''
            CREATE TABLE konkur_study_sessions (
              id TEXT PRIMARY KEY,
              subjectId TEXT NOT NULL,
              topicId TEXT,
              durationMinutes INTEGER NOT NULL,
              dateIso TEXT NOT NULL,
              mode TEXT NOT NULL DEFAULT 'LEARN',
              source TEXT NOT NULL DEFAULT 'MANUAL',
              startedAtMs INTEGER,
              endedAtMs INTEGER,
              quality INTEGER,
              note TEXT,
              testsTotal INTEGER NOT NULL DEFAULT 0,
              testsCorrect INTEGER NOT NULL DEFAULT 0,
              testsWrong INTEGER NOT NULL DEFAULT 0,
              testsBlank INTEGER NOT NULL DEFAULT 0,
              createdAt INTEGER NOT NULL
            );
          ''');
          await db.execute('''
            CREATE TABLE study_active_session (
              id TEXT PRIMARY KEY,
              subjectId TEXT NOT NULL,
              topicId TEXT,
              mode TEXT NOT NULL DEFAULT 'LEARN',
              startedAtMs INTEGER NOT NULL,
              accumulatedSeconds INTEGER NOT NULL DEFAULT 0,
              phaseAccumulatedSeconds INTEGER NOT NULL DEFAULT 0,
              isPaused INTEGER NOT NULL DEFAULT 0,
              plannedMinutes INTEGER,
              pomodoroPhase TEXT NOT NULL DEFAULT 'FOCUS',
              pomodoroCycle INTEGER NOT NULL DEFAULT 1,
              targetSeconds INTEGER NOT NULL DEFAULT 1500,
              createdAt INTEGER NOT NULL
            );
          ''');
          await db.execute('''
            CREATE TABLE study_deadlines (
              id TEXT PRIMARY KEY,
              subjectId TEXT,
              title TEXT NOT NULL,
              deadlineType TEXT NOT NULL DEFAULT 'EXAM',
              dueDateIso TEXT NOT NULL,
              dueTime TEXT,
              priority TEXT NOT NULL DEFAULT 'MEDIUM',
              isCompleted INTEGER NOT NULL DEFAULT 0,
              weight REAL NOT NULL DEFAULT 1.0,
              note TEXT,
              createdAt INTEGER NOT NULL,
              updatedAt INTEGER NOT NULL
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

  group('Study & Konkur Isolation & Hardening Fixes (RITF-021 .. RITF-033)', () {
    test('RITF-021: GoalsRepository isolates Konkur subjects/topics from general study', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      // Insert 1 Konkur subject and 1 General Study subject
      await db.insert('konkur_subjects', {
        'id': 'sub_konkur_1',
        'name': 'فیزیک کنکور',
        'origin': 'KONKUR_PRESET',
        'isPreset': 1,
        'isArchived': 0,
        'createdAt': now,
        'updatedAt': now,
      });
      await db.insert('konkur_subjects', {
        'id': 'sub_study_user_1',
        'name': 'مطالعه آزاد تاریخ',
        'origin': 'USER',
        'isPreset': 0,
        'isArchived': 0,
        'createdAt': now,
        'updatedAt': now,
      });

      // Insert topics
      await db.insert('konkur_topics', {
        'id': 'top_konkur_1',
        'subjectId': 'sub_konkur_1',
        'name': 'حرکت شناسی',
        'origin': 'KONKUR_PRESET',
      });
      await db.insert('konkur_topics', {
        'id': 'top_study_1',
        'subjectId': 'sub_study_user_1',
        'name': 'تاریخ معاصر',
        'origin': 'USER',
      });

      final konkurSubjects = await goalsRepo.getKonkurSubjects();
      expect(konkurSubjects.length, equals(1));
      expect(konkurSubjects.first.id, equals('sub_konkur_1'));

      final konkurTopics = await goalsRepo.getKonkurTopics();
      expect(konkurTopics.length, equals(1));
      expect(konkurTopics.first.id, equals('top_konkur_1'));
    });

    test('RITF-024: StudyRepository respects isKonkurMode and defaults topic origin to USER', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert('konkur_subjects', {
        'id': 'sub_konkur_1',
        'name': 'شیمی کنکور',
        'origin': 'KONKUR_PRESET',
        'isPreset': 1,
        'isArchived': 0,
        'createdAt': now,
        'updatedAt': now,
      });
      await db.insert('konkur_subjects', {
        'id': 'sub_study_1',
        'name': 'برنامه‌نویسی',
        'origin': 'USER',
        'isPreset': 0,
        'isArchived': 0,
        'createdAt': now,
        'updatedAt': now,
      });

      final studySubjects = await studyRepo.getSubjects(isKonkurMode: false);
      expect(studySubjects.length, equals(1));
      expect(studySubjects.first.id, equals('sub_study_1'));

      final konkurSubjects = await studyRepo.getSubjects(isKonkurMode: true);
      expect(konkurSubjects.length, equals(1));
      expect(konkurSubjects.first.id, equals('sub_konkur_1'));

      // Save a new topic without specifying origin -> should default to USER
      const newTopic = StudyTopic(
        id: 'top_new_1',
        subjectId: 'sub_study_1',
        name: 'دارت و فلاتر',
      );
      await studyRepo.saveTopic(newTopic);

      final insertedRows = await db.query('konkur_topics', where: 'id = ?', whereArgs: ['top_new_1']);
      expect(insertedRows.first['origin'], equals('USER'));
    });

    test('RITF-025: StudyRepository.recordSession delta tracking prevents duplicate double counting', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert('konkur_subjects', {
        'id': 'sub_1',
        'name': 'ریاضی',
        'origin': 'USER',
        'createdAt': now,
        'updatedAt': now,
      });
      await db.insert('konkur_topics', {
        'id': 'top_1',
        'subjectId': 'sub_1',
        'name': 'مشتق',
        'studyCompletedMinutes': 0,
        'origin': 'USER',
      });

      final session1 = StudySession(
        id: 'sess_1',
        subjectId: 'sub_1',
        topicId: 'top_1',
        durationMinutes: 30,
        dateIso: '2026-08-27',
        createdAtMs: now,
      );

      // Record 30 minutes
      await studyRepo.recordSession(session1);
      var topic = await studyRepo.getTopicById('top_1');
      expect(topic?.studyCompletedMinutes, equals(30));

      // Retry/edit same session id with 45 minutes -> should be +15 delta = 45 total (not 30+45=75)
      final session1Updated = StudySession(
        id: 'sess_1',
        subjectId: 'sub_1',
        topicId: 'top_1',
        durationMinutes: 45,
        dateIso: '2026-08-27',
        createdAtMs: now,
      );
      await studyRepo.recordSession(session1Updated);
      topic = await studyRepo.getTopicById('top_1');
      expect(topic?.studyCompletedMinutes, equals(45));
    });

    test('RITF-026: StudyRepository.deleteSubject cascades to konkur_plan_items', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert('konkur_subjects', {
        'id': 'sub_del_1',
        'name': 'زیست‌شناسی',
        'origin': 'KONKUR_PRESET',
        'createdAt': now,
        'updatedAt': now,
      });
      await db.insert('konkur_plan_items', {
        'id': 'plan_1',
        'subjectId': 'sub_del_1',
        'title': 'فصل ۱ ژنتیک',
        'dateStr': '2026-08-27',
      });

      await studyRepo.deleteSubject('sub_del_1');

      final planItems = await db.query('konkur_plan_items', where: 'subjectId = ?', whereArgs: ['sub_del_1']);
      expect(planItems.isEmpty, isTrue);
    });

    test('RITF-027: StudyRepository.getAggregatedSubjectStats isolates stats by mode', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert('konkur_subjects', {
        'id': 'sub_konkur_stat',
        'name': 'ادبیات کنکور',
        'origin': 'KONKUR_PRESET',
        'createdAt': now,
        'updatedAt': now,
      });
      await db.insert('konkur_subjects', {
        'id': 'sub_study_stat',
        'name': 'زبان انگلیسی',
        'origin': 'USER',
        'createdAt': now,
        'updatedAt': now,
      });

      await db.insert('konkur_study_sessions', {
        'id': 'sess_k1',
        'subjectId': 'sub_konkur_stat',
        'durationMinutes': 60,
        'dateIso': '2026-08-27',
        'createdAt': now,
      });
      await db.insert('konkur_study_sessions', {
        'id': 'sess_s1',
        'subjectId': 'sub_study_stat',
        'durationMinutes': 40,
        'dateIso': '2026-08-27',
        'createdAt': now,
      });

      final studyStats = await studyRepo.getAggregatedSubjectStats(isKonkurMode: false);
      expect(studyStats.containsKey('sub_study_stat'), isTrue);
      expect(studyStats.containsKey('sub_konkur_stat'), isFalse);
      expect(studyStats['sub_study_stat']?.totalMinutes, equals(40));

      final konkurStats = await studyRepo.getAggregatedSubjectStats(isKonkurMode: true);
      expect(konkurStats.containsKey('sub_konkur_stat'), isTrue);
      expect(konkurStats.containsKey('sub_study_stat'), isFalse);
      expect(konkurStats['sub_konkur_stat']?.totalMinutes, equals(60));
    });

    test('RITF-028: StudyDeadline.daysRemaining handles Jalali and Gregorian day keys correctly', () {
      final nowGregorian = DateTime(2026, 8, 27);
      // Gregorian deadline in 5 days
      final deadlineGregorian = StudyDeadline(
        id: 'd1',
        title: 'امتحان ریاضی',
        dueDateIso: '2026-09-01',
        createdAtMs: 0,
        updatedAtMs: 0,
      );
      expect(deadlineGregorian.daysRemaining(nowGregorian), equals(5));

      // Jalali deadline test (1405-06-10 vs 1405-06-05)
      final jalaliToday = Jalali(1405, 6, 5).toDateTime();
      final deadlineJalali = StudyDeadline(
        id: 'd2',
        title: 'کنکور آزمایشی',
        dueDateIso: '1405-06-10',
        createdAtMs: 0,
        updatedAtMs: 0,
      );
      expect(deadlineJalali.daysRemaining(jalaliToday), equals(5));
    });
  });
}
