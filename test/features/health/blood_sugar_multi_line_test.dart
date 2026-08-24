import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/theme/ritmo_palette.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/health/models/health_models.dart';
import 'package:ritmo/features/health/presentation/widgets/blood_sugar_section.dart';
import 'package:ritmo/l10n/app_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => '.',
        );
  });

  group('BloodSugarLog Model & Category Enhancements', () {
    test('categoryColor and categoryLabel return distinct values per type', () {
      final fasting = BloodSugarLog(
        id: 'bs_1',
        value: 95,
        measurementType: 'FASTING',
        loggedAt: 1000,
      );
      expect(fasting.categoryLabel, 'ناشتا');
      expect(fasting.categoryColor, const Color(0xFF06B6D4));

      final afterMeal = BloodSugarLog(
        id: 'bs_2',
        value: 145,
        measurementType: 'AFTER_MEAL',
        loggedAt: 2000,
      );
      expect(afterMeal.categoryLabel, 'بعد غذا');
      expect(afterMeal.categoryColor, const Color(0xFFF59E0B));

      final beforeMeal = BloodSugarLog(
        id: 'bs_3',
        value: 105,
        measurementType: 'BEFORE_MEAL',
        loggedAt: 3000,
      );
      expect(beforeMeal.categoryLabel, 'قبل غذا');
      expect(beforeMeal.categoryColor, const Color(0xFF6366F1));

      final bedtime = BloodSugarLog(
        id: 'bs_4',
        value: 120,
        measurementType: 'BEDTIME',
        loggedAt: 4000,
      );
      expect(bedtime.categoryLabel, 'قبل خواب');
      expect(bedtime.categoryColor, const Color(0xFF8B5CF6));

      final random = BloodSugarLog(
        id: 'bs_5',
        value: 110,
        measurementType: 'RANDOM',
        loggedAt: 5000,
      );
      expect(random.categoryLabel, 'تصادفی');
      expect(random.categoryColor, const Color(0xFFEC4899));
    });

    test('BloodSugarTargetRange adapts accurately for diabetic and non-diabetic', () {
      // Non-diabetic
      final fNorm = BloodSugarTargetRange.forCategory('FASTING', isDiabetic: false);
      expect(fNorm.min, 70);
      expect(fNorm.max, 100);

      final amNorm = BloodSugarTargetRange.forCategory('AFTER_MEAL', isDiabetic: false);
      expect(amNorm.min, 70);
      expect(amNorm.max, 140);

      final btNorm = BloodSugarTargetRange.forCategory('BEDTIME', isDiabetic: false);
      expect(btNorm.min, 100);
      expect(btNorm.max, 140);

      // Diabetic
      final fDiab = BloodSugarTargetRange.forCategory('FASTING', isDiabetic: true);
      expect(fDiab.min, 80);
      expect(fDiab.max, 130);

      final amDiab = BloodSugarTargetRange.forCategory('AFTER_MEAL', isDiabetic: true);
      expect(amDiab.min, 80);
      expect(amDiab.max, 180);

      final btDiab = BloodSugarTargetRange.forCategory('BEDTIME', isDiabetic: true);
      expect(btDiab.min, 100);
      expect(btDiab.max, 150);
    });

    test('getStatus accurately classifies LOW, NORMAL, HIGH', () {
      final logLow = BloodSugarLog(id: '1', value: 65, measurementType: 'FASTING', loggedAt: 1000);
      expect(logLow.getStatus(false), 'LOW');

      final logNormNonDiab = BloodSugarLog(id: '2', value: 95, measurementType: 'FASTING', loggedAt: 1000);
      expect(logNormNonDiab.getStatus(false), 'NORMAL');

      final logHighNonDiab = BloodSugarLog(id: '3', value: 120, measurementType: 'FASTING', loggedAt: 1000);
      expect(logHighNonDiab.getStatus(false), 'HIGH');
      expect(logHighNonDiab.getStatus(true), 'NORMAL'); // 120 is in range for diabetic fasting (80-130)

      final logHighDiab = BloodSugarLog(id: '4', value: 200, measurementType: 'AFTER_MEAL', loggedAt: 1000);
      expect(logHighDiab.getStatus(true), 'HIGH');
    });
  });

  group('BloodSugarStats Clinical Computation', () {
    test('calculates accurate averages, TIR percentages, and ADA HbA1c estimate', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final logs = [
        BloodSugarLog(id: '1', value: 90, measurementType: 'FASTING', loggedAt: now - 3000), // in-range
        BloodSugarLog(id: '2', value: 100, measurementType: 'FASTING', loggedAt: now - 2000), // in-range
        BloodSugarLog(id: '3', value: 160, measurementType: 'AFTER_MEAL', loggedAt: now - 1000), // in-range (diab) / high (non-diab)
        BloodSugarLog(id: '4', value: 60, measurementType: 'RANDOM', loggedAt: now), // low
      ];

      // Diabetic calculation
      final statsDiab = BloodSugarStats.compute(logs, isDiabetic: true)!;
      expect(statsDiab.totalCount, 4);
      expect(statsDiab.minGlucose, 60);
      expect(statsDiab.maxGlucose, 160);
      expect(statsDiab.averageGlucose, 102.5);
      expect(statsDiab.averageFasting, 95.0);
      expect(statsDiab.lowPercentage, 25.0); // 1 out of 4 is < 70
      expect(statsDiab.inRangePercentage, 75.0); // 90, 100, 160 are in range for diabetic
      expect(statsDiab.highPercentage, 0.0);
      // HbA1c estimate = (102.5 + 46.7) / 28.7 = 5.2
      expect(statsDiab.estimatedHbA1c, closeTo(5.2, 0.1));

      // Non-diabetic calculation
      final statsNorm = BloodSugarStats.compute(logs, isDiabetic: false)!;
      expect(statsNorm.lowPercentage, 25.0);
      expect(statsNorm.inRangePercentage, 50.0); // 90, 100 in range; 160 high; 60 low
      expect(statsNorm.highPercentage, 25.0);
    });

    test('returns null for empty logs', () {
      expect(BloodSugarStats.compute([], isDiabetic: false), isNull);
    });
  });

  group('BloodSugarSection Widget Tests', () {
    late Database db;

    setUp(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE IF NOT EXISTS app_settings (key TEXT PRIMARY KEY, value TEXT, updatedAt INTEGER)',
          );
          await db.execute(
            'CREATE TABLE IF NOT EXISTS blood_sugar_logs (id TEXT PRIMARY KEY, value INTEGER, measurementType TEXT, note TEXT, loggedAt INTEGER)',
          );
        },
      );
      DatabaseHelper.instance.overrideDatabaseForTesting(db);
    });

    tearDown(() async {
      await db.close();
      DatabaseHelper.databaseInstance = null;
    });

    Widget createTestWidget() {
      return MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('fa')],
        locale: const Locale('fa'),
        theme: RitmoTheme.build(
          palette: RitmoPalette.jadeNoir,
          brightness: Brightness.dark,
        ),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: BloodSugarSection(),
          ),
        ),
      );
    }

    testWidgets('renders blood sugar section with filters and empty state', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('قند خون'), findsWidgets);
      expect(find.text('کاربر مبتلا به دیابت است'), findsOneWidget);
      expect(find.text('۷ روز'), findsOneWidget);
      expect(find.text('۱۴ روز'), findsOneWidget);
      expect(find.text('۳۰ روز'), findsOneWidget);
      expect(find.text('همه سوابق'), findsOneWidget);
      expect(find.text('همه (چندخطی)'), findsOneWidget);
      expect(find.text('ناشتا'), findsWidgets);
      expect(find.text('بعد غذا'), findsWidgets);
      expect(find.text('داده‌ای برای بازه یا دسته انتخابی یافت نشد'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('logs entry and renders multi-line chart, stats card, and history', (tester) async {
      final now = DateTime.now().millisecondsSinceEpoch;

      // Insert diverse multi-category logs
      await db.insert('blood_sugar_logs', {
        'id': 'bs_test_1',
        'value': 95,
        'measurementType': 'FASTING',
        'note': 'آزمایش صبح ناشتا',
        'loggedAt': now - 3600000 * 4,
      });
      await db.insert('blood_sugar_logs', {
        'id': 'bs_test_2',
        'value': 140,
        'measurementType': 'AFTER_MEAL',
        'note': 'بعد از ناهار',
        'loggedAt': now - 3600000 * 2,
      });
      await db.insert('blood_sugar_logs', {
        'id': 'bs_test_3',
        'value': 110,
        'measurementType': 'BEDTIME',
        'note': 'قبل خواب',
        'loggedAt': now,
      });

      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Clinical TIR Stats card should be rendered
      expect(find.text('تحلیل و وضعیت بالینی (TIR)'), findsOneWidget);
      expect(find.text('در محدوده هدف'), findsOneWidget);
      expect(find.text('میانگین کل'), findsOneWidget);

      // History should list items
      expect(find.text('آزمایش صبح ناشتا'), findsOneWidget);
      expect(find.text('بعد از ناهار'), findsOneWidget);
      expect(find.text('قبل خواب'), findsWidgets);

      // Tap on Category Filter Chip (ناشتا)
      final fastingChip = find.widgetWithText(FilterChip, 'ناشتا (۱)');
      expect(fastingChip, findsOneWidget);
      await tester.tap(fastingChip);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Filtered to Fasting only
      expect(find.text('آزمایش صبح ناشتا'), findsOneWidget);
      expect(find.text('بعد از ناهار'), findsNothing);

      // Clean unmount
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });
  });
}
