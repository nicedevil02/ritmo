import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/goals/models/planning_models.dart';
import 'package:ritmo/features/goals/presentation/widgets/create_commitment_sheet.dart';
import 'package:ritmo/features/goals/presentation/widgets/create_goal_sheet.dart';
import 'package:ritmo/features/goals/presentation/widgets/week_planner_sheet.dart';
import 'package:ritmo/features/goals/presentation/widgets/week_review_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const dummyCycle = PlanningCycle(
    id: 'test_cycle_1',
    horizon: PlanningHorizon.week,
    startDayKey: '2026-08-23',
    endDayKey: '2026-08-29',
    status: CycleStatus.active,
    createdAt: 0,
    activatedAt: 0,
  );

  group('Goals Sheets Glassmorphism Tests', () {
    testWidgets('CreateCommitmentSheet renders BackdropFilter when glass is enabled', (tester) async {
      final glassTheme = RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
        reduceTransparency: false,
        glassBlurSigma: 20.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: glassTheme,
          home: Scaffold(
            body: CreateCommitmentSheet(
              onSaved: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('CreateCommitmentSheet renders opaque container when glass is disabled', (tester) async {
      final opaqueTheme = RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
        reduceTransparency: true,
        glassBlurSigma: 0.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: opaqueTheme,
          home: Scaffold(
            body: CreateCommitmentSheet(
              onSaved: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('WeekPlannerSheet renders BackdropFilter when glass is enabled', (tester) async {
      final glassTheme = RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
        reduceTransparency: false,
        glassBlurSigma: 20.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: glassTheme,
          home: Scaffold(
            body: WeekPlannerSheet(
              onSaved: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('WeekPlannerSheet renders opaque container when glass is disabled', (tester) async {
      final opaqueTheme = RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
        reduceTransparency: true,
        glassBlurSigma: 0.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: opaqueTheme,
          home: Scaffold(
            body: WeekPlannerSheet(
              onSaved: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('WeekReviewSheet renders BackdropFilter when glass is enabled', (tester) async {
      final glassTheme = RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
        reduceTransparency: false,
        glassBlurSigma: 20.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: glassTheme,
          home: Scaffold(
            body: WeekReviewSheet(
              cycle: dummyCycle,
              allocations: const [],
              commitments: const [],
              onClosed: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('WeekReviewSheet renders opaque container when glass is disabled', (tester) async {
      final opaqueTheme = RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
        reduceTransparency: true,
        glassBlurSigma: 0.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: opaqueTheme,
          home: Scaffold(
            body: WeekReviewSheet(
              cycle: dummyCycle,
              allocations: const [],
              commitments: const [],
              onClosed: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('CreateGoalSheet renders BackdropFilter when glass is enabled', (tester) async {
      final glassTheme = RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
        reduceTransparency: false,
        glassBlurSigma: 20.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: glassTheme,
          home: Scaffold(
            body: CreateGoalSheet(
              onSaved: () {},
              routines: const [],
              activeGoals: const [],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('CreateGoalSheet renders opaque container when glass is disabled', (tester) async {
      final opaqueTheme = RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
        reduceTransparency: true,
        glassBlurSigma: 0.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: opaqueTheme,
          home: Scaffold(
            body: CreateGoalSheet(
              onSaved: () {},
              routines: const [],
              activeGoals: const [],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(BackdropFilter), findsNothing);
    });
  });
}
