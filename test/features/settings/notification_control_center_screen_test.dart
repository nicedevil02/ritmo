import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/di/service_locator.dart';
import 'package:ritmo/core/platform/alarm_platform.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/settings/presentation/groups/notifications_group_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MockAlarmPlatform implements AlarmPlatform {
  @override
  Future<bool> cancelAlarm(String id) async => true;

  @override
  Future<bool> scheduleExactAlarm({
    required String id,
    required int timeMsUTC,
    required String title,
    required bool isEssential,
  }) async => true;

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

  late Directory tempDir;
  Database? db;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('notif_center_test_');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (methodCall) async => tempDir.path,
    );

    if (sl.isRegistered<AlarmPlatform>()) {
      sl.unregister<AlarmPlatform>();
    }
    sl.registerSingleton<AlarmPlatform>(MockAlarmPlatform());

    try {
      databaseFactory = databaseFactoryFfi;
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('CREATE TABLE app_settings (key TEXT PRIMARY KEY, value TEXT, updatedAt INTEGER);');
          await db.execute('''
            CREATE TABLE notification_channel_prefs (
              channel_id TEXT PRIMARY KEY,
              enabled INTEGER NOT NULL DEFAULT 1,
              sound_mode TEXT NOT NULL DEFAULT 'default',
              vibration_enabled INTEGER NOT NULL DEFAULT 1,
              bypass_dnd INTEGER NOT NULL DEFAULT 0,
              updated_at INTEGER NOT NULL
            );
          ''');
        },
      );
      DatabaseHelper.instance.overrideDatabaseForTesting(db!);
    } catch (_) {}
  });

  tearDown(() async {
    if (db != null) {
      await db!.close();
    }
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Notification Control Center Screen Widget Tests', () {
    testWidgets('renders title, master switch, privacy center tile, and all 6 canonical channels', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.darkTheme,
          home: const NotificationsGroupScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify AppBar and Master Title
      expect(find.text('مرکز کنترل اعلان‌ها'), findsOneWidget);
      expect(find.text('کلید اصلی اعلان‌ها (Master)'), findsOneWidget);

      // 2. Verify Privacy Center Banner Tile
      expect(find.text('مرکز حریم خصوصی و اعلان‌های مبدل'), findsOneWidget);

      // 3. Verify all 6 Canonical Channels are listed
      expect(find.text('دارو و سلامت حیاتی'), findsOneWidget);
      expect(find.text('روتین‌ها و عادات روزمره'), findsOneWidget);
      expect(find.text('اذان و عبادات'), findsOneWidget);
      expect(find.text('برنامه‌ریزی و بازبینی'), findsOneWidget);
      expect(find.text('بینش و دستیار هوشمند'), findsOneWidget);
      expect(find.text('اعلان‌های خصوصی'), findsOneWidget);

      // 4. Verify Critical channel has bypass badge
      expect(find.text('عبور از سکوت'), findsOneWidget);
    });
  });
}
