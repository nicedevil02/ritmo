import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/schema/tables/course_tables.dart';
import 'package:ritmo/core/database/schema/tables/system_tables.dart';
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

  group('Task 3 (N3) - SM-2 Review Sessions Sync & Cap', () {
    test('CourseLimits defines maxActiveReviewSessions = 10', () {
      expect(CourseLimits.maxActiveReviewSessions, equals(10));
    });

    test('completeSession creates review session and atomically syncs courses.totalSessions', () async {
      final db = await openDatabase(inMemoryDatabasePath, version: 1);
      await SystemTables.create(db);
      await CourseTables.create(db);
      await CourseTables.ensureSchema(db);

      final repo = CoursesRepository.instance;
      repo.overrideDatabaseForTesting(db);

      final now = DateTime.now().millisecondsSinceEpoch;

      await db.insert('courses', {
        'id': 'c_sm2_test',
        'title': 'SM2 Sync Test',
        'totalSessions': 2,
        'sessionDurationMinutes': 45,
        'activityType': 'STUDY',
        'status': 'ACTIVE',
        'isArchived': 0,
        'reviewEnabled': 1,
        'createdAt': now,
        'updatedAt': now,
        'courseType': 'VIDEO',
        'weeklyTargetSessions': 3,
      });

      await db.insert('course_sessions', {
        'id': 'sess_1',
        'courseId': 'c_sm2_test',
        'sessionNumber': 1,
        'displayOrder': 1,
        'completionStatus': 'PENDING',
        'createdAt': now,
        'updatedAt': now,
      });
      await db.insert('course_sessions', {
        'id': 'sess_2',
        'courseId': 'c_sm2_test',
        'sessionNumber': 2,
        'displayOrder': 2,
        'completionStatus': 'PENDING',
        'createdAt': now,
        'updatedAt': now,
      });

      // Complete session 1 with understandingScore = 1 (triggers review session)
      final res = await repo.completeSession(
        sessionId: 'sess_1',
        actualDurationMinutes: 45,
        understandingScore: 1,
        needsReview: true,
      );
      expect(res.isApplied, isTrue);

      // Verify review session was inserted
      final allSessions = await repo.getSessionsForCourse('c_sm2_test');
      expect(allSessions.length, equals(3));
      final reviewSession = allSessions.firstWhere((s) => s.isReview);
      expect(reviewSession.sourceSessionId, equals('sess_1'));

      // Verify courses.totalSessions was synced to 3 in DB
      final course = await repo.getCourseById('c_sm2_test');
      expect(course!.totalSessions, equals(3));

      // Uncomplete session 1 -> should remove the pending review session and restore totalSessions to 2
      final uncompleteRes = await repo.uncompleteSession('sess_1');
      expect(uncompleteRes.isApplied, isTrue);

      final postUncompleteSessions = await repo.getSessionsForCourse('c_sm2_test');
      expect(postUncompleteSessions.length, equals(2));
      expect(postUncompleteSessions.any((s) => s.isReview), isFalse);

      final courseAfterUncomplete = await repo.getCourseById('c_sm2_test');
      expect(courseAfterUncomplete!.totalSessions, equals(2));

      repo.overrideDatabaseForTesting(null);
      await db.close();
    });

    test('Does not create duplicate open review session if one is already pending', () async {
      final db = await openDatabase(inMemoryDatabasePath, version: 1);
      await SystemTables.create(db);
      await CourseTables.create(db);
      await CourseTables.ensureSchema(db);

      final repo = CoursesRepository.instance;
      repo.overrideDatabaseForTesting(db);

      final now = DateTime.now().millisecondsSinceEpoch;

      await db.insert('courses', {
        'id': 'c_dup_test',
        'title': 'Duplicate Review Test',
        'totalSessions': 1,
        'sessionDurationMinutes': 45,
        'activityType': 'STUDY',
        'status': 'ACTIVE',
        'isArchived': 0,
        'reviewEnabled': 1,
        'createdAt': now,
        'updatedAt': now,
        'courseType': 'VIDEO',
        'weeklyTargetSessions': 3,
      });

      await db.insert('course_sessions', {
        'id': 'sess_orig',
        'courseId': 'c_dup_test',
        'sessionNumber': 1,
        'displayOrder': 1,
        'completionStatus': 'PENDING',
        'createdAt': now,
        'updatedAt': now,
      });

      // Complete once -> creates 1 review session
      await repo.completeSession(
        sessionId: 'sess_orig',
        actualDurationMinutes: 45,
        understandingScore: 2,
        needsReview: true,
      );

      var sessions = await repo.getSessionsForCourse('c_dup_test');
      expect(sessions.length, equals(2));

      // Completing again with same source session while review is pending should NOT create another review
      await repo.completeSession(
        sessionId: 'sess_orig',
        actualDurationMinutes: 45,
        understandingScore: 2,
        needsReview: true,
      );

      sessions = await repo.getSessionsForCourse('c_dup_test');
      expect(sessions.length, equals(2));

      repo.overrideDatabaseForTesting(null);
      await db.close();
    });
  });
}
