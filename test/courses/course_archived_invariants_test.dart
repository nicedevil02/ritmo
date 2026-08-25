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

  group('Task 1 (N1) - Course Archiving & Partitioning Invariants', () {
    test('Invariant: getActiveCourses + getCompletedCourses + getArchivedCourses partitions all courses', () async {
      final db = await openDatabase(inMemoryDatabasePath, version: 1);
      await SystemTables.create(db);
      await CourseTables.create(db);
      await CourseTables.ensureSchema(db);

      final repo = CoursesRepository.instance;
      repo.overrideDatabaseForTesting(db);

      final now = DateTime.now().millisecondsSinceEpoch;

      // Permutations of status (ACTIVE, PAUSED, COMPLETED) x isArchived (0, 1)
      final testCases = [
        {'id': 'c_act_unarch', 'status': 'ACTIVE', 'isArchived': 0},
        {'id': 'c_act_arch', 'status': 'ACTIVE', 'isArchived': 1},
        {'id': 'c_pau_unarch', 'status': 'PAUSED', 'isArchived': 0},
        {'id': 'c_pau_arch', 'status': 'PAUSED', 'isArchived': 1},
        {'id': 'c_com_unarch', 'status': 'COMPLETED', 'isArchived': 0},
        {'id': 'c_com_arch', 'status': 'COMPLETED', 'isArchived': 1},
      ];

      for (final tc in testCases) {
        await db.insert('courses', {
          'id': tc['id'],
          'title': 'Course ${tc['id']}',
          'totalSessions': 5,
          'sessionDurationMinutes': 45,
          'activityType': 'STUDY',
          'status': tc['status'],
          'isArchived': tc['isArchived'],
          'createdAt': now,
          'updatedAt': now,
          'courseType': 'VIDEO',
          'weeklyTargetSessions': 3,
        });
      }

      final active = await repo.getActiveCourses();
      final completed = await repo.getCompletedCourses();
      final archived = await repo.getArchivedCourses();

      final allIds = <String>{
        ...active.map((c) => c.id),
        ...completed.map((c) => c.id),
        ...archived.map((c) => c.id),
      };

      // 1. Invariant: Total count equals total rows
      expect(allIds.length, equals(testCases.length));
      expect(active.length + completed.length + archived.length, equals(testCases.length));

      // 2. Invariant: No overlaps between lists
      final activeIds = active.map((c) => c.id).toSet();
      final completedIds = completed.map((c) => c.id).toSet();
      final archivedIds = archived.map((c) => c.id).toSet();

      expect(activeIds.intersection(completedIds), isEmpty);
      expect(activeIds.intersection(archivedIds), isEmpty);
      expect(completedIds.intersection(archivedIds), isEmpty);

      // Verify specific memberships
      expect(activeIds, containsAll(['c_act_unarch', 'c_pau_unarch']));
      expect(completedIds, containsAll(['c_com_unarch']));
      expect(archivedIds, containsAll(['c_act_arch', 'c_pau_arch', 'c_com_arch']));

      repo.overrideDatabaseForTesting(null);
      await db.close();
    });

    test('Restore archived PAUSED course with pending sessions restores to ACTIVE', () async {
      final db = await openDatabase(inMemoryDatabasePath, version: 1);
      await SystemTables.create(db);
      await CourseTables.create(db);
      await CourseTables.ensureSchema(db);

      final repo = CoursesRepository.instance;
      repo.overrideDatabaseForTesting(db);

      final now = DateTime.now().millisecondsSinceEpoch;

      await db.insert('courses', {
        'id': 'c_paused_arch',
        'title': 'Paused Archived Course',
        'totalSessions': 3,
        'sessionDurationMinutes': 45,
        'activityType': 'STUDY',
        'status': 'PAUSED',
        'isArchived': 1,
        'createdAt': now,
        'updatedAt': now,
        'courseType': 'VIDEO',
        'weeklyTargetSessions': 3,
      });

      // Insert pending sessions
      for (var i = 1; i <= 3; i++) {
        await db.insert('course_sessions', {
          'id': 'sess_p_$i',
          'courseId': 'c_paused_arch',
          'sessionNumber': i,
          'displayOrder': i,
          'completionStatus': 'PENDING',
          'createdAt': now,
          'updatedAt': now,
        });
      }

      // Check it is in archived courses initially
      var archived = await repo.getArchivedCourses();
      expect(archived.map((c) => c.id), contains('c_paused_arch'));

      var active = await repo.getActiveCourses();
      expect(active.map((c) => c.id), isNot(contains('c_paused_arch')));

      // Restore course
      final result = await repo.restoreCourse('c_paused_arch');
      expect(result.isApplied, isTrue);

      // Verify it moved from archived to active
      archived = await repo.getArchivedCourses();
      expect(archived.map((c) => c.id), isNot(contains('c_paused_arch')));

      active = await repo.getActiveCourses();
      expect(active.map((c) => c.id), contains('c_paused_arch'));
      final restoredCourse = active.firstWhere((c) => c.id == 'c_paused_arch');
      expect(restoredCourse.status, equals(CourseStatus.active));
      expect(restoredCourse.isArchived, isFalse);

      repo.overrideDatabaseForTesting(null);
      await db.close();
    });
  });
}
