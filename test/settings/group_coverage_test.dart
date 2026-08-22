import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/settings/settings_registry.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/settings/presentation/groups/calendar_group_screen.dart';
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

  group('Group Coverage Tests', () {
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
      SettingsService.instance.resetForTesting();
      await SettingsService.instance.init();
      await SettingsService.instance.set('show_advanced_settings', true);
    });

    tearDown(() async {
      SettingsService.instance.cancelPendingSignals();
      await db.close();
    });

    Widget createTestWidget(Widget child) {
      return MaterialApp(
        theme: RitmoTheme.build(
          palette: RitmoPalette.jadeNoir,
          brightness: Brightness.light,
        ),
        home: child,
      );
    }

    testWidgets('CalendarGroupScreen renders all calendar descriptors', (tester) async {
      await tester.pumpWidget(createTestWidget(const CalendarGroupScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final calendarDescriptors = SettingsRegistry.userVisibleByGroup(SettingsGroup.calendar);

      // Verify that every single calendar descriptor is present in the screen
      for (final desc in calendarDescriptors) {
        expect(
          find.text(desc.labelFa),
          findsAtLeastNWidgets(1),
          reason: 'Expected ${desc.key} (${desc.labelFa}) to be rendered in CalendarGroupScreen',
        );
      }
    });
  });
}
