import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/goals/presentation/widgets/create_commitment_sheet.dart';
import 'package:ritmo/features/goals/presentation/widgets/week_planner_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
      expect(find.text('افزودن تعهد جدید'), findsOneWidget);
    });

    testWidgets('CreateCommitmentSheet renders opaque container when glass is disabled', (tester) async {
      final opaqueTheme = RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
        reduceTransparency: true,
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
      expect(find.text('افزودن تعهد جدید'), findsOneWidget);
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
  });
}
