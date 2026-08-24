import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/localization/locale_repository.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/theme/theme_repository.dart';
import 'package:ritmo/features/settings/presentation/groups/appearance_group_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SettingsService.instance.resetForTesting();
    await SettingsService.instance.init();
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

  group('AppearanceGroupScreen UI Scale & Density Tests', () {
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
        await tester.pumpAndSettle();

        expect(find.text('اندازهٔ متن و المان‌ها'), findsOneWidget);
        expect(find.text('پیش‌نمایش زنده'), findsOneWidget);
        expect(find.text('اندازهٔ متن'), findsWidgets);
        expect(find.byType(Slider), findsOneWidget);
        expect(find.text('پیروی از اندازه فونت سیستم'), findsOneWidget);
        expect(find.text('چگالی و بزرگی المان‌ها'), findsOneWidget);
        expect(find.text('بازگردانی به پیش‌فرض'), findsOneWidget);

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
      await tester.pumpAndSettle();

      final switchFinder = find.byWidgetPredicate(
        (w) => w is CupertinoSwitch && w.value == true,
      );
      expect(switchFinder, findsWidgets);

      await tester.tap(switchFinder.first);
      await tester.pumpAndSettle();

      expect(themeRepo.preferencesNotifier.value.followOsTextScale, isFalse);

      themeRepo.dispose();
    });
  });
}
