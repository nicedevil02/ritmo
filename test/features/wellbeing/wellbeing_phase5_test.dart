import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/wellbeing/presentation/widgets/wellbeing_pulse_chart.dart';

void main() {
  group('Phase 5 Tests — Trend Tab & Pulse Chart (B20..B22)', () {
    testWidgets('Criterion 1: WellbeingPulseChart renders 14 days without overflow', (tester) async {
      final days = List.generate(
        14,
        (i) => WellbeingPulseDayData(
          dateStr: '2026-08-${(i + 1).toString().padLeft(2, '0')}',
          sleepHours: 7.0 + (i % 3),
          energyLevel: 2.0,
          moodScore: 4.0,
          hasReflection: i % 2 == 0,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: const [RitmoColors.light]),
          home: Scaffold(
            body: SingleChildScrollView(
              child: WellbeingPulseChart(days: days),
            ),
          ),
        ),
      );

      expect(find.text('نبض دو هفته'), findsOneWidget);
      expect(find.byType(WellbeingPulseChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Criterion 2: WellbeingPulseChart renders 90 days with horizontal scrolling without negative width crash', (tester) async {
      final days = List.generate(
        90,
        (i) => WellbeingPulseDayData(
          dateStr: '2026-06-${(i + 1).toString().padLeft(2, '0')}',
          sleepHours: 6.5,
          energyLevel: 2.0,
          moodScore: 3.0,
          hasReflection: true,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: const [RitmoColors.light]),
          home: Scaffold(
            body: SingleChildScrollView(
              child: WellbeingPulseChart(days: days),
            ),
          ),
        ),
      );

      expect(find.text('نبض ۹۰ روز اخیر'), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}
