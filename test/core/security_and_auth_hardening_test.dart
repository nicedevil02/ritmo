import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/backend/auth_service.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/di/service_locator.dart';
import 'package:ritmo/core/notifications/notification_channel.dart';
import 'package:ritmo/core/notifications/notification_gateway.dart';
import 'package:ritmo/core/notifications/notification_policy.dart';
import 'package:ritmo/core/notifications/notification_request.dart';
import 'package:ritmo/core/platform/alarm_platform.dart';
import 'package:ritmo/core/security/pin_hasher.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MockAlarmPlatform implements AlarmPlatform {
  bool shouldSucceed = true;
  final List<Map<String, dynamic>> scheduledCalls = [];
  final List<String> cancelledIds = [];

  @override
  Future<bool> scheduleExactAlarm({
    required String id,
    required int timeMsUTC,
    required String title,
    required bool isEssential,
  }) async {
    scheduledCalls.add({
      'id': id,
      'timeMsUTC': timeMsUTC,
      'title': title,
      'isEssential': isEssential,
    });
    return shouldSucceed;
  }

  @override
  Future<bool> scheduleSilentTick({
    required String id,
    required int timeMsUTC,
  }) async {
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
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('T1 & T2 - Pin Security & Length Checks', () {
    test('PinHasher validates legacy and upgraded hashes consistently', () {
      final v2 = PinHasher.hashPin('0000');
      expect(PinHasher.verifyPin('0000', v2), isTrue);
      expect(PinHasher.verifyPin('۰۰۰۰', v2), isTrue);
      expect(PinHasher.needsUpgrade(v2), isFalse);

      expect(PinHasher.needsUpgrade('1234'), isTrue);
      expect(PinHasher.needsUpgrade(''), isFalse);
    });
  });

  group('T3 - AuthService State & Provider Isolation', () {
    test('UserAccountState reports correct googleLinked and provider status', () {
      const emailState = UserAccountState(
        isLoggedIn: true,
        provider: 'email',
        maskedIdentifier: 'te***@example.com',
        isGoogleLinked: false,
      );
      expect(emailState.isGoogleLinked, isFalse);
      expect(emailState.provider, equals('email'));

      const googleState = UserAccountState(
        isLoggedIn: true,
        provider: 'google',
        maskedIdentifier: 'go***@gmail.com',
        isGoogleLinked: true,
      );
      expect(googleState.isGoogleLinked, isTrue);
      expect(googleState.provider, equals('google'));
    });
  });

  group('T5 - NotificationGateway Execution Order & Delivery Outcome', () {
    late Database db;
    late MockAlarmPlatform mockPlatform;

    setUp(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (d, version) async {
          await d.execute('''
            CREATE TABLE alarm_delivery_log (
              id TEXT PRIMARY KEY,
              reminderId TEXT NOT NULL,
              routineId TEXT,
              expectedAt INTEGER NOT NULL,
              firedAt INTEGER,
              outcome TEXT NOT NULL,
              createdAt INTEGER NOT NULL
            )
          ''');
          await d.execute('''
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
              expiresAt INTEGER NOT NULL,
              dedupeKey TEXT UNIQUE
            )
          ''');
          await d.execute('''
            CREATE TABLE app_settings (
              key TEXT PRIMARY KEY,
              value TEXT,
              updatedAt INTEGER
            )
          ''');
          await d.execute('''
            CREATE TABLE calendar_exceptions (
              date TEXT PRIMARY KEY,
              behavior TEXT NOT NULL
            )
          ''');
        },
      );

      DatabaseHelper.databaseInstance = db;
      mockPlatform = MockAlarmPlatform();

      if (sl.isRegistered<AlarmPlatform>()) {
        sl.unregister<AlarmPlatform>();
      }
      sl.registerSingleton<AlarmPlatform>(mockPlatform);
    });

    tearDown(() async {
      DatabaseHelper.databaseInstance = null;
      await db.close();
    });

    test('Schedule failure records failed outcome in log and does NOT push to inbox', () async {
      mockPlatform.shouldSucceed = false;

      final req = NotificationRequest(
        id: 'test_alarm_fail_1',
        entityId: 'routine_1',
        title: 'یادآور آب خوردن',
        body: 'یک لیوان آب بنوشید',
        scheduledAt: DateTime.now().add(const Duration(minutes: 30)),
        channel: NotificationChannelId.routine,
        sourceSystem: 'routine',
      );

      final result = await NotificationGateway.schedule(
        req,
        overridePolicy: const NotificationPolicy(masterEnabled: true),
      );

      expect(result, isFalse);
      expect(mockPlatform.scheduledCalls.length, equals(1));

      // Verify alarm_delivery_log has outcome: 'failed' and firedAt: null
      final logs = await db.query('alarm_delivery_log');
      expect(logs.length, equals(1));
      expect(logs.first['outcome'], equals('failed'));
      expect(logs.first['firedAt'], isNull);

      // Verify NO inbox item was pushed
      final inboxItems = await db.query('inbox_items');
      expect(inboxItems, isEmpty);
    });

    test('Schedule success records scheduled outcome in log and pushes to inbox idempotently', () async {
      mockPlatform.shouldSucceed = true;

      final schedTime = DateTime.now().add(const Duration(minutes: 45));
      final req = NotificationRequest(
        id: 'test_alarm_success_1',
        entityId: 'routine_2',
        title: 'مطالعه روزانه',
        body: 'زمان مطالعه کتاب فرا رسیده است',
        scheduledAt: schedTime,
        channel: NotificationChannelId.routine,
        sourceSystem: 'routine',
      );

      final result = await NotificationGateway.schedule(
        req,
        overridePolicy: const NotificationPolicy(masterEnabled: true),
      );

      expect(result, isTrue);

      final logs = await db.query('alarm_delivery_log');
      expect(logs.length, equals(1));
      expect(logs.first['outcome'], equals('scheduled'));
      expect(logs.first['firedAt'], isNull);

      final inboxItems = await db.query('inbox_items');
      expect(inboxItems.length, equals(1));
      expect(inboxItems.first['title'], equals('مطالعه روزانه'));

      // Reschedule should not create duplicate inbox items due to dedupeKey
      final result2 = await NotificationGateway.schedule(
        req,
        overridePolicy: const NotificationPolicy(masterEnabled: true),
      );
      expect(result2, isTrue);

      final inboxItemsAfterReschedule = await db.query('inbox_items');
      expect(inboxItemsAfterReschedule.length, equals(1));
    });
  });
}
