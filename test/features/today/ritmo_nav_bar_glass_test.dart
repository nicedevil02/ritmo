import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/app_mode/app_mode_service.dart';
import 'package:ritmo/core/navigation/shell_metrics.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/today/presentation/widgets/ritmo_nav_bar.dart';

void main() {
  Widget buildNavBarHarness({
    Brightness brightness = Brightness.light,
    AppMode mode = AppMode.full,
    int? currentIndex,
  }) {
    final theme = RitmoTheme.build(
      palette: RitmoPalette.jadeNoir,
      brightness: brightness,
    );

    return MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: RitmoNavBar(
            mode: mode,
            currentIndex: currentIndex ?? RitmoShellMetrics.defaultTabFor(mode),
            onSelectTab: (_) {},
            onCenterTap: () {},
          ),
        ),
      ),
    );
  }

  group('RitmoNavBar Neumorphic Visual Tests', () {
    testWidgets('renders in light mode without errors', (tester) async {
      await tester.pumpWidget(buildNavBarHarness(brightness: Brightness.light));
      await tester.pumpAndSettle();

      expect(find.byType(RitmoNavBar), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders in dark mode without errors', (tester) async {
      await tester.pumpWidget(buildNavBarHarness(brightness: Brightness.dark));
      await tester.pumpAndSettle();

      expect(find.byType(RitmoNavBar), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders all inactive tabs in full mode with active tab label hidden', (tester) async {
      await tester.pumpWidget(buildNavBarHarness(mode: AppMode.full));
      await tester.pumpAndSettle();

      expect(find.text('خانه'), findsNothing); // Active label is hidden
      expect(find.text('تقویم'), findsOneWidget);
      expect(find.text('دستیار'), findsOneWidget);
      expect(find.text('سیستم‌ها'), findsOneWidget);
      expect(find.text('بینش‌ها'), findsOneWidget);
    });

    testWidgets('renders all inactive tabs in simple mode with active tab label hidden', (tester) async {
      await tester.pumpWidget(buildNavBarHarness(mode: AppMode.simple));
      await tester.pumpAndSettle();

      expect(find.text('کارها'), findsNothing); // Active label is hidden
      expect(find.text('خانه'), findsOneWidget);
      expect(find.text('تقویم'), findsOneWidget);
    });
  });
}
