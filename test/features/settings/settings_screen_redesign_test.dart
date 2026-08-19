import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/localization/locale_repository.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/theme_repository.dart';
import 'package:ritmo/features/settings/presentation/settings_screen.dart';
import 'package:ritmo/features/settings/presentation/widgets/settings_group_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ThemeRepository themeRepository;
  late LocaleRepository localeRepository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
    themeRepository = ThemeRepository();
    localeRepository = LocaleRepository();
  });

  Widget buildTestApp(Widget child) {
    return MaterialApp(
      theme: ThemeData.light(),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: child,
      ),
    );
  }

  group('SettingsScreen Redesign iOS 26 Tests', () {
    testWidgets('Renders all 4 distinct island sections with proper titles', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          SettingsScreen(
            onFactoryReset: () {},
            themeRepository: themeRepository,
            localeRepository: localeRepository,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify Section 1 Header
      expect(find.text('شخصی‌سازی و تجربه کاربری'), findsOneWidget);

      // Verify Section 2 Header
      expect(find.text('هسته هوشمند و قابلیت‌ها'), findsOneWidget);

      // Verify Section 3 Header
      expect(find.text('ارتباطات و اعلان‌ها'), findsOneWidget);

      // Verify Section 4 Header
      expect(find.text('امنیت و مدیریت داده‌ها'), findsOneWidget);

      // Verify group tiles are present
      expect(find.byType(SettingsGroupTile), findsNWidgets(8));

      // Verify specific group titles
      expect(find.text('حساب و هویت'), findsOneWidget);
      expect(find.text('ظاهر و زبان'), findsOneWidget);
      expect(find.text('ماژول‌ها و بخش‌های برنامه'), findsOneWidget);
      expect(find.text('دستیار و روان‌شناسی'), findsOneWidget);
      expect(find.text('تقویم و برنامه‌ریزی'), findsOneWidget);
      expect(find.text('اعلان‌ها و یادآوری‌ها'), findsOneWidget);
      expect(find.text('امنیت و قفل برنامه'), findsOneWidget);
      expect(find.text('داده و پشتیبان'), findsOneWidget);
    });

    testWidgets('SettingsGroupTile handles tap and micro-interaction', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            body: SettingsGroupTile(
              title: 'تست عنوان',
              subtitle: 'تست زیرعنوان',
              icon: CupertinoIcons.gear,
              gradient: const [Colors.blue, Colors.cyan],
              count: 5,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('تست عنوان'), findsOneWidget);
      expect(find.text('تست زیرعنوان'), findsOneWidget);
      expect(find.text('۵ مورد'), findsOneWidget);

      await tester.tap(find.byType(SettingsGroupTile));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });
  });
}
