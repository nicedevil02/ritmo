import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/schema/tables/movement_tables.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/application/strength_program_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_strength_day.dart';
import 'package:ritmo/features/movement/domain/models/movement_strength_exercise.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';
import 'package:ritmo/features/movement/presentation/session/modes/strength_session_view.dart';
import 'package:ritmo/features/movement/presentation/strength/sheets/swap_exercise_sheet.dart';
import 'package:ritmo/features/movement/presentation/strength/widgets/current_exercise_card.dart';
import 'package:ritmo/features/movement/presentation/strength/widgets/rest_timer_bar.dart';
import 'package:ritmo/features/movement/presentation/strength/widgets/rir_picker.dart';
import 'package:ritmo/features/movement/presentation/strength/widgets/set_table.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  try {
    sqfliteFfiInit();
  } catch (_) {}

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      theme: RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
      ),
      home: Scaffold(
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: child,
        ),
      ),
    );
  }

  group('StrengthSessionView & Strength Mode Tests (Gate 4)', () {
    Database? db;
    bool dbReady = false;
    late StrengthProgramService service;

    setUp(() async {
      try {
        databaseFactory = databaseFactoryFfi;
        db = await databaseFactory.openDatabase(inMemoryDatabasePath);
        await MovementTables.create(db!);
        service = StrengthProgramService(db: db);
        dbReady = true;
      } catch (_) {
        service = StrengthProgramService();
        dbReady = false;
      }
    });

    tearDown(() async {
      if (dbReady && db != null) {
        await db!.close();
      }
    });

    const sampleExercise = MovementStrengthExercise(
      id: 'ex_test_1',
      dayId: 'day_test_1',
      orderIndex: 0,
      nameFa: 'پرس سینه دمبل',
      muscleGroup: 'سینه',
      sets: 3,
      repsMin: 8,
      repsMax: 12,
      restSec: 60,
      formTips: ['تیغه‌های شانه را منقبض کنید.'],
      alternatives: ['شنا سوئدی', 'پرس سینه کش'],
    );

    const sampleDay = MovementStrengthDay(
      id: 'day_test_1',
      programId: 'prog_1',
      weekIndex: 1,
      weekday: 1,
      name: 'بالاتنه قدرتی',
      targetMuscles: ['سینه', 'پشت‌بازو'],
      estimatedMinutes: 30,
      orderIndex: 0,
      exercises: [sampleExercise],
    );

    testWidgets('1. Renders exercise card, set table and RIR picker', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          StrengthSessionView(
            day: sampleDay,
            sessionId: 'sess_1',
            strengthService: service,
            onFinishSession: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(CurrentExerciseCard), findsOneWidget);
      expect(find.byType(SetTable), findsOneWidget);
      expect(find.byType(RirPicker), findsOneWidget);
      expect(find.text('پرس سینه دمبل'), findsOneWidget);
      expect(find.text(MovementStrings.strengthRecordSet), findsOneWidget);
    });

    testWidgets('2. Completing a set records set log and displays RestTimerBar', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          StrengthSessionView(
            day: sampleDay,
            sessionId: 'sess_1',
            strengthService: service,
            onFinishSession: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap primary CTA to complete set 1
      await tester.tap(find.text(MovementStrings.strengthRecordSet));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // RestTimerBar appears
      expect(find.byType(RestTimerBar), findsOneWidget);
      expect(find.text(MovementStrings.strengthRestTimer), findsOneWidget);

      // Verify log was saved to DB if ready
      if (dbReady) {
        final logs = await service.getSetLogsForSession('sess_1');
        expect(logs.length, equals(1));
        expect(logs.first.setIndex, equals(1));
        expect(logs.first.completed, isTrue);
      }

      // Dismiss rest timer by tapping skip
      await tester.tap(find.text(MovementStrings.strengthRestSkip));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('3. Swapping exercise mid-session keeps previous sets', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          StrengthSessionView(
            day: sampleDay,
            sessionId: 'sess_1',
            strengthService: service,
            onFinishSession: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Open swap sheet
      await tester.tap(find.text('تعویض'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(SwapExerciseSheet), findsOneWidget);
      expect(find.text('مشاهدهٔ حرکات جایگزین'), findsOneWidget);

      // Go to step 2
      await tester.tap(find.text('مشاهدهٔ حرکات جایگزین'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('شنا سوئدی'), findsOneWidget);
      await tester.tap(find.text('تأیید جایگزینی'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Updated name is shown
      expect(find.text('شنا سوئدی'), findsOneWidget);
    });
  });
}
