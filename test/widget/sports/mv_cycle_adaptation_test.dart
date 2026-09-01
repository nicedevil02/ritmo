import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/schema/tables/supplementary_sports_tables.dart';
import 'package:ritmo/core/domain/engines/ritmo_cross_module_engine.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/util/ritmo_date.dart';
import 'package:ritmo/features/supplementary_sports/application/mv_readiness_use_case.dart';
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
      CREATE TABLE IF NOT EXISTS cycle_entries (
        id TEXT PRIMARY KEY,
        startDate TEXT NOT NULL,
        endDate TEXT
      );
    ''');

    DatabaseHelper.instance.overrideDatabaseForTesting(db);
    RitmoCrossModuleEngine.instance.invalidateCache();
  });

  tearDown(() async {
    await db.close();
  });

  group('Step 5: Cycle Phase Synchronization & Consent Gate Tests', () {
    test('MvReadinessUseCase respects cycle consent gate (Law 16, 18 & 19)', () async {
      final todayIso = RitmoDate.dayKey(DateTime.now());

      // Seed menstrual cycle start today in cycle_entries
      await db.insert('cycle_entries', {
        'id': 'cycle_1',
        'startDate': todayIso,
        'endDate': null,
      });

      // User profile WITHOUT cycle consent
      const profileNoConsent = MvUserProfile(
        goal: 'generalFitness',
        experienceLevel: 'intermediate',
        trainingLocation: 'home',
        availableEquipment: [],
        cycleConsentGranted: false,
        createdAt: 1000,
        updatedAt: 1000,
      );

      final useCase = MvReadinessUseCase();

      // Execute without consent -> score stays 100 (Full)
      final decisionNoConsent = await useCase.execute(
        dateIso: todayIso,
        profile: profileNoConsent,
        sleepHours: 8.0,
      );
      expect(decisionNoConsent.value, equals(MvReadinessTier.full));

      // User profile WITH cycle consent
      await db.insert('ss_user_profile', {
        'id': 'default',
        'goal': 'generalFitness',
        'experienceLevel': 'intermediate',
        'trainingLocation': 'home',
        'availableEquipment': '[]',
        'cycleConsentGranted': 1,
        'createdAt': 1000,
        'updatedAt': 1000,
      });

      const profileWithConsent = MvUserProfile(
        goal: 'generalFitness',
        experienceLevel: 'intermediate',
        trainingLocation: 'home',
        availableEquipment: [],
        cycleConsentGranted: true,
        createdAt: 1000,
        updatedAt: 1000,
      );

      RitmoCrossModuleEngine.instance.invalidateCache();

      // Seed moderate fatigue checkin to combine with cycle (-15) -> lands in minimal
      await db.insert('ss_daily_checkin', {
        'dateIso': todayIso,
        'energy': 3,
        'soreness': 2,
        'fatigue': 2,
        'painLevel': 0,
        'availableMinutes': 30,
        'createdAt': 1000,
        'updatedAt': 1000,
      });

      final decisionWithConsent = await useCase.execute(
        dateIso: todayIso,
        profile: profileWithConsent,
        sleepHours: 8.0,
      );

      // Score reduced to light tier (100 - 16 - 15 = 69 -> Light)
      expect(decisionWithConsent.value, equals(MvReadinessTier.light));
      expect(decisionWithConsent.reasonFa, contains('فاز استراحت چرخه'));

      // Verify decision logged in ss_decision_log
      final decisionLogs = await db.query('ss_decision_log');
      expect(decisionLogs, isNotEmpty);
      expect(decisionLogs.first['decisionType'], equals('ADAPT_READINESS'));
    });

    testWidgets('MvContextualBanner renders cycle recovery action and triggers callback', (
      tester,
    ) async {
      bool actionTriggered = false;
      const snapshot = RitmoCrossModuleSnapshot(
        dateIso: '2026-09-01',
        isMenstrualPhase: true,
        cycleConsentGranted: true,
      );

      await tester.pumpWidget(
        createTestApp(
          MvContextualBanner(
            snapshot: snapshot,
            onShowRestorativeMovements: () {
              actionTriggered = true;
            },
          ),
        ),
      );

      expect(find.text('فاز ریکاوری چرخهٔ زیستی'), findsOneWidget);
      final actionButton = find.text('تعدیل برنامه به تمرینات تسکین‌دهنده 🌸');
      expect(actionButton, findsOneWidget);

      await tester.tap(actionButton);
      await tester.pump();

      expect(actionTriggered, isTrue);
    });

    testWidgets('MvTodayTab adapts workout slot to restorative stretching on cycle action tap', (
      tester,
    ) async {
      final now = DateTime.now();
      final todayIso = RitmoDate.dayKey(now);

      MvSlot updatedSlot = MvSlot(
        id: 'slot_cycle_1',
        dateIso: todayIso,
        slotType: MvSlotType.strength,
        status: MvSlotStatus.planned,
        headlineFa: 'تمرین سنگین قدرتی',
        intensityTier: MvIntensityTier.moderate,
        targetMinutes: 45,
        createdAt: 1000,
        updatedAt: 1000,
      );

      const snapshot = RitmoCrossModuleSnapshot(
        dateIso: '2026-09-01',
        isMenstrualPhase: true,
        cycleConsentGranted: true,
      );

      await tester.pumpWidget(
        createTestApp(
          SingleChildScrollView(
            child: MvTodayTab(
              weekSlots: [updatedSlot],
              todaySlot: updatedSlot,
              readinessDecision: const MvDecision<MvReadinessTier>(
                value: MvReadinessTier.minimal,
                reasonFa: 'فاز آرامش چرخه',
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

      final actionButton = find.text('تعدیل برنامه به تمرینات تسکین‌دهنده 🌸');
      expect(actionButton, findsOneWidget);

      await tester.tap(actionButton);
      await tester.pumpAndSettle();

      // Verify slot adapted to restorative stretching headline and light intensity
      expect(updatedSlot.headlineFa, equals('حرکات کششی و تسکین‌دهنده'));
      expect(updatedSlot.intensityTier, equals(MvIntensityTier.light));
      expect(updatedSlot.targetMinutes, equals(20));
      expect(updatedSlot.focusCodes, contains('LOWER_BACK'));
    });
  });
}
