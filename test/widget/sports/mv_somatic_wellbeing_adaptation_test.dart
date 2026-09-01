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
      CREATE TABLE IF NOT EXISTS energy_logs (
        id TEXT PRIMARY KEY,
        energyLevel TEXT NOT NULL,
        loggedAt INTEGER NOT NULL
      );
    ''');

    DatabaseHelper.instance.overrideDatabaseForTesting(db);
    RitmoCrossModuleEngine.instance.invalidateCache();
  });

  tearDown(() async {
    await db.close();
  });

  group('Step 6: Wellbeing & Somatic Movement Adaptation Tests', () {
    test('RitmoCrossModuleEngine flags isHighStressOrFatigue on low energy checkin', () async {
      final todayIso = RitmoDate.dayKey(DateTime.now());

      // Seed low energy checkin
      await db.insert('ss_daily_checkin', {
        'dateIso': todayIso,
        'energy': 2,
        'soreness': 2,
        'fatigue': 4,
        'painLevel': 0,
        'availableMinutes': 30,
        'createdAt': 1000,
        'updatedAt': 1000,
      });

      final snapshot =
          await RitmoCrossModuleEngine.instance.getSnapshot(date: DateTime.now());

      expect(snapshot.isHighStressOrFatigue, isTrue);
      expect(snapshot.energyLevel, equals(2));
      expect(snapshot.applicableReasonKeys, contains(MvReasonKeys.readinessLow));
    });

    testWidgets('MvContextualBanner renders somatic movement action and triggers callback', (
      tester,
    ) async {
      bool actionTriggered = false;
      const snapshot = RitmoCrossModuleSnapshot(
        dateIso: '2026-09-01',
        isHighStressOrFatigue: true,
      );

      await tester.pumpWidget(
        createTestApp(
          MvContextualBanner(
            snapshot: snapshot,
            onApplySomaticMovement: () {
              actionTriggered = true;
            },
          ),
        ),
      );

      expect(find.text('پیشنهاد تن‌آرامی و حرکات سوماتیک'), findsOneWidget);
      final actionButton = find.text('انطباق به تمرین سوماتیک و تنفس 🌿');
      expect(actionButton, findsOneWidget);

      await tester.tap(actionButton);
      await tester.pump();

      expect(actionTriggered, isTrue);
    });

    testWidgets('MvTodayTab adapts workout slot to 8-minute somatic movement on 1-tap', (
      tester,
    ) async {
      final now = DateTime.now();
      final todayIso = RitmoDate.dayKey(now);

      MvSlot updatedSlot = MvSlot(
        id: 'slot_wellbeing_1',
        dateIso: todayIso,
        slotType: MvSlotType.strength,
        status: MvSlotStatus.planned,
        headlineFa: 'تمرین قدرتی سنگین',
        intensityTier: MvIntensityTier.moderate,
        targetMinutes: 45,
        createdAt: 1000,
        updatedAt: 1000,
      );

      const snapshot = RitmoCrossModuleSnapshot(
        dateIso: '2026-09-01',
        isHighStressOrFatigue: true,
      );

      await tester.pumpWidget(
        createTestApp(
          SingleChildScrollView(
            child: MvTodayTab(
              weekSlots: [updatedSlot],
              todaySlot: updatedSlot,
              readinessDecision: const MvDecision<MvReadinessTier>(
                value: MvReadinessTier.minimal,
                reasonFa: 'خستگی و تنش بالا',
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

      final actionButton = find.text('انطباق به تمرین سوماتیک و تنفس 🌿');
      expect(actionButton, findsOneWidget);

      await tester.tap(actionButton);
      await tester.pumpAndSettle();

      // Verify slot adapted to 8-minute somatic movement headline and light intensity
      expect(updatedSlot.headlineFa, equals('تمرین سوماتیک و تن‌آرامی'));
      expect(updatedSlot.intensityTier, equals(MvIntensityTier.light));
      expect(updatedSlot.targetMinutes, equals(8));
      expect(updatedSlot.focusCodes, contains('NECK_TRAPS'));
    });
  });
}
