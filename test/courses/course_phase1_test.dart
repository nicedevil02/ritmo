import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/schema/tables/course_tables.dart';
import 'package:ritmo/core/util/ritmo_number.dart';
import 'package:ritmo/features/courses/models/course_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Phase 1 Tests (K-06 to K-13)', () {
    test('K-08: Persian & Arabic digit parsing with RitmoNumber.toEn and range limits', () {
      final faNum = RitmoNumber.toEn('۱۲');
      final arNum = RitmoNumber.toEn('٣٤');
      final mixed = RitmoNumber.toEn('  ۵۰  ');

      expect(int.tryParse(faNum), equals(12));
      expect(int.tryParse(arNum), equals(34));
      expect(int.tryParse(mixed), equals(50));

      expect(12 >= CourseLimits.minTotalSessions && 12 <= CourseLimits.maxTotalSessions, isTrue);
      expect(0 >= CourseLimits.minTotalSessions, isFalse);
      expect(600 <= CourseLimits.maxSessionDurationMinutes, isTrue);
    });

    test('K-09: CourseEnergyLevel and CourseEnergyRule enum mapping', () {
      expect(CourseEnergyLevelExtension.fromString('HIGH'), equals(CourseEnergyLevel.high));
      expect(CourseEnergyLevelExtension.fromString('LOW'), equals(CourseEnergyLevel.low));
      expect(CourseEnergyLevelExtension.fromString('unknown'), equals(CourseEnergyLevel.medium));

      expect(CourseEnergyRuleExtension.fromString('MEDIUM_OR_HIGH'), equals(CourseEnergyRule.mediumOrHigh));
      expect(CourseEnergyRuleExtension.fromString('HIGH_ONLY'), equals(CourseEnergyRule.highOnly));
      expect(CourseEnergyRuleExtension.fromString('NONE'), equals(CourseEnergyRule.all));
    });

    test('K-10: CourseMutationResult status checks', () {
      const applied = CourseMutationResult.applied;
      const notFound = CourseMutationResult.notFound;
      const noOp = CourseMutationResult.noOp;

      expect(applied.isApplied, isTrue);
      expect(applied.isNotFound, isFalse);
      expect(notFound.isNotFound, isTrue);
      expect(noOp.isNoOp, isTrue);
    });

    test('K-12 & K-13: CourseTables.ensureSchema creates tables and indexes safely, and reorder negation works', () async {
      final db = await openDatabase(inMemoryDatabasePath, version: 1);

      // Self-healing schema validation
      await CourseTables.create(db);
      await CourseTables.ensureSchema(db);

      // Verify courses and course_sessions exist
      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      final tableNames = tables.map((t) => t['name'] as String).toSet();

      expect(tableNames.contains('courses'), isTrue);
      expect(tableNames.contains('course_sessions'), isTrue);
      expect(tableNames.contains('course_active_timers'), isTrue);
      expect(tableNames.contains('study_active_session'), isTrue);

      // Insert course & sessions
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert('courses', {
        'id': 'test_course_1',
        'title': 'Test Course',
        'totalSessions': 3,
        'sessionDurationMinutes': 45,
        'activityType': 'STUDY',
        'createdAt': now,
        'updatedAt': now,
        'courseType': 'VIDEO',
        'weeklyTargetSessions': 3,
        'preferredDays': '6,1,3',
      });

      for (var i = 1; i <= 3; i++) {
        await db.insert('course_sessions', {
          'id': 'sess_$i',
          'courseId': 'test_course_1',
          'sessionNumber': i,
          'displayOrder': i,
          'completionStatus': 'PENDING',
          'createdAt': now,
          'updatedAt': now,
        });
      }

      // Reorder sessions with two-step negation (reverse order: 3, 2, 1)
      final newOrder = ['sess_3', 'sess_2', 'sess_1'];
      await db.transaction((txn) async {
        // Step 1: negate
        await txn.rawUpdate('''
          UPDATE course_sessions 
          SET sessionNumber = -sessionNumber, displayOrder = -displayOrder 
          WHERE courseId = ?
        ''', ['test_course_1']);

        // Step 2: assign positive target numbers
        for (var idx = 0; idx < newOrder.length; idx++) {
          final sId = newOrder[idx];
          final newNum = idx + 1;
          await txn.update(
            'course_sessions',
            {'sessionNumber': newNum, 'displayOrder': newNum},
            where: 'id = ? AND courseId = ?',
            whereArgs: [sId, 'test_course_1'],
          );
        }
      });

      // Verify sessions are in new order without duplicate key conflict
      final updatedSessions = await db.query('course_sessions', where: 'courseId = ?', whereArgs: ['test_course_1'], orderBy: 'displayOrder ASC');
      expect(updatedSessions.length, equals(3));
      expect(updatedSessions[0]['id'], equals('sess_3'));
      expect(updatedSessions[0]['sessionNumber'], equals(1));
      expect(updatedSessions[1]['id'], equals('sess_2'));
      expect(updatedSessions[1]['sessionNumber'], equals(2));
      expect(updatedSessions[2]['id'], equals('sess_1'));
      expect(updatedSessions[2]['sessionNumber'], equals(3));

      await db.close();
    });

    test('M1: CourseTables.ensureSchema standalone creation creates tables with valid schema', () async {
      final db = await openDatabase(inMemoryDatabasePath, version: 1);

      // Self-healing schema validation alone
      await CourseTables.ensureSchema(db);

      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      final tableNames = tables.map((t) => t['name'] as String).toSet();

      expect(tableNames.contains('courses'), isTrue);
      expect(tableNames.contains('course_sessions'), isTrue);
      expect(tableNames.contains('course_active_timers'), isTrue);

      await db.close();
    });
  });
}
