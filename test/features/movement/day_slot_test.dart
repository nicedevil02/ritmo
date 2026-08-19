import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/day_slot.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/day_status_indicators.dart';
import 'package:ritmo/features/movement/presentation/common/movement_semantics.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: RitmoTheme.build(
      palette: RitmoPalette.jadeNoir,
      brightness: Brightness.dark,
    ),
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: MediaQuery(
        data: const MediaQueryData(
          size: Size(400, 800),
          padding: EdgeInsets.only(top: 24),
        ),
        child: Material(child: child),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DaySlot & Semantics Exact Label Tests (Point 3)', () {
    testWidgets(
      'Renders exact full semantics template matching specification: "شنبه ۲۵ مرداد، ۲ جلسه، یکی انجام شده، انتخاب‌شده"',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            DaySlot(
              dayName: 'شنبه',
              dayNumber: 25,
              monthName: 'مرداد',
              state: MovementDaySlotState.selected,
              statuses: const [
                MovementDayStatus.completed,
                MovementDayStatus.planned,
              ],
              sessionCount: 2,
              completedCount: 1,
              onTap: () {},
            ),
          ),
        );

        final semanticsNode = tester.getSemantics(find.byType(DaySlot));
        const expectedLabel =
            'شنبه ۲۵ مرداد، ۲ جلسه، یکی انجام شده، انتخاب‌شده';

        // 1. Exact string match on Semantics label
        expect(semanticsNode.label, equals(expectedLabel));

        // 2. Semantics selected state flag
        expect(
          semanticsNode.getSemanticsData().flagsCollection.isSelected.name,
          equals('isTrue'),
        );
      },
    );

    testWidgets('Today and Selected semantics formats with "امروز، ..."', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          DaySlot(
            dayName: 'یکشنبه',
            dayNumber: 26,
            monthName: 'مرداد',
            state: MovementDaySlotState.todayAndSelected,
            statuses: const [
              MovementDayStatus.completed,
              MovementDayStatus.completed,
            ],
            sessionCount: 2,
            completedCount: 2,
            onTap: () {},
          ),
        ),
      );

      final semanticsNode = tester.getSemantics(find.byType(DaySlot));
      const expectedLabel =
          'امروز، یکشنبه ۲۶ مرداد، ۲ جلسه، ۲ انجام شده، انتخاب‌شده';

      expect(semanticsNode.label, equals(expectedLabel));
      expect(
        semanticsNode.getSemanticsData().flagsCollection.isSelected.name,
        equals('isTrue'),
      );
    });

    testWidgets('Zero sessions semantics formats with "، بدون جلسه"', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          DaySlot(
            dayName: 'دوشنبه',
            dayNumber: 27,
            monthName: 'مرداد',
            state: MovementDaySlotState.normal,
            statuses: const [],
            sessionCount: 0,
            completedCount: 0,
            onTap: () {},
          ),
        ),
      );

      final semanticsNode = tester.getSemantics(find.byType(DaySlot));
      const expectedLabel = 'دوشنبه ۲۷ مرداد، بدون جلسه';

      expect(semanticsNode.label, equals(expectedLabel));
      expect(
        semanticsNode.getSemanticsData().flagsCollection.isSelected.name,
        equals('isFalse'),
      );
    });

    test('MovementSemantics.dayLabel direct unit verification', () {
      final label1 = MovementSemantics.dayLabel(
        dayName: 'شنبه',
        dayNumber: 25,
        monthName: 'مرداد',
        sessionCount: 2,
        completedCount: 1,
        isSelected: true,
        isToday: false,
      );
      expect(
        label1,
        equals('شنبه ۲۵ مرداد، ۲ جلسه، یکی انجام شده، انتخاب‌شده'),
      );

      final label2 = MovementSemantics.dayLabel(
        dayName: 'جمعه',
        dayNumber: 31,
        monthName: 'مرداد',
        sessionCount: 3,
        completedCount: 2,
        isSelected: false,
        isToday: true,
      );
      expect(label2, equals('امروز، جمعه ۳۱ مرداد، ۳ جلسه، ۲ انجام شده'));
    });
  });
}
