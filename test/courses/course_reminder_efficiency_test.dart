import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/schema/tables/course_tables.dart';
import 'package:ritmo/core/database/schema/tables/system_tables.dart';
import 'package:ritmo/features/courses/logic/courses_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Task 6 (H7) - Reminder Efficiency & Point Rebuild', () {
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

    test('rescheduleSession updates only that session reminder without wiping other reminders', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final futureDate1 = DateTime.now().add(const Duration(days: 2));
      final futureDate2 = DateTime.now().add(const Duration(days: 4));
      final date1Str = '${futureDate1.year}-${futureDate1.month.toString().padLeft(2, '0')}-${futureDate1.day.toString().padLeft(2, '0')}';
      final date2Str = '${futureDate2.year}-${futureDate2.month.toString().padLeft(2, '0')}-${futureDate2.day.toString().padLeft(2, '0')}';

      await db.insert('courses', {
        'id': 'c_rem_test',
        'title': 'Reminder Test Course',
        'totalSessions': 2,
        'sessionDurationMinutes': 45,
        'activityType': 'STUDY',
        'status': 'ACTIVE',
        'isArchived': 0,
        'reminderEnabled': 1,
        'preferredTime': '18:00',
        'createdAt': now,
        'updatedAt': now,
        'courseType': 'VIDEO',
        'weeklyTargetSessions': 2,
      });

      await db.insert('course_sessions', {
        'id': 'sess_r1',
        'courseId': 'c_rem_test',
        'sessionNumber': 1,
        'displayOrder': 1,
        'plannedDate': date1Str,
        'completionStatus': 'PENDING',
        'createdAt': now,
        'updatedAt': now,
      });

      await db.insert('course_sessions', {
        'id': 'sess_r2',
        'courseId': 'c_rem_test',
        'sessionNumber': 2,
        'displayOrder': 2,
        'plannedDate': date2Str,
        'completionStatus': 'PENDING',
        'createdAt': now,
        'updatedAt': now,
      });

      // Insert pre-existing reminder for session 2
      await db.insert('pending_reminders', {
        'id': 'rem_sess_r2_custom',
        'courseSessionId': 'sess_r2',
        'originalTime': now + 500000,
        'scheduledTime': now + 500000,
        'state': 'SCHEDULED',
        'deferCount': 0,
        'createdAt': now,
        'updatedAt': now,
      });

      final newDateFor1 = DateTime.now().add(const Duration(days: 3));
      final newDate1Str = '${newDateFor1.year}-${newDateFor1.month.toString().padLeft(2, '0')}-${newDateFor1.day.toString().padLeft(2, '0')}';

      // Reschedule only session 1
      final res = await repo.rescheduleSession('sess_r1', newDate1Str);
      expect(res.isApplied, isTrue);

      // Session 2 reminder must NOT have been wiped
      final rems2 = await db.query('pending_reminders', where: 'courseSessionId = ?', whereArgs: ['sess_r2']);
      expect(rems2.length, equals(1));
      expect(rems2.first['id'], equals('rem_sess_r2_custom'));

      // Session 1 should now have a reminder created
      final rems1 = await db.query('pending_reminders', where: 'courseSessionId = ?', whereArgs: ['sess_r1']);
      expect(rems1.length, equals(1));
    });

    test('completeSession removes only that session reminder without wiping other session reminders', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final futureDate1 = DateTime.now().add(const Duration(days: 2));
      final futureDate2 = DateTime.now().add(const Duration(days: 4));
      final date1Str = '${futureDate1.year}-${futureDate1.month.toString().padLeft(2, '0')}-${futureDate1.day.toString().padLeft(2, '0')}';
      final date2Str = '${futureDate2.year}-${futureDate2.month.toString().padLeft(2, '0')}-${futureDate2.day.toString().padLeft(2, '0')}';

      await db.insert('courses', {
        'id': 'c_rem_comp',
        'title': 'Completion Reminder Course',
        'totalSessions': 2,
        'sessionDurationMinutes': 45,
        'activityType': 'STUDY',
        'status': 'ACTIVE',
        'isArchived': 0,
        'reminderEnabled': 1,
        'preferredTime': '18:00',
        'createdAt': now,
        'updatedAt': now,
        'courseType': 'VIDEO',
        'weeklyTargetSessions': 2,
      });

      await db.insert('course_sessions', {
        'id': 'sess_c1',
        'courseId': 'c_rem_comp',
        'sessionNumber': 1,
        'displayOrder': 1,
        'plannedDate': date1Str,
        'completionStatus': 'PENDING',
        'createdAt': now,
        'updatedAt': now,
      });

      await db.insert('course_sessions', {
        'id': 'sess_c2',
        'courseId': 'c_rem_comp',
        'sessionNumber': 2,
        'displayOrder': 2,
        'plannedDate': date2Str,
        'completionStatus': 'PENDING',
        'createdAt': now,
        'updatedAt': now,
      });

      // Insert custom reminders for both sessions
      await db.insert('pending_reminders', {
        'id': 'rem_sess_c1_custom',
        'courseSessionId': 'sess_c1',
        'originalTime': now + 400000,
        'scheduledTime': now + 400000,
        'state': 'SCHEDULED',
        'deferCount': 0,
        'createdAt': now,
        'updatedAt': now,
      });

      await db.insert('pending_reminders', {
        'id': 'rem_sess_c2_custom',
        'courseSessionId': 'sess_c2',
        'originalTime': now + 600000,
        'scheduledTime': now + 600000,
        'state': 'SCHEDULED',
        'deferCount': 0,
        'createdAt': now,
        'updatedAt': now,
      });

      // Complete session 1
      final res = await repo.completeSession(
        sessionId: 'sess_c1',
        actualDurationMinutes: 45,
      );
      expect(res.isApplied, isTrue);

      // Session 1 reminder must be deleted
      final rems1 = await db.query('pending_reminders', where: 'courseSessionId = ?', whereArgs: ['sess_c1']);
      expect(rems1.isEmpty, isTrue);

      // Session 2 reminder must remain untouched with its original ID
      final rems2 = await db.query('pending_reminders', where: 'courseSessionId = ?', whereArgs: ['sess_c2']);
      expect(rems2.length, equals(1));
      expect(rems2.first['id'], equals('rem_sess_c2_custom'));

      // Uncomplete session 1
      final unres = await repo.uncompleteSession('sess_c1');
      expect(unres.isApplied, isTrue);

      // Session 1 should have a fresh reminder recreated
      final rems1Recreated = await db.query('pending_reminders', where: 'courseSessionId = ?', whereArgs: ['sess_c1']);
      expect(rems1Recreated.length, equals(1));

      // Session 2 reminder must still be untouched
      final rems2AfterUncomplete = await db.query('pending_reminders', where: 'courseSessionId = ?', whereArgs: ['sess_c2']);
      expect(rems2AfterUncomplete.length, equals(1));
      expect(rems2AfterUncomplete.first['id'], equals('rem_sess_c2_custom'));
    });

    test('deleteCourse removes all pending reminders for the course', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.insert('courses', {
        'id': 'c_del_test',
        'title': 'Delete Course',
        'totalSessions': 1,
        'sessionDurationMinutes': 45,
        'activityType': 'STUDY',
        'status': 'ACTIVE',
        'isArchived': 0,
        'reminderEnabled': 1,
        'preferredTime': '18:00',
        'createdAt': now,
        'updatedAt': now,
        'courseType': 'VIDEO',
        'weeklyTargetSessions': 1,
      });

      await db.insert('course_sessions', {
        'id': 'sess_del1',
        'courseId': 'c_del_test',
        'sessionNumber': 1,
        'displayOrder': 1,
        'plannedDate': '2026-09-01',
        'completionStatus': 'PENDING',
        'createdAt': now,
        'updatedAt': now,
      });

      await db.insert('pending_reminders', {
        'id': 'rem_del1',
        'courseSessionId': 'sess_del1',
        'originalTime': now + 400000,
        'scheduledTime': now + 400000,
        'state': 'SCHEDULED',
        'deferCount': 0,
        'createdAt': now,
        'updatedAt': now,
      });

      final delRes = await repo.deleteCourse('c_del_test');
      expect(delRes.isApplied, isTrue);

      final rems = await db.query('pending_reminders', where: 'courseSessionId = ?', whereArgs: ['sess_del1']);
      expect(rems.isEmpty, isTrue);
    });
  });
}
