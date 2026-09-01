import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/schema/tables/supplementary_sports_tables.dart';
import 'package:ritmo/core/domain/engines/ritmo_cross_module_engine.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/util/ritmo_date.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/engines.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/features/supplementary_sports/presentation/components/mv_contextual_banner.dart';
import 'package:ritmo/features/supplementary_sports/presentation/screens/mv_today_tab.dart';
import 'package:ritmo/l10n/app_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Widget createTestApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('fa'),
    theme: RitmoTheme.build(
      palette: RitmoPalette.jadeNoir,
      brightness: Brightness.dark,
    ),
    home: Scaffold(
      body: SizedBox(
        height: 1000,
        width: 600,
        child: child,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await SupplementarySportsTables.create(db);

    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS iran_cities (
        id TEXT PRIMARY KEY,
        nameFa TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS prayer_times_cache (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        cityId TEXT NOT NULL,
        calculationMethod TEXT NOT NULL,
        fajr TEXT NOT NULL,
        sunrise TEXT NOT NULL,
        dhuhr TEXT NOT NULL,
        asr TEXT NOT NULL,
        maghrib TEXT NOT NULL,
        isha TEXT NOT NULL,
        midnightShari TEXT NOT NULL,
        sunset TEXT
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS prayer_times (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        fajr TEXT NOT NULL,
        sunrise TEXT NOT NULL,
        dhuhr TEXT NOT NULL,
        asr TEXT NOT NULL,
        maghrib TEXT NOT NULL,
        isha TEXT NOT NULL,
        midnightShari TEXT NOT NULL,
        sunset TEXT
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS worship_day_contexts (
        date TEXT PRIMARY KEY,
        isTraveller INTEGER DEFAULT 0,
        fastingExempt INTEGER DEFAULT 0,
        prayerExempt INTEGER DEFAULT 0,
        exemptPrayers TEXT,
        reason TEXT
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS worship_practices (
        id TEXT PRIMARY KEY,
        practiceType TEXT NOT NULL,
        isCustom INTEGER DEFAULT 0
      );
    ''');

    DatabaseHelper.instance.overrideDatabaseForTesting(db);
    RitmoCrossModuleEngine.instance.invalidateCache();
  });

  tearDown(() async {
    await db.close();
  });

  group('Step 4: Fasting & Ramadan Protocol Tests', () {
    test('RitmoCrossModuleEngine correctly calculates fasting golden pre and post iftar windows', (
    ) async {
      final todayIso = RitmoDate.dayKey(DateTime.now());

      await db.insert('worship_practices', {
        'id': 'fast_1',
        'practiceType': 'FASTING',
        'isCustom': 0,
      });

      await db.insert('prayer_times_cache', {
        'id': 'ptc_1',
        'date': todayIso,
        'cityId': 'tehran',
        'calculationMethod': 'TEHRAN_GEOPHYSICS',
        'fajr': '04:30',
        'sunrise': '06:00',
        'dhuhr': '12:30',
        'asr': '16:00',
        'maghrib': '19:15',
        'isha': '20:15',
        'midnightShari': '23:30',
      });

      final snapshot =
          await RitmoCrossModuleEngine.instance.getSnapshot(date: DateTime.now());

      expect(snapshot.isFasting, isTrue);
      expect(snapshot.maghribTime, equals('19:15'));
      expect(snapshot.goldenPreIftarWindow, isNotNull);
      expect(snapshot.goldenPostIftarWindow, isNotNull);
      expect(snapshot.applicableReasonKeys, contains(MvReasonKeys.constraintRelaxed));
    });

    testWidgets('MvContextualBanner renders fasting action and triggers callback', (
      tester,
    ) async {
      bool actionTriggered = false;
      const snapshot = RitmoCrossModuleSnapshot(
        dateIso: '2026-09-01',
        isFasting: true,
        maghribTime: '19:15',
        goldenPreIftarWindow: '۱۸:۳۰ تا ۱۹:۱۵',
      );

      await tester.pumpWidget(
        createTestApp(
          MvContextualBanner(
            snapshot: snapshot,
            onApplyFastingWindow: () {
              actionTriggered = true;
            },
          ),
        ),
      );

      expect(find.text('پروتکل روزه‌داری و تمرین'), findsOneWidget);
      final actionButton = find.text('تنظیم زمان به قبل از افطار 🌙');
      expect(actionButton, findsOneWidget);

      await tester.tap(actionButton);
      await tester.pump();

      expect(actionTriggered, isTrue);
    });

    testWidgets('MvTodayTab applies fasting pre-iftar window on 1-tap action', (
      tester,
    ) async {
      final now = DateTime.now();
      final todayIso = RitmoDate.dayKey(now);

      MvSlot updatedSlot = MvSlot(
        id: 'slot_fasting_1',
        dateIso: todayIso,
        slotType: MvSlotType.strength,
        status: MvSlotStatus.planned,
        headlineFa: 'تمرین قدرتی بالاتنه',
        intensityTier: MvIntensityTier.moderate,
        targetMinutes: 30,
        createdAt: 1000,
        updatedAt: 1000,
      );

      const snapshot = RitmoCrossModuleSnapshot(
        dateIso: '2026-09-01',
        isFasting: true,
        maghribTime: '19:15',
        goldenPreIftarWindow: '۱۸:۳۰ تا ۱۹:۱۵',
      );

      await tester.pumpWidget(
        createTestApp(
          SingleChildScrollView(
            child: MvTodayTab(
              weekSlots: [updatedSlot],
              todaySlot: updatedSlot,
              readinessDecision: const MvDecision<MvReadinessTier>(
                value: MvReadinessTier.full,
                reasonFa: '',
              ),
              budgetProgress: const MvWeeklyBudgetProgress(
                moderateEquivalentMinutes: 60,
                rawMetMinutes: 180,
                strengthDays: 1,
                targetMin: 150,
                targetOptimal: 300,
                strengthDaysTarget: 2,
              ),
              bodyMapDistribution: const MvBodyMapDistribution(
                muscleSessionCounts: {},
              ),
              crossModuleSnapshot: snapshot,
              onStartSession: () {},
              onSlotUpdated: (s) {
                updatedSlot = s;
              },
              onCheckinSaved: (_) {},
              onQuickLogSaved: (kind, dur, feeling, note) async {},
              onDateSelected: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final actionButton = find.text('تنظیم زمان به قبل از افطار 🌙');
      expect(actionButton, findsOneWidget);

      await tester.tap(actionButton);
      await tester.pumpAndSettle();

      // Verify slot updated to pre-Iftar time (18:30) and light intensity
      expect(updatedSlot.plannedTime, equals('18:30'));
      expect(updatedSlot.intensityTier, equals(MvIntensityTier.light));
    });
  });
}
