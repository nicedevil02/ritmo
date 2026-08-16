import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/schema/tables/movement_tables.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/application/strength_program_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_strength_program.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';
import 'package:ritmo/features/movement/presentation/strength/onboarding/step_equipment.dart';
import 'package:ritmo/features/movement/presentation/strength/onboarding/step_goal.dart';
import 'package:ritmo/features/movement/presentation/strength/onboarding/step_level_safety.dart';
import 'package:ritmo/features/movement/presentation/strength/onboarding/step_preferences.dart';
import 'package:ritmo/features/movement/presentation/strength/onboarding/step_schedule.dart';
import 'package:ritmo/features/movement/presentation/strength/strength_onboarding_flow.dart';
import 'package:ritmo/features/movement/presentation/strength/strength_program_preview_screen.dart';
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
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: child,
      ),
    );
  }

  group('StrengthOnboardingFlow & Steps Tests (Gate 4)', () {
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

    testWidgets('1. Flow renders 5 steps with Persian step progress string', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          StrengthOnboardingFlow(strengthService: service),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Step 1: StepGoal
      expect(find.text(MovementStrings.strengthStepOf(1)), findsOneWidget);
      expect(find.byType(StepGoal), findsOneWidget);
      expect(find.text('عضله‌سازی و فرم‌دهی'), findsOneWidget);

      // Advance to Step 2
      await tester.tap(find.text('گام بعدی'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Step 2: StepLevelSafety
      expect(find.text(MovementStrings.strengthStepOf(2)), findsOneWidget);
      expect(find.byType(StepLevelSafety), findsOneWidget);
      expect(find.text(MovementStrings.strengthMedicalDisclaimer), findsOneWidget);

      // Advance to Step 3
      await tester.tap(find.text('گام بعدی'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Step 3: StepEquipment
      expect(find.text(MovementStrings.strengthStepOf(3)), findsOneWidget);
      expect(find.byType(StepEquipment), findsOneWidget);

      // Advance to Step 4
      await tester.tap(find.text('گام بعدی'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Step 4: StepSchedule
      expect(find.text(MovementStrings.strengthStepOf(4)), findsOneWidget);
      expect(find.byType(StepSchedule), findsOneWidget);

      // Advance to Step 5
      await tester.tap(find.text('گام بعدی'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Step 5: StepPreferences
      expect(find.text(MovementStrings.strengthStepOf(5)), findsOneWidget);
      expect(find.byType(StepPreferences), findsOneWidget);
      expect(find.text('مشاهدهٔ برنامه'), findsOneWidget);

      // Finish Step 5 -> Navigates to Preview
      await tester.tap(find.text('مشاهدهٔ برنامه'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(StrengthProgramPreviewScreen), findsOneWidget);
    });

    testWidgets('2. Resuming from existing draft starts at the saved draftStep', (tester) async {
      final draft = MovementStrengthProgram(
        id: 'draft_resume_1',
        status: MovementStrengthProgramStatus.draft,
        draftStep: 3,
        goal: 'strength',
        equipment: const ['dumbbells'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        buildTestableWidget(
          StrengthOnboardingFlow(
            strengthService: service,
            initialDraft: draft,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Starts directly at Step 3
      expect(find.text(MovementStrings.strengthStepOf(3)), findsOneWidget);
      expect(find.byType(StepEquipment), findsOneWidget);
    });
  });
}
