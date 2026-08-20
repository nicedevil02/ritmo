import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/movement_cross_feedback_card.dart';

void main() {
  Widget wrapWithTheme(Widget child) {
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

  group('Movement Cross Feedback Card Tests (Phase 9 / P-24, P-25)', () {
    testWidgets('1. Low sleep (< 6.0) renders sleep encouragement card', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const MovementCrossFeedbackCard(sleepHours: 5.5),
        ),
      );
      await tester.pump();

      expect(
        find.text('امروز خوابت کم بوده. پیاده‌روی سبک پیشنهاد می‌شه.'),
        findsOneWidget,
      );
      expect(
        find.text('تمرین ملایم شاید حالت رو بهتر کنه.'),
        findsNothing,
      );
    });

    testWidgets('2. Low mood (< 3) alone renders mood encouragement card', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const MovementCrossFeedbackCard(moodScore: 2),
        ),
      );
      await tester.pump();

      expect(
        find.text('تمرین ملایم شاید حالت رو بهتر کنه.'),
        findsOneWidget,
      );
      expect(
        find.text('امروز خوابت کم بوده. پیاده‌روی سبک پیشنهاد می‌شه.'),
        findsNothing,
      );
    });

    testWidgets('3. Both low sleep and low mood renders ONLY sleep card (priority)', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const MovementCrossFeedbackCard(
            sleepHours: 5.0,
            moodScore: 2,
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text('امروز خوابت کم بوده. پیاده‌روی سبک پیشنهاد می‌شه.'),
        findsOneWidget,
      );
      expect(
        find.text('تمرین ملایم شاید حالت رو بهتر کنه.'),
        findsNothing,
      );
    });

    testWidgets('4. Normal data renders empty widget without card', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const MovementCrossFeedbackCard(
            sleepHours: 7.5,
            moodScore: 4,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Container), findsNothing);
      expect(
        find.text('امروز خوابت کم بوده. پیاده‌روی سبک پیشنهاد می‌شه.'),
        findsNothing,
      );
      expect(
        find.text('تمرین ملایم شاید حالت رو بهتر کنه.'),
        findsNothing,
      );
    });
  });
}
