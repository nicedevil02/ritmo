import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/app_mode/app_mode_service.dart';
import 'package:ritmo/core/navigation/shell_metrics.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/today/presentation/widgets/ritmo_nav_bar.dart';

void main() {
  group('NAV0-5 & NAV2: RitmoNavBar Contract & Destination Tests', () {
    Widget buildTestHarness(AppMode mode, {int? currentIndex, ValueChanged<int>? onSelectTab, VoidCallback? onCenterTap}) {
      return MaterialApp(
        theme: RitmoTheme.dark(),
        home: Scaffold(
          body: Center(
            child: RitmoNavBar(
              mode: mode,
              currentIndex: currentIndex ?? RitmoShellMetrics.defaultTabFor(mode),
              onSelectTab: onSelectTab ?? (_) {},
              onCenterTap: onCenterTap ?? () {},
            ),
          ),
        ),
      );
    }

    testWidgets('RitmoNavBar in AppMode.simple has exact height equal to RitmoShellMetrics.navBarHeight', (tester) async {
      await tester.pumpWidget(buildTestHarness(AppMode.simple));
      await tester.pumpAndSettle();

      final navBarFinder = find.byType(RitmoNavBar);
      expect(navBarFinder, findsOneWidget);

      final size = tester.getSize(navBarFinder);
      expect(size.height, equals(RitmoShellMetrics.navBarHeight));
    });

    testWidgets('RitmoNavBar in AppMode.full has exact height equal to RitmoShellMetrics.navBarHeight', (tester) async {
      await tester.pumpWidget(buildTestHarness(AppMode.full));
      await tester.pumpAndSettle();

      final navBarFinder = find.byType(RitmoNavBar);
      expect(navBarFinder, findsOneWidget);

      final size = tester.getSize(navBarFinder);
      expect(size.height, equals(RitmoShellMetrics.navBarHeight));
    });

    testWidgets('Only active tab displays text label in full mode', (tester) async {
      // In full mode, tab 3 is assistant, tab 4 is calendar, tab 0 is systems, tab 1 is insights
      // Center tab is 2 (NowDashboard)
      await tester.pumpWidget(buildTestHarness(AppMode.full, currentIndex: 3));
      await tester.pumpAndSettle();

      expect(find.text('دستیار'), findsOneWidget);
      expect(find.text('تقویم'), findsNothing);
      expect(find.text('سیستم‌ها'), findsNothing);
      expect(find.text('بینش‌ها'), findsNothing);
    });

    testWidgets('Tapping tab invokes onSelectTab callback', (tester) async {
      int? selectedIndex;
      await tester.pumpWidget(buildTestHarness(AppMode.full, currentIndex: 2, onSelectTab: (idx) {
        selectedIndex = idx;
      }));
      await tester.pumpAndSettle();

      // Tap Assistant tab (find by sparkles icon)
      final assistantIconFinder = find.byIcon(CupertinoIcons.sparkles);
      expect(assistantIconFinder, findsOneWidget);
      await tester.tap(assistantIconFinder);
      await tester.pumpAndSettle();

      expect(selectedIndex, equals(3));
    });
  });
}
