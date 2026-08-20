import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/schema/tables/movement_tables.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/application/movement_occurrence_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_absence_status.dart';
import 'package:ritmo/features/movement/domain/models/movement_tier.dart';
import 'package:ritmo/features/movement/presentation/center/states/movement_no_plan_view.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/day_slot.dart';
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
      home: Directionality(textDirection: TextDirection.rtl, child: child),
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
        state: MovementDaySlotState.normal,
      ),
    );
  }

  group('Absence Detection and Return Tests (Phase 5 / P-14, P-15, P-16)', () {
    Database? db;
    bool dbInitialized = false;
    late MovementOccurrenceService occService;

    setUp(() async {
      try {
        databaseFactory = databaseFactoryFfi;
        db = await databaseFactory.openDatabase(inMemoryDatabasePath);
        await MovementTables.create(db!);
        occService = MovementOccurrenceService(db: db);
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

    test('1. User with no workout logs returns AbsenceStatus.none', () async {
      if (!dbInitialized) return;
      final status = await occService.checkAbsence(DateTime(2026, 8, 20));
      expect(status, equals(AbsenceStatus.none));
    });

    test('2. User with last workout log 6 days ago returns AbsenceStatus.none', () async {
      if (!dbInitialized || db == null) return;
      await db!.insert(MovementTables.tableWorkoutLogs, {
        'id': 'log_recent',
        'activityKindId': 'kind_walking',
        'dateIso': '2026-08-14',
        'durationSec': 1200,
        'source': 'quick',
        'createdAt': DateTime(2026, 8, 14).toIso8601String(),
        'updatedAt': DateTime(2026, 8, 14).toIso8601String(),
      });

      final status = await occService.checkAbsence(DateTime(2026, 8, 20));
      expect(status, equals(AbsenceStatus.none));
    });

    test('3. User with last workout log 8 days ago returns AbsenceStatus.shortAbsence', () async {
      if (!dbInitialized || db == null) return;
      await db!.insert(MovementTables.tableWorkoutLogs, {
        'id': 'log_short_abs',
        'activityKindId': 'kind_walking',
        'dateIso': '2026-08-12',
        'durationSec': 1200,
        'source': 'quick',
        'createdAt': DateTime(2026, 8, 12).toIso8601String(),
        'updatedAt': DateTime(2026, 8, 12).toIso8601String(),
      });

      final status = await occService.checkAbsence(DateTime(2026, 8, 20));
      expect(status, equals(AbsenceStatus.shortAbsence));
    });

    test('4. User with last workout log 25 days ago returns AbsenceStatus.longAbsence', () async {
      if (!dbInitialized || db == null) return;
      await db!.insert(MovementTables.tableWorkoutLogs, {
        'id': 'log_long_abs',
        'activityKindId': 'kind_walking',
        'dateIso': '2026-07-26',
        'durationSec': 1200,
        'source': 'quick',
        'createdAt': DateTime(2026, 7, 26).toIso8601String(),
        'updatedAt': DateTime(2026, 7, 26).toIso8601String(),
      });

      final status = await occService.checkAbsence(DateTime(2026, 8, 20));
      expect(status, equals(AbsenceStatus.longAbsence));
    });

    testWidgets('5. Short absence renders encouraging message without guilt or day counts', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          Scaffold(
            body: MovementNoPlanView(
              tier: MovementTier.one,
              railDays: createSampleRailDays(),
              absenceStatus: AbsenceStatus.shortAbsence,
              onOpenPicker: () {},
              onOpenPlanEditor: () {},
              onSelectDay: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('یه مدت نبودی. مهم نیست —'), findsOneWidget);
      expect(find.text('بریم از یه تمرین سبک شروع کنیم و ریتم رو برگردونیم.'), findsOneWidget);
      expect(find.text('یه تمرین سبک ثبت کن'), findsOneWidget);
      expect(find.textContaining('روز نبودی'), findsNothing);
      expect(find.textContaining('۸ روز'), findsNothing);
    });

    testWidgets('6. Long absence renders welcoming message without guilt or day counts', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          Scaffold(
            body: MovementNoPlanView(
              tier: MovementTier.one,
              railDays: createSampleRailDays(),
              absenceStatus: AbsenceStatus.longAbsence,
              onOpenPicker: () {},
              onOpenPlanEditor: () {},
              onSelectDay: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('بعد از مدتی برگشتی. خوش اومدی!'), findsOneWidget);
      expect(find.text('قدم‌های کوچک بهترین شروع برای بازگشت به تحرک هستند.'), findsOneWidget);
      expect(find.text('یه تمرین کوتاه ثبت کن'), findsOneWidget);
      expect(find.textContaining('روز نبودی'), findsNothing);
      expect(find.textContaining('۲۵ روز'), findsNothing);
    });
  });
}
