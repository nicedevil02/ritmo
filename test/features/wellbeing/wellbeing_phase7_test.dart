import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/analytics/wellbeing_engine.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/wellbeing/presentation/widgets/wellbeing_explanation_sheet.dart';

void main() {
  group('Phase 7 Tests — Explanation Sheet (B25..B26)', () {
    testWidgets('Criterion 1: WellbeingExplanationSheet renders waterfall with 50 base and signal contributions', (tester) async {
      const index = WellbeingIndex(
        value: 72,
        confidence: 0.85,
        contributions: [
          WellbeingContribution(
            signal: WellbeingSignal.sleep,
            score: 80,
            weight: 0.4,
            sampleCount: 7,
            windowDays: 14,
            confidence: 0.9,
            isAiDerived: false,
          ),
          WellbeingContribution(
            signal: WellbeingSignal.energy,
            score: 65,
            weight: 0.3,
            sampleCount: 5,
            windowDays: 14,
            confidence: 0.75,
            isAiDerived: false,
          ),
        ],
        missing: [
          WellbeingMissingSignal(
            signal: WellbeingSignal.mood,
            have: 1,
            need: 3,
          ),
        ],
        computedAtMillis: 1723896000000,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: const [RitmoColors.light]),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: WellbeingExplanationSheet(index: index),
            ),
          ),
        ),
      );

      expect(find.text('سهم هر سیگنال از پایهٔ ۵۰'), findsOneWidget);
      expect(find.text('پایهٔ محاسباتی'), findsOneWidget);
      expect(find.text('شاخص نهایی'), findsOneWidget);
      expect(find.text('سیگنال‌های با دادهٔ ناکافی'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
