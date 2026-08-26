import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/schema/tables/course_tables.dart';
import 'package:ritmo/core/database/schema/tables/system_tables.dart';
import 'package:ritmo/features/courses/logic/course_adaptive_engine.dart';
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

  group('Courses Hardening v2 - Complete Execution Verification', () {
    late Database db;
    late CoursesRepository repo;

    setUp(() async {
      db = await openDatabase(inMemoryDatabasePath, version: 1);
      await SystemTables.create(db);
      await CourseTables.create(db);
      await CourseTables.ensureSchema(db);

      repo = CoursesRepository.instance;
      repo.overrideDatabaseForTesting(db);
    });

    tearDown(() async {
      repo.overrideDatabaseForTesting(null);
      await db.close();
    });

    test('createCourse returns ScheduleResult and records unscheduled sessions if any', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final course = Course(
        id: 'c_n2_test',
        title: 'N2 Scheduling Course',
        totalSessions: 12,
        sessionDurationMinutes: 45,
        weeklyTargetSessions: 3,
        preferredDays: [6, 1, 3], // 3 days per week
        courseType: CourseType.video,
        createdAt: now,
        updatedAt: now,
      );

      final scheduleResult = await repo.createCourse(course);
      expect(scheduleResult.dates.length, equals(12));
      expect(scheduleResult.unscheduledCount, equals(0));
      expect(scheduleResult.isFullyScheduled, isTrue);

      final createdSessions = await repo.getSessionsForCourse('c_n2_test');
      expect(createdSessions.length, equals(12));
      expect(createdSessions.every((s) => s.plannedDate != null), isTrue);
    });

    test('rescheduleCoursePendingSessions reschedules all pending sessions', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final course = Course(
        id: 'c_resched_test',
        title: 'Reschedule Course',
        totalSessions: 4,
        sessionDurationMinutes: 45,
        weeklyTargetSessions: 2,
        preferredDays: [6, 1],
        courseType: CourseType.video,
        createdAt: now,
        updatedAt: now,
      );

      await repo.createCourse(course);

      // Manually un-schedule session 3 and 4
      await db.update('course_sessions', {'plannedDate': null}, where: 'sessionNumber IN (3, 4)');

      var sessions = await repo.getSessionsForCourse('c_resched_test');
      expect(sessions.where((s) => s.plannedDate == null).length, equals(2));

      // Trigger reschedule
      final res = await repo.rescheduleCoursePendingSessions('c_resched_test');
      expect(res.isApplied, isTrue);

      sessions = await repo.getSessionsForCourse('c_resched_test');
      expect(sessions.every((s) => s.plannedDate != null), isTrue);
    });

    test('updateCourse session reduction is consistent with actual existing sessions', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final course = Course(
        id: 'c_shrink_test',
        title: 'Shrink Course',
        totalSessions: 5,
        sessionDurationMinutes: 45,
        weeklyTargetSessions: 2,
        preferredDays: [6, 1],
        courseType: CourseType.video,
        createdAt: now,
        updatedAt: now,
      );

      await repo.createCourse(course);
      var sessions = await repo.getSessionsForCourse('c_shrink_test');
      expect(sessions.length, equals(5));

      // Reduce totalSessions from 5 to 3
      final updated = course.copyWith(totalSessions: 3);
      final res = await repo.updateCourse(updated);
      expect(res.isApplied, isTrue);

      sessions = await repo.getSessionsForCourse('c_shrink_test');
      expect(sessions.length, equals(3));
    });

    test('Adaptive proposal and 24h rollback work end-to-end', () async {
      final now = DateTime.now();
      final course = Course(
        id: 'c_adapt_test',
        title: 'Adaptive Course',
        totalSessions: 10,
        sessionDurationMinutes: 45,
        weeklyTargetSessions: 4,
        preferredDays: [6, 0, 1, 2],
        isAdaptive: true,
        courseType: CourseType.video,
        createdAt: now.millisecondsSinceEpoch,
        updatedAt: now.millisecondsSinceEpoch,
      );

      await repo.createCourse(course);

      // Manually set 7 sessions overdue (planned in past)
      const pastDateStr = '2026-08-01';
      await db.update(
        'course_sessions',
        {'plannedDate': pastDateStr, 'completionStatus': SessionStatus.pending.dbValue},
        where: 'courseId = ? AND sessionNumber <= 7',
        whereArgs: ['c_adapt_test'],
      );

      final sessions = await repo.getSessionsForCourse('c_adapt_test');
      final proposal = CourseAdaptiveEngine.proposeAdjustment(course: course, sessions: sessions, today: now);
      expect(proposal, isNotNull);
      expect(proposal!.newWeeklyTarget, equals(3)); // reduced from 4 to 3

      // Apply adjustment
      await CourseAdaptiveEngine.applyAdjustment(course, proposal);

      final updatedCourse = await repo.getCourseById('c_adapt_test');
      expect(updatedCourse!.weeklyTargetSessions, equals(3));
      expect(updatedCourse.adaptiveLastAppliedAt, isNotNull);

      // Rollback adjustment
      final rollbackResult = await repo.rollbackAdaptiveAdjustment('c_adapt_test');
      expect(rollbackResult.isApplied, isTrue);

      final rolledBackCourse = await repo.getCourseById('c_adapt_test');
      expect(rolledBackCourse!.weeklyTargetSessions, equals(4)); // restored back to 4
    });
  });
}
