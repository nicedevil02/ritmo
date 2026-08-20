import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/di/service_locator.dart';
import 'package:ritmo/core/platform/alarm_platform.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
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

  group('Notification Privacy Cascade Tests (PRG-41)', () {
    test('cascades preg_lock_enabled to notification masking when mask is false', () async {
      final now = DateTime(2026, 5, 10, 8, 0);
      final lmp = DateTime(2026, 3, 1);

      final settings = {
        'cycle_pregnancy_mode': 'true',
        'preg_start_date': CycleDateContract.toDayKey(lmp),
        'preg_lock_enabled': 'true',
        'preg_mask_notifications': 'false',
        'preg_supplement_reminder': 'true',
        'preg_kick_reminder': 'true',
        'preg_reminder_hour': '9',
      };

      await PregnancyReminderScheduler.rescheduleAll(
        dbExecutor: db,
        appSettings: settings,
        now: now,
      );

      final inbox = await db.query('inbox_items');
      expect(inbox, isNotEmpty);
      for (final item in inbox) {
        expect(item['title'], PregnancyReminderScheduler.maskedTitle);
      }
    });

    test('cascades cycle_inbox_mask_enabled to notification masking when preg_mask is false', () async {
      final now = DateTime(2026, 5, 10, 8, 0);
      final lmp = DateTime(2026, 3, 1);

      final settings = {
        'cycle_pregnancy_mode': 'true',
        'preg_start_date': CycleDateContract.toDayKey(lmp),
        'preg_lock_enabled': 'false',
        'preg_mask_notifications': 'false',
        'cycle_inbox_mask_enabled': 'true',
        'preg_supplement_reminder': 'true',
        'preg_kick_reminder': 'true',
        'preg_reminder_hour': '9',
      };

      await PregnancyReminderScheduler.rescheduleAll(
        dbExecutor: db,
        appSettings: settings,
        now: now,
      );

      final inbox = await db.query('inbox_items');
      expect(inbox, isNotEmpty);
      for (final item in inbox) {
        expect(item['title'], PregnancyReminderScheduler.maskedTitle);
      }
    });
  });
}
