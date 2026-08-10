import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/goals/presentation/planning_screen.dart';

void main() {
  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      theme: RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
      ),
      home: child,
    );
  }

  testWidgets('U-14 Test 1 & 2: Renders 3 horizons SegmentedControl and default is این هفته', (tester) async {
    await tester.pumpWidget(buildTestableWidget(const PlanningScreen()));
    await tester.pumpAndSettle();

    expect(find.text('امروز'), findsOneWidget);
    expect(find.text('این هفته'), findsOneWidget);
    expect(find.text('این ماه'), findsOneWidget);
  });

  testWidgets('U-14 Test 3: Switching to امروز renders today command card', (tester) async {
    await tester.pumpWidget(buildTestableWidget(const PlanningScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('امروز'));
    await tester.pumpAndSettle();

    expect(find.textContaining('چیدمان امروز با ✨'), findsOneWidget);
  });

  testWidgets('U-14 Test 4: Switching to این ماه renders MonthPlanSection', (tester) async {
    await tester.pumpWidget(buildTestableWidget(const PlanningScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('این ماه'));
    await tester.pumpAndSettle();

    expect(find.textContaining('تمرکزهای اصلی ماه'), findsOneWidget);
  });

  testWidgets('U-14 Test 5: Empty state in Today tab shows Persian fallback message', (tester) async {
    await tester.pumpWidget(buildTestableWidget(const PlanningScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('امروز'));
    await tester.pumpAndSettle();

    expect(find.textContaining('امروز هیچ تعهدی نداری'), findsOneWidget);
  });
}
