import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/worship/domain/prayer_target.dart';
import 'package:ritmo/features/worship/models/worship_models.dart';
import 'package:ritmo/features/worship/presentation/widgets/mustahab_section.dart';
import 'package:ritmo/features/worship/presentation/widgets/prayer_city_picker.dart';
import 'package:ritmo/features/worship/presentation/widgets/prayer_sheet.dart';
import 'package:ritmo/features/worship/presentation/widgets/worship_reminder_settings_sheet.dart';
import 'package:ritmo/features/worship/presentation/widgets/worship_settings_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const dummyPractice = WorshipPractice(
    id: 'test_practice_1',
    practiceType: 'MUSTAHAB',
    subType: 'CUSTOM',
    title: 'تست مستحب',
    reminderEnabled: false,
    reminderTime: '20:00',
    dailyDoneDate: '',
    createdAt: 0,
    updatedAt: 0,
  );

  final dummyPrayerTarget = PrayerTarget(
    groupKey: 'FAJR',
    titleFa: 'نماز صبح',
    practiceIds: const ['wp_prayer_fajr'],
    date: DateTime.now(),
  );

  group('Worship Sheets Glassmorphism Tests', () {
    testWidgets('WorshipSettingsSheet renders BackdropFilter when glass is enabled', (tester) async {
      final glassTheme = RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
        reduceTransparency: false,
        glassBlurSigma: 20.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: glassTheme,
          home: Scaffold(
            body: WorshipSettingsSheet(
              onChanged: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('WorshipSettingsSheet renders opaque container when glass is disabled', (tester) async {
      final opaqueTheme = RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
        reduceTransparency: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: opaqueTheme,
          home: Scaffold(
            body: WorshipSettingsSheet(
              onChanged: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('PrayerCityPicker renders BackdropFilter when glass is enabled', (tester) async {
      final glassTheme = RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
        reduceTransparency: false,
        glassBlurSigma: 20.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: glassTheme,
          home: Scaffold(
            body: PrayerCityPicker(
              onChanged: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('PrayerCityPicker renders opaque container when glass is disabled', (tester) async {
      final opaqueTheme = RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
        reduceTransparency: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: opaqueTheme,
          home: Scaffold(
            body: PrayerCityPicker(
              onChanged: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('WorshipReminderSettingsSheet renders BackdropFilter when glass is enabled', (tester) async {
      final glassTheme = RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
        reduceTransparency: false,
        glassBlurSigma: 20.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: glassTheme,
          home: Scaffold(
            body: WorshipReminderSettingsSheet(
              practice: dummyPractice,
              onSaved: (_) {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(find.text('تنظیم یادآوری'), findsOneWidget);
    });

    testWidgets('WorshipReminderSettingsSheet renders opaque container when glass is disabled', (tester) async {
      final opaqueTheme = RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
        reduceTransparency: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: opaqueTheme,
          home: Scaffold(
            body: WorshipReminderSettingsSheet(
              practice: dummyPractice,
              onSaved: (_) {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.text('تنظیم یادآوری'), findsOneWidget);
    });

    testWidgets('PrayerSheet renders BackdropFilter when glass is enabled', (tester) async {
      final glassTheme = RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
        reduceTransparency: false,
        glassBlurSigma: 20.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: glassTheme,
          home: Scaffold(
            body: PrayerSheet(
              target: dummyPrayerTarget,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(find.text('نماز صبح'), findsOneWidget);
    });

    testWidgets('PrayerSheet renders opaque container when glass is disabled', (tester) async {
      final opaqueTheme = RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
        reduceTransparency: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: opaqueTheme,
          home: Scaffold(
            body: PrayerSheet(
              target: dummyPrayerTarget,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.text('نماز صبح'), findsOneWidget);
    });

    testWidgets('AddCustomMustahabSheet renders BackdropFilter when glass is enabled', (tester) async {
      final glassTheme = RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
        reduceTransparency: false,
        glassBlurSigma: 20.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: glassTheme,
          home: Scaffold(
            body: AddCustomMustahabSheet(
              onSaved: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(find.text('افزودن مستحب سفارشی'), findsOneWidget);
    });

    testWidgets('AddCustomMustahabSheet renders opaque container when glass is disabled', (tester) async {
      final opaqueTheme = RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
        reduceTransparency: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: opaqueTheme,
          home: Scaffold(
            body: AddCustomMustahabSheet(
              onSaved: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.text('افزودن مستحب سفارشی'), findsOneWidget);
    });
  });
}
