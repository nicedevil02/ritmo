import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/widgets/ritmo_progress_ring.dart';
import 'package:ritmo/features/cycle/cycle_hero_card.dart';
import 'package:ritmo/features/today/presentation/widgets/dashboard/home_focus_hero.dart';
import 'package:ritmo/features/today/presentation/widgets/dashboard/next_action_hero.dart';
import 'package:ritmo/features/today/presentation/widgets/dashboard/today_path_progress_banner.dart';
import 'package:ritmo/features/worship/logic/worship_engine.dart';
import 'package:ritmo/features/worship/models/worship_models.dart';
import 'package:ritmo/features/worship/presentation/widgets/prayer_arc_hero.dart';
import 'package:ritmo/features/worship/presentation/widgets/qibla_compass_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../support/responsive_harness.dart';

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

  late Database db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS app_settings (
            key TEXT PRIMARY KEY,
            value TEXT,
            updatedAt INTEGER
          );
        ''');
      },
    );
    DatabaseHelper.databaseInstance = db;
    SettingsService.instance.resetForTesting();
    await SettingsService.instance.init();
  });

  const testDensities = [
    RitmoDensityLevel.compact,
    RitmoDensityLevel.comfortable,
  ];
  const testScales = [1.0, 1.30, 1.40];

  final mockTimes = PrayerTimes(
    date: '2026-08-24',
    cityId: 'tehran',
    fajr: DateTime(2026, 8, 24, 4, 30),
    sunrise: DateTime(2026, 8, 24, 6, 0),
    dhuhr: DateTime(2026, 8, 24, 12, 30),
    asr: DateTime(2026, 8, 24, 16, 0),
    sunset: DateTime(2026, 8, 24, 19, 30),
    maghrib: DateTime(2026, 8, 24, 19, 50),
    isha: DateTime(2026, 8, 24, 21, 0),
    midnightShari: DateTime(2026, 8, 24, 23, 30),
    calculationMethod: 'Tehran',
  );

  final mockWorshipDay = WorshipDay(
    date: DateTime(2026, 8, 24),
    hijri: const HijriDate(
      day: 10,
      month: 3,
      year: 1448,
      monthName: 'ربیع‌الاول',
      formatted: '۱۰ ربیع‌الاول ۱۴۴۸',
    ),
    times: mockTimes,
    practices: const [],
    seasons: const [],
    context: WorshipDayContext(date: DateTime(2026, 8, 24), isTraveller: false),
    occasions: const [],
  );

  final mockHeroData = NextActionHeroData(
    type: HeroPriorityType.overdueOrNextItem,
    title: 'جلسه بازبینی معماری ریتمو',
    subtitle: 'شروع در ۱۰ دقیقه آینده در اتاق جلسات',
    primaryCtaLabel: 'شروع فعالیت',
    onPrimaryTap: () {},
    secondaryCtaLabel: 'به تعویق انداختن',
    onSecondaryTap: () {},
    previousTaskTitle: 'ورزش صبحگاهی',
    isPreviousTaskCompleted: true,
    nextTaskTitle: 'مطالعه روزانه',
    nextTaskTime: '۱۱:۳۰',
  );

  group('Canvas & Hero Scale Robustness Tests', () {
    for (final density in testDensities) {
      for (final textScale in testScales) {
        final label =
            'Canvas Scale Test [Density: ${density.name}, Scale: ${(textScale * 100).toInt()}%]';

        testWidgets(label, (tester) async {
          tester.view.physicalSize = const Size(390, 2400);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);

          final theme = RitmoTheme.build(
            palette: RitmoPalette.jadeNoir,
            brightness: Brightness.light,
            density: density,
          );

          await tester.pumpWidget(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: theme,
              home: MediaQuery(
                data: MediaQueryData(
                  size: const Size(390, 2400),
                  textScaler: TextScaler.linear(textScale),
                ),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Scaffold(
                    body: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. RitmoProgressRing
                          const Center(
                            child: RitmoProgressRing(
                              key: ValueKey('canvas_progress_ring'),
                              value: 78,
                              confidence: 0.85,
                              size: 130,
                              strokeWidth: 9,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 2. HomeFocusHero
                          HomeFocusHero(
                            key: const ValueKey('canvas_focus_hero'),
                            data: mockHeroData,
                          ),
                          const SizedBox(height: 16),

                          // 3. TodayPathProgressBanner
                          const TodayPathProgressBanner(
                            key: ValueKey('canvas_path_progress'),
                            progress: 0.65,
                            doneCount: 5,
                            totalCount: 8,
                            remainingCount: 3,
                          ),
                          const SizedBox(height: 16),

                          // 4. CycleHeroCard
                          const CycleHeroCard(
                            key: ValueKey('canvas_cycle_hero'),
                            currentPhase: CyclePhase.follicular,
                            currentDay: 8,
                            totalDaysInPhase: 14,
                          ),
                          const SizedBox(height: 16),

                          // 5. PrayerArcHero
                          PrayerArcHero(
                            key: const ValueKey('canvas_prayer_arc'),
                            day: mockWorshipDay,
                            onPracticeToggle: (_, _) {},
                            onTravellerToggle: (_) {},
                            onOpenCityPicker: () {},
                          ),
                          const SizedBox(height: 16),

                          // 6. QiblaCompassSheet
                          const QiblaCompassSheet(
                            key: ValueKey('canvas_qibla_compass'),
                            cityLat: 35.6892,
                            cityLng: 51.3890,
                            cityName: 'تهران',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );

          await expectNoOverflow(tester, label: label);
        });
      }
    }
  });
}
