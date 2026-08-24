// test/features/wellbeing/sleep_target_card_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/sleep/models/sleep_models.dart';
import 'package:ritmo/features/wellbeing/presentation/widgets/sleep_target_card.dart';

Widget _wrap(Widget child, {double width = 360}) {
  return MaterialApp(
    theme: ThemeData.light().copyWith(
      extensions: [
        RitmoColors.light,
      ],
    ),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: SingleChildScrollView(child: child),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SleepTargetCard Widget Tests', () {
    testWidgets('1. Renders expanded state with zero overflow on narrow screen (300px)', (tester) async {
      final target = SleepTarget(
        bedtime: '23:30',
        wake: '05:00',
        durationMinutes: 330,
      );

      await tester.pumpWidget(_wrap(
        SleepTargetCard(
          target: target,
          isExpanded: true,
          onEditTap: () {},
          onToggleExpand: () {},
        ),
        width: 300,
      ));

      expect(find.text('هدف و زمان‌بندی خواب'), findsOneWidget);
      expect(find.text('تنظیم'), findsOneWidget);
      expect(find.text('ساعت خواب هدف'), findsOneWidget);
      expect(find.text('ساعت بیداری هدف'), findsOneWidget);
      expect(find.text('مدت خواب مطلوب هدف:'), findsOneWidget);
      expect(find.text('۵ ساعت و ۳۰ دقیقه'), findsOneWidget);

      // Verify no RenderFlex overflow exception
      expect(tester.takeException(), isNull);
    });

    testWidgets('2. Renders collapsed state with concise summary', (tester) async {
      final target = SleepTarget(
        bedtime: '23:30',
        wake: '05:00',
        durationMinutes: 330,
      );

      await tester.pumpWidget(_wrap(
        SleepTargetCard(
          target: target,
          isExpanded: false,
          onEditTap: () {},
          onToggleExpand: () {},
        ),
        width: 340,
      ));

      expect(find.text('هدف: '), findsOneWidget);
      expect(find.text('تنظیم'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('3. Tapping edit and toggle triggers callbacks', (tester) async {
      int editCalls = 0;
      int toggleCalls = 0;
      final target = SleepTarget(
        bedtime: '23:30',
        wake: '05:00',
        durationMinutes: 330,
      );

      await tester.pumpWidget(_wrap(
        SleepTargetCard(
          target: target,
          isExpanded: true,
          onEditTap: () => editCalls++,
          onToggleExpand: () => toggleCalls++,
        ),
      ));

      await tester.tap(find.text('تنظیم'));
      expect(editCalls, 1);

      await tester.tap(find.text('هدف و زمان‌بندی خواب'));
      expect(toggleCalls, 1);
    });
  });
}
