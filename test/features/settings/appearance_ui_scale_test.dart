import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/localization/locale_repository.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/theme/theme_repository.dart';
import 'package:ritmo/features/settings/presentation/groups/appearance_group_screen.dart';
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async => null,
        );
  });

  group('AppearanceGroupScreen UI Scale & Density Tests', () {
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
      DatabaseHelper.databaseInstance = null;
    });

    Widget buildTestableScreen({
      required ThemeRepository themeRepo,
      required LocaleRepository localeRepo,
    }) {
      return MaterialApp(
        theme: RitmoTheme.build(
          palette: RitmoPalette.jadeNoir,
          brightness: Brightness.light,
        ),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: AppearanceGroupScreen(
            themeRepository: themeRepo,
            localeRepository: localeRepo,
          ),
        ),
      );
    }

    testWidgets(
      'Renders live preview, text scale slider, density control, and switches',
      (tester) async {
        final themeRepo = ThemeRepository();
        await themeRepo.init();
        final localeRepo = LocaleRepository();
        await localeRepo.init();

        await tester.pumpWidget(
          buildTestableScreen(themeRepo: themeRepo, localeRepo: localeRepo),
        );
        await tester.pump();

        expect(find.text('اندازهٔ متن و المان‌ها'), findsOneWidget);
        expect(find.text('پیش‌نمایش زنده'), findsOneWidget);
        expect(find.text('اندازهٔ متن'), findsWidgets);
        expect(find.byType(Slider), findsOneWidget);
        expect(find.text('پیروی از اندازه فونت سیستم'), findsOneWidget);
        expect(find.text('چگالی و بزرگی المان‌ها'), findsOneWidget);
        expect(find.text('بازگردانی به پیش‌فرض'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        themeRepo.dispose();
      },
    );

    testWidgets('Toggling follow OS switch updates ThemeRepository', (
      tester,
    ) async {
      final themeRepo = ThemeRepository();
      await themeRepo.init();
      final localeRepo = LocaleRepository();
      await localeRepo.init();

      await tester.pumpWidget(
        buildTestableScreen(themeRepo: themeRepo, localeRepo: localeRepo),
      );
      await tester.pump();

      final switchFinder = find.byType(CupertinoSwitch);
      expect(switchFinder, findsWidgets);

      final initialVal = themeRepo.preferencesNotifier.value.followOsTextScale;
      await tester.tap(switchFinder.first);
      await tester.pump();

      expect(
        themeRepo.preferencesNotifier.value.followOsTextScale,
        !initialVal,
      );

      await tester.pumpWidget(const SizedBox());
      themeRepo.dispose();
    });

    testWidgets('Slider accurately tracks step indices and discrete scale states', (
      tester,
    ) async {
      final themeRepo = ThemeRepository();
      await themeRepo.init();
      final localeRepo = LocaleRepository();
      await localeRepo.init();

      await tester.pumpWidget(
        buildTestableScreen(themeRepo: themeRepo, localeRepo: localeRepo),
      );
      await tester.pump();

      final sliderFinder = find.byType(Slider);
      expect(sliderFinder, findsOneWidget);

      final slider = tester.widget<Slider>(sliderFinder);
      expect(slider.min, 0.0);
      expect(slider.max, 5.0);
      expect(slider.divisions, 5);
      expect(slider.value, 2.0); // 100% is index 2

      await tester.pumpWidget(const SizedBox());
      themeRepo.dispose();
    });
  });
}
