import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/di/service_locator.dart';
import 'package:ritmo/core/notifications/notification_request.dart';
import 'package:ritmo/core/platform/alarm_platform.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/logic/pregnancy_reminder_scheduler.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../cycle/test_helpers/cycle_test_db.dart';

class MockAlarmPlatform implements AlarmPlatform {
  final List<String> scheduledIds = [];
  final List<NotificationRequest> scheduledRequests = [];
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
    scheduledRequests.clear();
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
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pregnancy_checkups (
        id TEXT PRIMARY KEY,
        pregnancyId TEXT,
        title TEXT,
        scheduledDate INTEGER,
        isDone INTEGER DEFAULT 0,
        isCompleted INTEGER DEFAULT 0
      )
    ''');
  });

  tearDown(() async {
    await db.close();
  });

  group('PregnancyReminderScheduler Tests (PRG-35)', () {
    test('cancels all reminders when pregnancy mode is not active', () async {
      await db.insert('app_settings', {
        'key': 'cycle_pregnancy_mode',
        'value': 'false',
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await PregnancyReminderScheduler.rescheduleAll(dbExecutor: db);
      expect(mockAlarm.scheduledIds, isEmpty);
    });

    test('masks all notifications when preg_mask_notifications is true', () async {
      final now = DateTime(2026, 5, 10, 8, 0); // 8:00 AM
      final lmp = DateTime(2026, 3, 1); // ~10 weeks

      final settings = {
        'cycle_pregnancy_mode': 'true',
        'preg_start_date': CycleDateContract.toDayKey(lmp),
        'preg_mask_notifications': 'true',
        'preg_supplement_reminder': 'true',
        'preg_kick_reminder': 'true',
        'preg_reminder_hour': '9',
      };

      for (final entry in settings.entries) {
        await db.insert('app_settings', {
          'key': entry.key,
          'value': entry.value,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      await PregnancyReminderScheduler.rescheduleAll(
        dbExecutor: db,
        appSettings: settings,
        now: now,
      );

      // Verify scheduled alarms exist
      expect(mockAlarm.scheduledIds, isNotEmpty);

      // Query alarm delivery log to inspect titles and bodies
      final logs = await db.query('alarm_delivery_log');
      expect(logs, isNotEmpty);

      final sensitiveWords = ['بارداری', 'ویزیت', 'لگد', 'مکمل', 'مامایی', 'جنین'];
      final inbox = await db.query('inbox_items');
      expect(inbox, isNotEmpty);
      for (final item in inbox) {
        final title = item['title']?.toString() ?? '';
        final body = item['body']?.toString() ?? '';
        for (final word in sensitiveWords) {
          expect(
            title.contains(word),
            isFalse,
            reason: 'Title contains sensitive word "$word": $title',
          );
          expect(
            body.contains(word),
            isFalse,
            reason: 'Body contains sensitive word "$word": $body',
          );
        }
        expect(title, PregnancyReminderScheduler.maskedTitle);
        expect(body, PregnancyReminderScheduler.maskedBody);
      }
    });

    test('does not schedule kick reminder before week 28', () async {
      final now = DateTime(2026, 5, 10, 8, 0);
      // Week 20 (140 days)
      final lmp = now.subtract(const Duration(days: 140));

      final settings = {
        'cycle_pregnancy_mode': 'true',
        'preg_start_date': CycleDateContract.toDayKey(lmp),
        'preg_mask_notifications': 'false',
        'preg_supplement_reminder': 'false',
        'preg_kick_reminder': 'true', // Enabled, but ga < 28 weeks
        'preg_reminder_hour': '9',
      };

      await PregnancyReminderScheduler.rescheduleAll(
        dbExecutor: db,
        appSettings: settings,
        now: now,
      );

      // No kick reminder should be scheduled
      expect(mockAlarm.scheduledIds, isEmpty);
    });

    test('schedules kick reminder at week 28 and above', () async {
      final now = DateTime(2026, 5, 10, 8, 0);
      // Week 30 (210 days)
      final lmp = now.subtract(const Duration(days: 210));

      final settings = {
        'cycle_pregnancy_mode': 'true',
        'preg_start_date': CycleDateContract.toDayKey(lmp),
        'preg_mask_notifications': 'false',
        'preg_supplement_reminder': 'false',
        'preg_kick_reminder': 'true', // Enabled and ga >= 28 weeks
        'preg_reminder_hour': '9',
      };

      await PregnancyReminderScheduler.rescheduleAll(
        dbExecutor: db,
        appSettings: settings,
        now: now,
      );

      expect(mockAlarm.scheduledIds, contains('2080'));
    });

    test('schedules checkup visit reminder based on lead days', () async {
      final now = DateTime(2026, 5, 10, 8, 0);
      final lmp = now.subtract(const Duration(days: 70));
      final visitDate = now.add(const Duration(days: 4)); // In 4 days

      final settings = {
        'cycle_pregnancy_mode': 'true',
        'preg_start_date': CycleDateContract.toDayKey(lmp),
        'preg_mask_notifications': 'false',
        'preg_supplement_reminder': 'false',
        'preg_kick_reminder': 'false',
        'preg_visit_reminder_lead_days': '3', // 3 days before visit -> tomorrow at 9 AM
        'preg_reminder_hour': '9',
      };

      // Create pregnancy_checkups table and insert an upcoming checkup
      await db.execute('''
        CREATE TABLE IF NOT EXISTS pregnancy_checkups (
          id TEXT PRIMARY KEY,
          pregnancyId TEXT,
          title TEXT,
          scheduledDate INTEGER,
          isDone INTEGER DEFAULT 0,
          isCompleted INTEGER DEFAULT 0
        )
      ''');

      await db.insert('pregnancy_checkups', {
        'id': 'chk_1',
        'pregnancyId': 'preg_1',
        'title': 'مراقبت دوم: هفته ۱۶ تا ۲۰',
        'scheduledDate': visitDate.millisecondsSinceEpoch,
        'isDone': 0,
        'isCompleted': 0,
      });

      await PregnancyReminderScheduler.rescheduleAll(
        dbExecutor: db,
        appSettings: settings,
        now: now,
      );

      expect(mockAlarm.scheduledIds, contains('2060'));
    });
  });
}
