import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/schema/schema_manager.dart';
import 'package:ritmo/features/courses/logic/course_date_contract.dart';
import 'package:ritmo/features/courses/logic/course_timer_service.dart';
import 'package:ritmo/features/courses/logic/courses_repository.dart';
import 'package:ritmo/features/courses/models/course_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});

    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await SchemaManager.createAll(db);
        },
      ),
    );

    await DatabaseHelper.ensureCriticalSchema(db);
    DatabaseHelper.instance.overrideDatabaseForTesting(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Courses Module Fixes Audit (RITF-089 .. RITF-090)', () {
    test('RITF-089: CourseDate.parseDayKey handles malformed dates gracefully', () {
      expect(CourseDate.parseDayKey('2026-08-27'), DateTime(2026, 8, 27));
      expect(CourseDate.parseDayKey('2026-08-27T10:00:00Z'), DateTime(2026, 8, 27));
      expect(CourseDate.parseDayKey(''), isNull);
      expect(CourseDate.parseDayKey(null), isNull);
      expect(CourseDate.parseDayKey('invalid-date-string'), isNull);
      expect(CourseDate.parseDayKey('2026-99-99'), isNull);
    });

    test('RITF-089: SafeCourseColor.resolvedColor safely resolves diverse color formats', () {
      final course1 = Course(
        id: 'c1',
        title: 'Math',
        totalSessions: 10,
        sessionDurationMinutes: 45,
        courseType: CourseType.video,
        preferredDays: const [6, 1, 3],
        weeklyTargetSessions: 3,
        colorHex: '#3B82F6',
        createdAt: 0,
        updatedAt: 0,
      );
      expect(course1.resolvedColor(Colors.grey), const Color(0xFF3B82F6));

      final course2 = Course(
        id: 'c2',
        title: 'Physics',
        totalSessions: 10,
        sessionDurationMinutes: 45,
        courseType: CourseType.book,
        preferredDays: const [6, 1, 3],
        weeklyTargetSessions: 3,
        colorHex: '10B981',
        createdAt: 0,
        updatedAt: 0,
      );
      expect(course2.resolvedColor(Colors.grey), const Color(0xFF10B981));

      final course3 = Course(
        id: 'c3',
        title: 'Chemistry',
        totalSessions: 10,
        sessionDurationMinutes: 45,
        courseType: CourseType.custom,
        preferredDays: const [6, 1, 3],
        weeklyTargetSessions: 3,
        colorHex: 'invalid_hex',
        createdAt: 0,
        updatedAt: 0,
      );
      expect(course3.resolvedColor(Colors.red), Colors.red);
    });

    test('RITF-089: CoursesRepository & CourseTimerService use UpsertHelper', () async {
      final repo = CoursesRepository.instance;
      final now = DateTime.now();

      final course = Course(
        id: 'course_test_1',
        title: 'Flutter Advanced',
        totalSessions: 5,
        sessionDurationMinutes: 45,
        courseType: CourseType.video,
        weeklyTargetSessions: 3,
        preferredDays: const [6, 1, 3], // Sat, Mon, Wed
        preferredTime: '18:00',
        reminderEnabled: true,
        createdAt: now.millisecondsSinceEpoch,
        updatedAt: now.millisecondsSinceEpoch,
      );

      final result = await repo.createCourse(course);
      expect(result.dates.length, 5);

      final fetchedCourse = await repo.getCourseById('course_test_1');
      expect(fetchedCourse, isNotNull);
      expect(fetchedCourse!.title, 'Flutter Advanced');

      final timerService = CourseTimerService.instance;
      await timerService.startTimer('course_test_1', 'sess_test_1');
      expect(timerService.activeTimer, isNotNull);
      expect(timerService.activeTimer!.sessionId, 'sess_test_1');
      await timerService.stopTimer();
    });
  });
}
