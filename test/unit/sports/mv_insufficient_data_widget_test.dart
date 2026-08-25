import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/insight_engine.dart';
import 'package:ritmo/features/supplementary_sports/presentation/components/mv_insufficient_data.dart';
import 'package:ritmo/features/supplementary_sports/presentation/screens/mv_progress_tab.dart';

void main() {
  group('MvInsufficientData Presentation Verification (S0-T7)', () {
    testWidgets('Empty repositories state in MvProgressTab renders MvInsufficientData widgets without fake numbers', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MvProgressTab(
              continuousActiveWeeks: null,
              totalSessionsCount: 0,
              totalMetMinutes: 0.0,
              personalRecords: [],
              bodyMapDistribution: MvBodyMapDistribution(
                muscleSessionCounts: {},
              ),
              hasEnoughDataForTrends: false,
            ),
          ),
        ),
      );

      // Verify that MvInsufficientData widgets are rendered
      expect(find.byType(MvInsufficientData), findsAtLeastNWidgets(3));

      // Verify that no fake stats or numbers are displayed
      expect(find.text('0 هفته'), findsNothing);
      expect(find.text('0 جلسه'), findsNothing);
    });
  });
}
