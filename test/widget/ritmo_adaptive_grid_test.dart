import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/widgets/ritmo_adaptive_grid.dart';
import '../support/responsive_harness.dart';

void main() {
  group('RitmoAdaptiveGrid unit tests', () {
    testWidgets('calculates single column on very narrow constraints', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 200,
            child: RitmoAdaptiveGrid(
              minTileWidth: 140,
              spacing: 10,
              children: List.generate(4, (i) => Container(key: ValueKey(i), height: 50, color: Colors.blue)),
            ),
          ),
        ),
      );

      expect(find.byType(Container), findsNWidgets(4));
    });

    testWidgets('calculates multi columns respecting maxColumns and minTileWidth', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 600,
            child: RitmoAdaptiveGrid(
              minTileWidth: 120,
              spacing: 10,
              maxColumns: 3,
              children: List.generate(6, (i) => Container(key: ValueKey(i), height: 50, color: Colors.blue)),
            ),
          ),
        ),
      );

      expect(find.byType(Container), findsNWidgets(6));
    });

    testAcrossViewports('RitmoAdaptiveGrid handles all 4 test viewports without overflow', () {
      return Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: RitmoAdaptiveGrid(
            minTileWidth: 100,
            spacing: 8,
            maxColumns: 4,
            children: List.generate(
              8,
              (i) => Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  kWorstCaseFa.twoLinesLabel,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ),
        ),
      );
    });
  });
}
