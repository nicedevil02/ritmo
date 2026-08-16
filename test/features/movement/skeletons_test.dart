import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';
import 'package:ritmo/features/movement/presentation/common/skeletons.dart';

Widget _wrap(Widget child, {bool disableAnimations = false}) {
  return MaterialApp(
    theme: RitmoTheme.build(
      palette: RitmoPalette.jadeNoir,
      brightness: Brightness.dark,
    ),
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: MediaQuery(
        data: MediaQueryData(
          disableAnimations: disableAnimations,
          size: const Size(400, 800),
          padding: const EdgeInsets.only(top: 24),
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            child: child,
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Skeletons Widget & Layout Height Tests (Point 5)', () {
    testWidgets('Every skeleton matches the exact height constant from MovementLayout (Zero Layout Shifts)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HeroSkeleton(),
              SessionCardSkeleton(),
              WeekRailSkeleton(),
              ChartSkeleton(),
              ListRowSkeleton(),
            ],
          ),
        ),
      );

      // 1. HeroSkeleton matches kHeroMinHeight = 152.0
      final heroSize = tester.getSize(find.byType(HeroSkeleton));
      expect(heroSize.height, equals(MovementLayout.kHeroMinHeight));
      expect(heroSize.height, equals(152.0));

      // 2. SessionCardSkeleton matches kSessionCardMinHeight = 72.0
      final sessionCardSize = tester.getSize(find.byType(SessionCardSkeleton));
      expect(sessionCardSize.height, equals(MovementLayout.kSessionCardMinHeight));
      expect(sessionCardSize.height, equals(72.0));

      // 3. WeekRailSkeleton matches kWeekRailHeight = 76.0
      final weekRailSize = tester.getSize(find.byType(WeekRailSkeleton));
      expect(weekRailSize.height, equals(MovementLayout.kWeekRailHeight));
      expect(weekRailSize.height, equals(76.0));

      // 4. ChartSkeleton matches kChartCardHeight = 220.0
      final chartSize = tester.getSize(find.byType(ChartSkeleton));
      expect(chartSize.height, equals(MovementLayout.kChartCardHeight));
      expect(chartSize.height, equals(220.0));

      // 5. ListRowSkeleton matches kSetRowHeight = 56.0
      final listRowSize = tester.getSize(find.byType(ListRowSkeleton));
      expect(listRowSize.height, equals(MovementLayout.kSetRowHeight));
      expect(listRowSize.height, equals(56.0));
    });

    testWidgets('Disables shimmer animation when reduce motion (disableAnimations) is true', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const HeroSkeleton(),
          disableAnimations: true,
        ),
      );

      await tester.pump();
      expect(find.byType(HeroSkeleton), findsOneWidget);
      expect(find.byType(MovementSkeletonBox), findsWidgets);
    });
  });
}
