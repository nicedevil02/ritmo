import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/settings/presentation/widgets/day_timeline_preview.dart';
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

  group('Day Timeline 24h Preview Tests (SET-54)', () {
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
    });

    tearDown(() async {
      SettingsService.instance.cancelPendingSignals();
      await db.close();
    });

    testWidgets('DayTimelinePreview renders timeline bar and labels', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.build(
            palette: RitmoPalette.jadeNoir,
            brightness: Brightness.light,
          ),
          home: const Scaffold(
            body: DayTimelinePreview(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('day_timeline_preview')), findsOneWidget);
      expect(find.text('نمای توزیع ۲۴ ساعته زمان‌بندی‌ها'), findsOneWidget);
      expect(find.text('۰۰:۰۰'), findsOneWidget);
      expect(find.text('۱۲:۰۰'), findsOneWidget);
      expect(find.text('۲۴:۰۰'), findsOneWidget);
    });

    testWidgets('DayTimelinePreview dynamically reflects quiet hours', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.build(
            palette: RitmoPalette.jadeNoir,
            brightness: Brightness.light,
          ),
          home: const Scaffold(
            body: DayTimelinePreview(),
          ),
        ),
      );
      await tester.pump();

      // Initially quiet hours disabled
      expect(find.textContaining('سکوت:'), findsNothing);

      // Enable quiet hours inside tester.runAsync
      await tester.runAsync(() async {
        await SettingsService.instance.set('notif_quiet_enabled', true);
        await SettingsService.instance.set('notif_quiet_start', '22:00');
        await SettingsService.instance.set('notif_quiet_end', '06:00');
      });
      await tester.pump();

      expect(
        find.text('سکوت: ${toPersianDigits('22:00')} تا ${toPersianDigits('06:00')}'),
        findsOneWidget,
      );
    });
  });
}
