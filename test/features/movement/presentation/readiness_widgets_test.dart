import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/application/movement_readiness_service.dart';
import 'package:ritmo/features/movement/presentation/readiness/widgets/coach_suggestion_card.dart';
import 'package:ritmo/features/movement/presentation/readiness/widgets/readiness_result_card.dart';
import 'package:ritmo/features/movement/presentation/readiness/widgets/scale_selector.dart';

void main() {
  Widget createTestWidget(Widget child) {
    return MaterialApp(
      theme: RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
      ),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: child),
      ),
    );
  }

  group('Readiness & Coach Widgets Tests (Gate 5)', () {
    testWidgets('ScaleSelector renders 5 distinct buttons and fires callback', (
      tester,
    ) async {
      int? selected;
      await tester.pumpWidget(
        createTestWidget(
          ScaleSelector(
            title: 'کیفیت خواب',
            selectedValue: selected,
            onChanged: (val) => selected = val,
          ),
        ),
      );

      expect(find.text('کیفیت خواب'), findsOneWidget);
      expect(find.text('۱'), findsOneWidget);
      expect(find.text('۵'), findsOneWidget);

      await tester.tap(find.text('۴'));
      await tester.pump();

      expect(selected, equals(4));
    });

    testWidgets(
      'ReadinessResultCard renders descriptive status and suggestions',
      (tester) async {
        const eval = ReadinessEvaluationResult(
          statusHeadline: 'آمادگی مطلوب برای تمرین',
          reasonSummary: 'خواب کافی و انرژی بالا',
          suggestions: ['ادامه طبق برنامه', 'افزایش چالش'],
        );

        await tester.pumpWidget(
          createTestWidget(const ReadinessResultCard(result: eval)),
        );

        expect(find.text('آمادگی مطلوب برای تمرین'), findsOneWidget);
        expect(find.text('خواب کافی و انرژی بالا'), findsOneWidget);
        expect(find.text('ادامه طبق برنامه'), findsOneWidget);
        expect(find.text('افزایش چالش'), findsOneWidget);
      },
    );

    testWidgets('CoachSuggestionCard renders 3 layers with 3 action buttons', (
      tester,
    ) async {
      bool accepted = false;
      bool adjusted = false;
      bool dismissed = false;

      const sug = CoachSuggestion(
        id: 'sug_test',
        text: 'پیشنهاد Plan B برای ریکاوری بهتر',
        reason: 'خستگی عضلانی',
        primaryActionLabel: 'پذیرش',
        secondaryActionLabel: 'تغییر',
        dismissActionLabel: 'رد کردن',
      );

      await tester.pumpWidget(
        createTestWidget(
          CoachSuggestionCard(
            suggestion: sug,
            onAccept: () => accepted = true,
            onAdjust: () => adjusted = true,
            onDismiss: () => dismissed = true,
          ),
        ),
      );

      expect(find.text('پیشنهاد Plan B برای ریکاوری بهتر'), findsOneWidget);
      expect(find.text('خستگی عضلانی'), findsOneWidget);

      await tester.tap(find.text('پذیرش'));
      expect(accepted, isTrue);

      await tester.tap(find.text('تغییر'));
      expect(adjusted, isTrue);

      await tester.tap(find.text('رد کردن'));
      expect(dismissed, isTrue);
    });
  });
}
