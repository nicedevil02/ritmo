import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/settings/presentation/widgets/settings_ready_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
  });

  group('SettingsReadyGate Tests (SET-43)', () {
    late Database db;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE app_settings (
              key TEXT PRIMARY KEY,
              value TEXT,
              updatedAt INTEGER
            )
          ''');
        },
      );
      DatabaseHelper.instance.overrideDatabaseForTesting(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('Parallel init() calls are coalesced and safe', () async {
      // Calling init() concurrently 5 times
      final futures = List.generate(5, (_) => SettingsService.instance.init());
      await Future.wait(futures);

      expect(SettingsService.instance.isInitialized, isTrue);
      expect(SettingsService.instance.loadState, SettingsLoadState.loaded);
    });

    testWidgets('SettingsReadyGate initializes service and renders child', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.build(
            palette: RitmoPalette.jadeNoir,
            brightness: Brightness.light,
          ),
          home: const Scaffold(
            body: SettingsReadyGate(
              child: Text('محتوای محافظت‌شده تنظیمات'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('محتوای محافظت‌شده تنظیمات'), findsOneWidget);
    });
  });
}
