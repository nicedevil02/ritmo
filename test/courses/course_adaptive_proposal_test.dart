import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/schema/tables/course_tables.dart';
import 'package:ritmo/core/database/schema/tables/system_tables.dart';
import 'package:ritmo/features/courses/logic/course_adaptive_engine.dart';
import 'package:ritmo/features/courses/logic/course_validation.dart';
import 'package:ritmo/features/courses/logic/courses_repository.dart';
import 'package:ritmo/features/courses/models/course_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Task 4 (H3) - Course Adaptive Proposals & 24h Rollback', () {
    test('evaluateAndAdjustCourse with default autoApply=false does NOT modify DB', () async {
      final db = await openDatabase(inMemoryDatabasePath, version: 1);
      await SystemTables.create(db);
      await CourseTables.create(db);
      await CourseTables.ensureSchema(db);

      final repo = CoursesRepository.instance;
      repo.overrideDatabaseForTesting(db);

      final now = DateTime.now().millisecondsSinceEpoch;
      final today = DateTime(2026, 8, 20);

      await db.insert('courses', {
        'id': 'c_adapt_1',
        'title': 'Adaptive Course 1',
        'totalSessions': 10,
        'sessionDurationMinutes': 45,
        'activityType': 'STUDY',
        'status': 'ACTIVE',
        'isArchived': 0,
        'isAdaptive': 1,
        'createdAt': now,
        'updatedAt': now,
        'courseType': 'VIDEO',
        'weeklyTargetSessions': 5,
        'preferredDays': '6,1,3',
      });

      // 6 overdue pending sessions
      final sessions = <CourseSession>[];
      for (var i = 1; i <= 6; i++) {
        final sess = CourseSession(
          id: 'sess_overdue_$i',
          courseId: 'c_adapt_1',
          sessionNumber: i,
          displayOrder: i,
          plannedDate: '2026-08-0$i',
          completionStatus: SessionStatus.pending,
          createdAt: now,
          updatedAt: now,
        );
        sessions.add(sess);
        await db.insert('course_sessions', sess.toMap());
      }

      final course = (await repo.getCourseById('c_adapt_1'))!;

      // Evaluate without autoApply (default autoApply = false)
      final proposal = await CourseAdaptiveEngine.evaluateAndAdjustCourse(
        course: course,
        sessions: sessions,
        today: today,
      );

      expect(proposal, isNotNull);
      expect(proposal!.newWeeklyTarget, equals(4)); // reduced from 5

      // Check DB course was NOT modified
      final unmodifiedCourse = (await repo.getCourseById('c_adapt_1'))!;
      expect(unmodifiedCourse.weeklyTargetSessions, equals(5));
      expect(unmodifiedCourse.adaptiveLastAppliedAt, isNull);

      repo.overrideDatabaseForTesting(null);
      await db.close();
    });

    test('applyAdjustment saves snapshot and rollbackAdaptiveAdjustment restores state within 24h', () async {
      final db = await openDatabase(inMemoryDatabasePath, version: 1);
      await SystemTables.create(db);
      await CourseTables.create(db);
      await CourseTables.ensureSchema(db);

      final repo = CoursesRepository.instance;
      repo.overrideDatabaseForTesting(db);

      final now = DateTime.now().millisecondsSinceEpoch;
      final today = DateTime(2026, 8, 20);

      await db.insert('courses', {
        'id': 'c_adapt_2',
        'title': 'Adaptive Course 2',
        'totalSessions': 4,
        'sessionDurationMinutes': 45,
        'activityType': 'STUDY',
        'status': 'ACTIVE',
        'isArchived': 0,
        'isAdaptive': 1,
        'createdAt': now,
        'updatedAt': now,
        'courseType': 'VIDEO',
        'weeklyTargetSessions': 4,
        'preferredDays': '6,1,3',
      });

      for (var i = 1; i <= 4; i++) {
        await db.insert('course_sessions', {
          'id': 'sess_a2_$i',
          'courseId': 'c_adapt_2',
          'sessionNumber': i,
          'displayOrder': i,
          'plannedDate': '2026-08-0$i',
          'completionStatus': 'PENDING',
          'createdAt': now,
          'updatedAt': now,
        });
      }

      final course = (await repo.getCourseById('c_adapt_2'))!;
      final sessions = await repo.getSessionsForCourse('c_adapt_2');

      final proposal = CourseAdaptiveEngine.proposeAdjustment(
        course: course,
        sessions: sessions,
        today: today,
      );

      // Apply adjustment
      await CourseAdaptiveEngine.applyAdjustment(course, proposal!);

      final updatedCourse = (await repo.getCourseById('c_adapt_2'))!;
      expect(updatedCourse.weeklyTargetSessions, equals(3));
      expect(updatedCourse.adaptiveLastAppliedAt, isNotNull);

      // Verify snapshot was created in course_adaptive_snapshots
      final snaps = await db.query('course_adaptive_snapshots', where: 'courseId = ?', whereArgs: ['c_adapt_2']);
      expect(snaps.length, equals(1));
      expect(snaps.first['oldWeeklyTarget'], equals(4));
      expect(snaps.first['newWeeklyTarget'], equals(3));

      // Rollback adjustment within 24h
      final rollbackRes = await repo.rollbackAdaptiveAdjustment('c_adapt_2');
      expect(rollbackRes.isApplied, isTrue);

      final restoredCourse = (await repo.getCourseById('c_adapt_2'))!;
      expect(restoredCourse.weeklyTargetSessions, equals(4)); // Restored!

      final restoredSessions = await repo.getSessionsForCourse('c_adapt_2');
      expect(restoredSessions[0].plannedDate, equals('2026-08-01')); // Restored original plannedDate!

      // Verify snapshot was cleaned up
      final snapsAfterRollback = await db.query('course_adaptive_snapshots', where: 'courseId = ?', whereArgs: ['c_adapt_2']);
      expect(snapsAfterRollback, isEmpty);

      repo.overrideDatabaseForTesting(null);
      await db.close();
    });

    test('rollbackAdaptiveAdjustment throws ROLLBACK_EXPIRED after 24 hours', () async {
      final db = await openDatabase(inMemoryDatabasePath, version: 1);
      await SystemTables.create(db);
      await CourseTables.create(db);
      await CourseTables.ensureSchema(db);

      final repo = CoursesRepository.instance;
      repo.overrideDatabaseForTesting(db);

      final now = DateTime.now().millisecondsSinceEpoch;
      // 25 hours ago
      final oldTime = now - (25 * 60 * 60 * 1000);

      await db.insert('courses', {
        'id': 'c_expired_snap',
        'title': 'Expired Snapshot Course',
        'totalSessions': 2,
        'sessionDurationMinutes': 45,
        'activityType': 'STUDY',
        'status': 'ACTIVE',
        'isArchived': 0,
        'createdAt': oldTime,
        'updatedAt': oldTime,
        'courseType': 'VIDEO',
        'weeklyTargetSessions': 2,
      });

      await db.insert('course_adaptive_snapshots', {
        'id': 'snap_expired',
        'courseId': 'c_expired_snap',
        'oldWeeklyTarget': 3,
        'newWeeklyTarget': 2,
        'snapshotJson': '[]',
        'createdAt': oldTime,
      });

      await expectLater(
        repo.rollbackAdaptiveAdjustment('c_expired_snap'),
        throwsA(isA<CourseValidationException>().having((e) => e.code, 'code', 'ROLLBACK_EXPIRED')),
      );

      repo.overrideDatabaseForTesting(null);
      await db.close();
    });
  });
}
