import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/di/service_locator.dart';
import 'package:ritmo/core/notifications/notification_ids.dart';
import 'package:ritmo/core/platform/alarm_platform.dart';
import 'package:ritmo/features/cycle/logic/pregnancy_reminder_scheduler.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../test_helpers/cycle_test_db.dart';

class MockAlarmPlatform implements AlarmPlatform {
  final List<String> scheduledIds = [];
  final List<String> cancelledIds = [];

  @override
  Future<bool> scheduleExactAlarm({
    required String id,
    required int timeMsUTC,
    required String title,
    required bool isEssential,
  }) async {
    scheduledIds.add(id);
    return true;
  }

  @override
  Future<bool> cancelAlarm(String id) async {
    cancelledIds.add(id);
    return true;
  }

  @override
  Future<bool> checkExactAlarmPermission() async => true;

  @override
  Future<bool> requestExactAlarmPermission() async => true;

  @override
  Future<bool> scheduleSilentTick({
    required String id,
    required int timeMsUTC,
  }) async => true;

  void reset() {
    scheduledIds.clear();
    cancelledIds.clear();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Database db;
  late MockAlarmPlatform mockAlarm;

  setUpAll(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    db = await openCycleTestDb();
    DatabaseHelper.instance.overrideDatabaseForTesting(db);

    mockAlarm = MockAlarmPlatform();
    if (sl.isRegistered<AlarmPlatform>()) {
      sl.unregister<AlarmPlatform>();
    }
    sl.registerSingleton<AlarmPlatform>(mockAlarm);

    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_reminders (
        id TEXT PRIMARY KEY,
        routineId TEXT,
        timeMsUTC INTEGER,
        title TEXT,
        isEssential INTEGER,
        state TEXT,
        createdAt INTEGER,
        updatedAt INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS alarm_delivery_log (
        id TEXT PRIMARY KEY,
        reminderId TEXT,
        routineId TEXT,
        expectedAt INTEGER,
        firedAt INTEGER,
        outcome TEXT,
        createdAt INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS inbox_items (
        id TEXT PRIMARY KEY,
        category TEXT,
        sourceSystem TEXT,
        title TEXT,
        body TEXT,
        priority INTEGER,
        linkModule TEXT,
        linkEntityId TEXT,
        linkAction TEXT,
        payloadJson TEXT,
        status TEXT,
        createdAt INTEGER,
        expiresAt INTEGER,
        dedupeKey TEXT
      )
    ''');
  });

  tearDown(() async {
    await db.close();
  });

  group('Cycle Resume Reminder Tests (PRG-39)', () {
    test(
      'schedules cycle resume reminder 40 days after birth when unmasked',
      () async {
        final now = DateTime(2026, 6, 1, 10, 0);
        final resumeDate = now.add(const Duration(days: 40));

        final settings = {
          'cycle_pregnancy_mode': 'false',
          'preg_cycle_resume_reminder': resumeDate.millisecondsSinceEpoch
              .toString(),
          'preg_mask_notifications': 'false',
        };

        await PregnancyReminderScheduler.rescheduleAll(
          dbExecutor: db,
          appSettings: settings,
          now: now,
        );

        expect(
          mockAlarm.scheduledIds,
          contains(NotificationIds.pregnancyCycleResume.toString()),
        );

        final inbox = await db.query('inbox_items');
        final resumeItems = inbox
            .where((r) => r['linkEntityId'] == 'pregnancy_cycle_resume')
            .toList();

        expect(resumeItems, isNotEmpty);
        expect(resumeItems.first['title'], 'پیگیری سلامت و چرخه قاعدگی');
      },
    );

    test(
      'schedules cycle resume reminder with masked title when masked',
      () async {
        final now = DateTime(2026, 6, 1, 10, 0);
        final resumeDate = now.add(const Duration(days: 40));

        final settings = {
          'cycle_pregnancy_mode': 'false',
          'preg_cycle_resume_reminder': resumeDate.millisecondsSinceEpoch
              .toString(),
          'preg_mask_notifications': 'true',
        };

        await PregnancyReminderScheduler.rescheduleAll(
          dbExecutor: db,
          appSettings: settings,
          now: now,
        );

        expect(
          mockAlarm.scheduledIds,
          contains(NotificationIds.pregnancyCycleResume.toString()),
        );

        final inbox = await db.query('inbox_items');
        final resumeItems = inbox
            .where((r) => r['linkEntityId'] == 'pregnancy_cycle_resume')
            .toList();

        expect(resumeItems, isNotEmpty);
        expect(resumeItems.first['title'], 'یادآوری ریتمو');
      },
    );

    test('cancelAll cancels cycle resume reminder ID 2090', () async {
      await PregnancyReminderScheduler.cancelAll();
      expect(
        mockAlarm.cancelledIds,
        contains(NotificationIds.pregnancyCycleResume.toString()),
      );
    });
  });
}
