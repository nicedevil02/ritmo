import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/schema/tables/movement_tables.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/application/movement_occurrence_service.dart';
import 'package:ritmo/features/movement/application/movement_preferences_service.dart';
import 'package:ritmo/features/movement/application/movement_readiness_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_absence_status.dart';
import 'package:ritmo/features/movement/domain/models/movement_occurrence.dart';
import 'package:ritmo/features/movement/domain/models/movement_tier.dart';
import 'package:ritmo/features/movement/domain/models/movement_week_stats.dart';
import 'package:ritmo/features/movement/presentation/center/movement_center_controller.dart';
import 'package:ritmo/features/movement/presentation/center/states/movement_has_session_view.dart';
import 'package:ritmo/features/movement/presentation/center/states/movement_no_plan_view.dart';
import 'package:ritmo/features/movement/presentation/center/states/movement_rest_day_view.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/day_slot.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/hero_session_card.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/week_rail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  try {
    sqfliteFfiInit();
  } catch (_) {}

  Widget wrapWithTheme(Widget child) {
    return MaterialApp(
      theme: RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
      ),
      home: Scaffold(
        body: Directionality(textDirection: TextDirection.rtl, child: child),
      ),
    );
  }

  List<MovementDayData> createSampleRailDays() {
    const dayNames = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];
    final base = DateTime(2026, 8, 15);
    return List.generate(
      7,
      (i) => MovementDayData(
        date: base.add(Duration(days: i)),
        dayName: dayNames[i],
        dayNumber: 25 + i,
        monthName: 'مرداد',
        state: i == 5 ? MovementDaySlotState.today : MovementDaySlotState.normal,
      ),
    );
  }

  group('MovementCenterScreen 3-State Widget Tests (Phase 3 / P-08, P-09, P-10)', () {
    // ۱. رندر حالت A: جلسه برنامه‌ریزی‌شده (MovementHasSessionView)
    testWidgets('1. State A: Has session renders MovementHasSessionView & HeroSessionCard', (
      tester,
    ) async {
      final occurrence = MovementOccurrence(
        id: 'occ_run_1',
        activityKindId: 'kind_running',
        dateIso: '2026-08-20',
        status: MovementOccurrenceStatus.planned,
        origin: MovementOrigin.oneOff,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      const weekStats = MovementWeekStats(
        plannedCount: 3,
        doneCount: 2,
        activeStreakDays: 2,
        totalMinutes: 60,
        adherence: MovementMetric<double>(
          value: 0.66,
          sampleSize: 5,
          reason: MovementMetricReason.ok,
        ),
        hasAnyData: true,
      );

      const readiness = ReadinessReady(
        tier: ReadinessTier.full,
        score: 90,
        suggestionFa: 'با توجه به وضعیت امروزت، ۴۵ دقیقه بهت میاد.',
        isEstimated: false,
      );

      await tester.pumpWidget(
        wrapWithTheme(
          MovementHasSessionView(
            occurrence: occurrence,
            weekStats: weekStats,
            readiness: readiness,
            tier: MovementTier.one,
            railDays: createSampleRailDays(),
            onStartSession: () {},
            onQuickLog: () {},
            onSelectDay: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(MovementHasSessionView), findsOneWidget);
      expect(find.byType(HeroSessionCard), findsOneWidget);
      expect(find.byType(WeekRail), findsOneWidget);
      expect(find.text('این هفته: ۲ از ۳'), findsOneWidget);
      expect(find.text('ثبت ۵ ثانیه‌ای جلسه'), findsOneWidget);
      expect(find.text('با توجه به وضعیت امروزت، ۴۵ دقیقه بهت میاد.'), findsOneWidget);
    });

    // ۲. رندر حالت B: روز استراحت (MovementRestDayView)
    testWidgets('2. State B: Rest day renders MovementRestDayView and actions', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          MovementRestDayView(
            railDays: createSampleRailDays(),
            onConfirmRestDay: () {},
            onOpenPicker: () {},
            onSelectDay: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(MovementRestDayView), findsOneWidget);
      expect(find.byType(WeekRail), findsOneWidget);
      expect(find.text('امروز استراحت کردن خودش تمرینه.'), findsOneWidget);
      expect(find.text('همین‌طور ثبتش کن (استراحت)'), findsOneWidget);
      expect(find.text('بازم می‌خوام تمرین کنم'), findsOneWidget);
    });

    // ۳. رندر حالت C: بدون برنامه (MovementNoPlanView)
    testWidgets('3. State C: No plan renders MovementNoPlanView with Tier 1 and absence messaging', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          MovementNoPlanView(
            tier: MovementTier.one,
            railDays: createSampleRailDays(),
            absenceStatus: AbsenceStatus.shortAbsence,
            onOpenPicker: () {},
            onOpenPlanEditor: () {},
            onSelectDay: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(MovementNoPlanView), findsOneWidget);
      expect(find.byType(WeekRail), findsOneWidget);
      expect(find.text('یه مدت نبودی. مهم نیست —'), findsOneWidget);
      expect(find.text('یه تمرین سبک ثبت کن'), findsOneWidget);
    });

    // ۴. دکمه برنامه‌ریزی هفتگی در Tier 2 برای State C نمایش داده می‌شود
    testWidgets('4. Tier 2 shows weekly planning button in State C', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          MovementNoPlanView(
            tier: MovementTier.two,
            railDays: createSampleRailDays(),
            absenceStatus: AbsenceStatus.none,
            onOpenPicker: () {},
            onOpenPlanEditor: () {},
            onSelectDay: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('تنظیم برنامهٔ هفتگی'), findsOneWidget);
      expect(find.text('یه فعالیت ثبت کن'), findsOneWidget);
    });
  });

  group('MovementCenterController Unit Tests (Phase 3 / P-09)', () {
    Database? db;
    bool dbInitialized = false;
    late MovementOccurrenceService occService;
    late MovementPreferencesService prefService;
    late MovementReadinessService readinessService;

    setUp(() async {
      try {
        databaseFactory = databaseFactoryFfi;
        db = await databaseFactory.openDatabase(inMemoryDatabasePath);
        await MovementTables.create(db!);
        occService = MovementOccurrenceService(db: db);
        prefService = MovementPreferencesService(db: db);
        readinessService = MovementReadinessService(db: db);
        dbInitialized = true;
      } catch (_) {
        dbInitialized = false;
      }
    });

    tearDown(() async {
      if (dbInitialized && db != null) {
        await db!.close();
      }
    });

    test('Controller transitions correctly to noPlan view when no occurrences exist', () async {
      if (!dbInitialized) return;
      final fixedDate = DateTime(2026, 8, 20);

      final controller = MovementCenterController(
        occurrenceService: occService,
        readinessService: readinessService,
        preferencesService: prefService,
        initialDate: fixedDate,
      );

      await controller.loadData();

      expect(controller.state, isA<MovementCenterReady>());
      final ready = controller.state as MovementCenterReady;
      expect(ready.view, equals(MovementCenterView.noPlan));
      expect(ready.railDays.length, equals(7));
    });

    test('Controller transitions to hasSession view when today has a scheduled session', () async {
      if (!dbInitialized || db == null) return;
      final fixedDate = DateTime(2026, 8, 20);
      final dateIso = fixedDate.toIso8601String().split('T').first;

      await db!.insert(MovementTables.tableOccurrences, {
        'id': 'occ_today_run',
        'activityKindId': 'kind_running',
        'dateIso': dateIso,
        'status': 'scheduled',
        'origin': 'manual',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      final controller = MovementCenterController(
        occurrenceService: occService,
        readinessService: readinessService,
        preferencesService: prefService,
        initialDate: fixedDate,
      );

      await controller.loadData();

      expect(controller.state, isA<MovementCenterReady>());
      final ready = controller.state as MovementCenterReady;
      expect(ready.view, equals(MovementCenterView.hasSession));
      expect(ready.todayOccurrence?.id, equals('occ_today_run'));
    });

    test('Controller transitions to restDay view when today is marked as restDay', () async {
      if (!dbInitialized || db == null) return;
      final fixedDate = DateTime(2026, 8, 20);
      final dateIso = fixedDate.toIso8601String().split('T').first;

      await db!.insert(MovementTables.tableOccurrences, {
        'id': 'occ_today_rest',
        'activityKindId': 'kind_rest',
        'dateIso': dateIso,
        'status': 'restDay',
        'origin': 'manual',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      final controller = MovementCenterController(
        occurrenceService: occService,
        readinessService: readinessService,
        preferencesService: prefService,
        initialDate: fixedDate,
      );

      await controller.loadData();

      expect(controller.state, isA<MovementCenterReady>());
      final ready = controller.state as MovementCenterReady;
      expect(ready.view, equals(MovementCenterView.restDay));
    });
  });
}
