import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/tokens/ritmo_breakpoints.dart';
import 'package:ritmo/core/widgets/ritmo_adaptive_grid.dart';
import '../../support/responsive_harness.dart';

void main() {
  group('R-44: RitmoBreakpoints.columnsFor pure logic', () {
    test('320 width with 140 minTileWidth returns 2 columns', () {
      final cols = RitmoBreakpoints.columnsFor(
        availableWidth: 320,
        minTileWidth: 140,
        spacing: 12,
      );
      expect(cols, equals(2));
    });

    test('320 width with 190 minTileWidth returns 1 column', () {
      final cols = RitmoBreakpoints.columnsFor(
        availableWidth: 320,
        minTileWidth: 190,
        spacing: 12,
      );
      expect(cols, equals(1));
    });

    test('390 width with 160 minTileWidth returns 2 columns', () {
      final cols = RitmoBreakpoints.columnsFor(
        availableWidth: 390,
        minTileWidth: 160,
        spacing: 12,
      );
      expect(cols, equals(2));
    });

    test('430 width with 140 minTileWidth returns 2 columns', () {
      final cols = RitmoBreakpoints.columnsFor(
        availableWidth: 430,
        minTileWidth: 140,
        spacing: 12,
      );
      expect(cols, equals(2));
    });

    test('600 width with 140 minTileWidth returns 4 columns capped by maxColumns', () {
      final cols = RitmoBreakpoints.columnsFor(
        availableWidth: 600,
        minTileWidth: 140,
        spacing: 12,
        maxColumns: 4,
      );
      expect(cols, equals(4));
    });
  });

  group('R-44: RitmoAdaptiveGrid widget resilience', () {
    testAcrossViewports('RitmoAdaptiveGrid with 6 Persian cards', () {
      return Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: RitmoAdaptiveGrid(
            minTileWidth: RitmoBreakpoints.tileMinWidthRegular,
            spacing: 12,
            children: List.generate(
              6,
              (index) => Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.star, size: 20, color: Colors.amber),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'کارت ${index + 1}: ${kWorstCaseFa.month}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      kWorstCaseFa.twoLinesLabel,
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  });
}
