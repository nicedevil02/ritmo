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
    test('rescheduleSession updates only that session reminder without wiping other reminders', () async {
      final db = await openDatabase(inMemoryDatabasePath, version: 1);
      await SystemTables.create(db);
      await CourseTables.create(db);
      await CourseTables.ensureSchema(db);

      final repo = CoursesRepository.instance;
      repo.overrideDatabaseForTesting(db);

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

      repo.overrideDatabaseForTesting(null);
      await db.close();
    });
  });
}
