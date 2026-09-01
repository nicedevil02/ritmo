import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/schema/tables/sleep_tables.dart';
import 'package:ritmo/core/database/schema/tables/supplementary_sports_tables.dart';
import 'package:ritmo/core/domain/engines/ritmo_cross_module_engine.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/util/ritmo_date.dart';
import 'package:ritmo/features/supplementary_sports/application/mv_readiness_use_case.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/engines.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/features/supplementary_sports/presentation/components/mv_contextual_banner.dart';
import 'package:ritmo/features/supplementary_sports/presentation/screens/mv_today_tab.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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
    await SleepTables.create(db);

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
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cycle_entries (
        id TEXT PRIMARY KEY,
        startDate TEXT NOT NULL,
        endDate TEXT
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS energy_logs (
        id TEXT PRIMARY KEY,
        energyLevel TEXT NOT NULL,
        source TEXT,
        loggedAt INTEGER NOT NULL
      );
    ''');

    DatabaseHelper.instance.overrideDatabaseForTesting(db);
    RitmoCrossModuleEngine.instance.invalidateCache();
  });

  tearDown(() async {
    await db.close();
  });

  group('Step 3: Sleep & Cross-Module Adaptation Integration Tests', () {
    test('MvReadinessUseCase automatically uses sleep from RitmoCrossModuleEngine and logs decision', (
    ) async {
      final todayIso = RitmoDate.dayKey(DateTime.now());

      // Seed user profile
      const profile = MvUserProfile(
        goal: 'generalFitness',
        experienceLevel: 'intermediate',
        trainingLocation: 'home',
        availableEquipment: [],
        createdAt: 1000,
        updatedAt: 1000,
      );

      // Seed sleep plan day with 300 minutes (5 hours < 6 hours debt)
      await db.insert('sleep_programs', {
        'id': 'prog_1',
        'status': 'active',
        'createdAt': 1000,
        'updatedAt': 1000,
      });

      await db.insert('sleep_plan_days', {
        'programId': 'prog_1',
        'date': todayIso,
        'plannedBedtimeMin': 1380,
        'plannedWakeMin': 420,
        'actualBedtimeMin': 1440,
        'actualWakeMin': 300, // 300 minutes = 5 hours
      });

      // Seed checkin with moderate soreness to land in minimal tier (40-59)
      await db.insert('ss_daily_checkin', {
        'dateIso': todayIso,
        'energy': 3,
        'soreness': 2,
        'fatigue': 2,
        'painLevel': 0,
        'availableMinutes': 30,
        'note': 'کمی خستگی',
        'createdAt': 1000,
        'updatedAt': 1000,
      });

      final useCase = MvReadinessUseCase();
      final decision = await useCase.execute(
        dateIso: todayIso,
        profile: profile,
      );

      // Score reduced significantly due to sleep debt (-25) and checkin soreness/fatigue
      expect(decision.value, equals(MvReadinessTier.minimal));

      // Verify decision logged in ss_decision_log (Constitution Law 2 & 19)
      final decisionLogs = await db.query('ss_decision_log');
      expect(decisionLogs, isNotEmpty);
      expect(decisionLogs.first['decisionType'], equals('ADAPT_READINESS'));
      expect(decisionLogs.first['rejectionReason'], equals(MvReasonKeys.readinessLow));
    });

    testWidgets('MvContextualBanner renders sleep debt adaptation message', (
      tester,
    ) async {
      const snapshot = RitmoCrossModuleSnapshot(
        dateIso: '2026-09-01',
        sleepMinutesLastNight: 300,
        isSleepDebtHigh: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.build(
            palette: RitmoPalette.jadeNoir,
            brightness: Brightness.dark,
          ),
          home: const Scaffold(
            body: MvContextualBanner(snapshot: snapshot),
          ),
        ),
      );

      expect(find.text('انطباق هوشمند با خواب دیشب'), findsOneWidget);
      expect(
        find.text(
          'به علت خواب کمتر از ۶ ساعت دیشب، برنامهٔ امروز به جلسهٔ سبک تبدیل شد تا بدن فرصت ریکاوری داشته باشد.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('MvContextualBanner renders fasting protocol message', (
      tester,
    ) async {
      const snapshot = RitmoCrossModuleSnapshot(
        dateIso: '2026-09-01',
        isFasting: true,
        goldenPreIftarWindow: '۱۸:۳۰ تا ۱۹:۱۵',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.build(
            palette: RitmoPalette.jadeNoir,
            brightness: Brightness.dark,
          ),
          home: const Scaffold(
            body: MvContextualBanner(snapshot: snapshot),
          ),
        ),
      );

      expect(find.text('پروتکل روزه‌داری و تمرین'), findsOneWidget);
      expect(
        find.text(
          'ساعت بهینه برای تمرین ملایم: ۴۵ دقیقه مانده به افطار (۱۸:۳۰ تا ۱۹:۱۵).',
        ),
        findsOneWidget,
      );
    });

    testWidgets('MvTodayTab renders contextual sleep banner and adapts hero card', (
      tester,
    ) async {
      final now = DateTime.now();
      final todayIso = RitmoDate.dayKey(now);

      final todaySlot = MvSlot(
        id: 'slot_today_1',
        dateIso: todayIso,
        slotType: MvSlotType.strength,
        status: MvSlotStatus.planned,
        headlineFa: 'تمرین قدرتی بالاتنه',
        intensityTier: MvIntensityTier.moderate,
        targetMinutes: 30,
        focusCodes: const ['CHEST'],
        createdAt: 1000,
        updatedAt: 1000,
      );

      const snapshot = RitmoCrossModuleSnapshot(
        dateIso: '2026-09-01',
        sleepMinutesLastNight: 300,
        isSleepDebtHigh: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.build(
            palette: RitmoPalette.jadeNoir,
            brightness: Brightness.dark,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: MvTodayTab(
                weekSlots: [todaySlot],
                todaySlot: todaySlot,
                readinessDecision: const MvDecision<MvReadinessTier>(
                  value: MvReadinessTier.minimal,
                  reasonFa: 'به علت کم‌خوابی دیشب دوز حداقل اعمال شد',
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
                onSlotUpdated: (_) {},
                onCheckinSaved: (_) {},
                onQuickLogSaved: (kind, dur, feeling, note) async {},
                onDateSelected: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Contextual Banner is rendered
      expect(find.text('انطباق هوشمند با خواب دیشب'), findsOneWidget);

      // Verify Hero Card title adapted to minimal dose
      expect(find.text('10-Minute Minimum Effective Dose'), findsOneWidget);
    });
  });
}
