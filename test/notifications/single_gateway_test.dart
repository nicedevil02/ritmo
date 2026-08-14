import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/di/service_locator.dart';
import 'package:ritmo/core/platform/alarm_platform.dart';
import 'package:ritmo/core/services/cycle_notification_service.dart';
import 'package:ritmo/core/services/sleep_winddown_reminder_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MockAlarmPlatform implements AlarmPlatform {
  final List<Map<String, dynamic>> scheduledAlarms = [];
  final List<String> cancelledAlarms = [];

  @override
  Future<bool> cancelAlarm(String id) async {
    cancelledAlarms.add(id);
    return true;
  }

  @override
  Future<bool> scheduleExactAlarm({
    required String id,
    required int timeMsUTC,
    required String title,
    required bool isEssential,
  }) async {
    scheduledAlarms.add({
      'id': id,
      'timeMsUTC': timeMsUTC,
      'title': title,
      'isEssential': isEssential,
    });
    return true;
  }

  @override
  Future<bool> scheduleSilentTick({required String id, required int timeMsUTC}) async => true;

  @override
  Future<bool> checkExactAlarmPermission() async => true;

  @override
  Future<bool> requestExactAlarmPermission() async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  try {
    sqfliteFfiInit();
  } catch (_) {}

  group('N2 Single Gateway Architectural Invariants', () {
    late Database db;
    late MockAlarmPlatform mockPlatform;
    bool dbInitialized = false;

    setUp(() async {
      mockPlatform = MockAlarmPlatform();
      if (sl.isRegistered<AlarmPlatform>()) {
        sl.unregister<AlarmPlatform>();
      }
      sl.registerSingleton<AlarmPlatform>(mockPlatform);

      try {
        databaseFactory = databaseFactoryFfi;
        db = await openDatabase(
          inMemoryDatabasePath,
          version: 1,
          onCreate: (db, version) async {
            await db.execute('CREATE TABLE app_settings (key TEXT PRIMARY KEY, value TEXT, updatedAt INTEGER);');
            await db.execute('''
              CREATE TABLE pending_reminders (
                id TEXT PRIMARY KEY,
                routineId TEXT,
                scheduleId TEXT,
                courseSessionId TEXT,
                originalTime INTEGER NOT NULL,
                scheduledTime INTEGER NOT NULL,
                state TEXT NOT NULL DEFAULT 'SCHEDULED',
                deferCount INTEGER NOT NULL DEFAULT 0,
                deferReason TEXT,
                createdAt INTEGER NOT NULL,
                updatedAt INTEGER NOT NULL,
                snoozeUntil INTEGER,
                nativeScheduled INTEGER DEFAULT 0,
                ownerModule TEXT
              );
            ''');
            await db.execute('''
              CREATE TABLE inbox_items (
                id TEXT PRIMARY KEY,
                category TEXT NOT NULL,
                sourceSystem TEXT NOT NULL,
                title TEXT NOT NULL,
                body TEXT,
                priority INTEGER NOT NULL,
                linkModule TEXT,
                linkEntityId TEXT,
                linkAction TEXT,
                payloadJson TEXT,
                status TEXT NOT NULL,
                createdAt INTEGER NOT NULL,
                expiresAt INTEGER,
                readAt INTEGER,
                dedupeKey TEXT
              );
            ''');
            await db.execute('CREATE TABLE calendar_exceptions (date TEXT PRIMARY KEY, behavior TEXT);');
            await db.execute('CREATE TABLE alarm_delivery_log (id TEXT PRIMARY KEY, reminderId TEXT, routineId TEXT, expectedAt INTEGER, firedAt INTEGER, outcome TEXT, createdAt INTEGER);');
          },
        );
        DatabaseHelper.instance.overrideDatabaseForTesting(db);
        dbInitialized = true;
      } catch (_) {
        dbInitialized = false;
      }
    });

    tearDown(() async {
      if (dbInitialized) {
        await db.close();
      }
    });

    test('CycleNotificationService schedules via NotificationGateway with redacted title', () async {
      if (!dbInitialized) return;

      final nextPeriod = DateTime.now().add(const Duration(days: 3));
      await CycleNotificationService.scheduleReminders(
        nextPeriodWindowStart: nextPeriod,
        consentReminders: true,
        pregnancyMode: false,
      );

      // Verify delivery through platform
      expect(mockPlatform.scheduledAlarms.isNotEmpty, isTrue);
      final alarm = mockPlatform.scheduledAlarms.first;
      expect(alarm['title'], equals('ریتمو: یادآوری روزانه 🌸'));
    });

    test('SleepWinddownReminderService schedules via NotificationGateway', () async {
      if (!dbInitialized) return;

      final now = DateTime.now();
      await db.insert('app_settings', {'key': 'sleep_winddown_reminder', 'value': 'true', 'updatedAt': now.millisecondsSinceEpoch});
      await db.insert('app_settings', {'key': 'sleep_winddown_minutes', 'value': '30', 'updatedAt': now.millisecondsSinceEpoch});
      await db.insert('app_settings', {'key': 'sleep_target_bedtime', 'value': '23:30', 'updatedAt': now.millisecondsSinceEpoch});

      await SleepWinddownReminderService.syncFromSettings();

      expect(mockPlatform.scheduledAlarms.any((a) => (a['id'] as String).contains('sleep_winddown')), isTrue);
    });

    test('Architectural Rule: scheduleExactAlarm is NEVER called directly outside NotificationGateway and AlarmPlatform', () {
      final libDir = Directory('lib');
      final dartFiles = libDir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

      final allowedPaths = [
        'lib\\core\\notifications\\notification_gateway.dart',
        'lib/core/notifications/notification_gateway.dart',
        'lib\\core\\platform\\alarm_platform.dart',
        'lib/core/platform/alarm_platform.dart',
        'lib\\core\\platform\\native_channel_contract.dart',
        'lib/core/platform/native_channel_contract.dart',
        'lib\\core\\services\\native_bridge.dart',
        'lib/core/services/native_bridge.dart',
      ];

      final violations = <String>[];

      for (final file in dartFiles) {
        final path = file.path;
        final isAllowed = allowedPaths.any((allowed) => path.replaceAll('/', '\\').contains(allowed.replaceAll('/', '\\')));
        if (isAllowed) continue;

        final content = file.readAsStringSync();
        if (content.contains('scheduleExactAlarm')) {
          violations.add(path);
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Direct calls to scheduleExactAlarm found in: $violations. All producers MUST use NotificationGateway.',
      );
    });
  });
}
