import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/tokens/ritmo_breakpoints.dart';
import '../../support/responsive_harness.dart';

void main() {
  group('R-12: RitmoBreakpoints Infrastructure Tests', () {
    test('1. widthClassOf(320) returns compact', () {
      expect(
        RitmoBreakpoints.widthClassOf(320),
        equals(RitmoWidthClass.compact),
      );
    });

    test('2. widthClassOf(359) returns compact (upper boundary)', () {
      expect(
        RitmoBreakpoints.widthClassOf(359),
        equals(RitmoWidthClass.compact),
      );
    });

    test('3. widthClassOf(360) returns regular (lower boundary)', () {
      expect(
        RitmoBreakpoints.widthClassOf(360),
        equals(RitmoWidthClass.regular),
      );
    });

    test('4. widthClassOf(600) returns expanded', () {
      expect(
        RitmoBreakpoints.widthClassOf(600),
        equals(RitmoWidthClass.expanded),
      );
    });

    test('5. heightClassOf(568) returns short', () {
      expect(
        RitmoBreakpoints.heightClassOf(568),
        equals(RitmoHeightClass.short),
      );
    });

    test('6. columnsFor(320, 160, 12) returns 1', () {
      expect(
        RitmoBreakpoints.columnsFor(
          availableWidth: 320,
          minTileWidth: 160,
          spacing: 12,
        ),
        equals(1),
      );
    });

    test('7. columnsFor(390, 160, 12) returns 2', () {
      expect(
        RitmoBreakpoints.columnsFor(
          availableWidth: 390,
          minTileWidth: 160,
          spacing: 12,
        ),
        equals(2),
      );
    });

    test('8. columnsFor(1200, 160, 12, maxColumns: 4) returns 4', () {
      expect(
        RitmoBreakpoints.columnsFor(
          availableWidth: 1200,
          minTileWidth: 160,
          spacing: 12,
          maxColumns: 4,
        ),
        equals(4),
      );
    });

    test('9. columnsFor(10, 160, 12) returns 1 (never zero or negative)', () {
      expect(
        RitmoBreakpoints.columnsFor(
          availableWidth: 10,
          minTileWidth: 160,
          spacing: 12,
        ),
        equals(1),
      );
    });

    testWidgets(
      '10. usableHeight computes height minus system paddings and insets',
      (tester) async {
        double? computedUsableHeight;

        await tester.pumpWidget(
          wrapResponsive(
            Builder(
              builder: (context) {
                computedUsableHeight = RitmoBreakpoints.usableHeight(context);
                return const SizedBox.shrink();
              },
            ),
            size: const Size(400, 800),
            padding: const EdgeInsets.only(top: 24, bottom: 16),
            keyboardInset: 300,
          ),
        );

        // 800 - 24 (top) - 16 (bottom) - 300 (keyboard) = 460
        expect(computedUsableHeight, equals(460.0));
      },
    );
  });
}
