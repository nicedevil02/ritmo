import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/app_mode/app_mode_service.dart';
import 'package:ritmo/core/navigation/shell_metrics.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/today/presentation/widgets/ritmo_nav_bar.dart';

void main() {
  Widget buildNavBarHarness({
    bool reduceTransparency = false,
    bool highContrast = false,
  }) {
    final theme = RitmoTheme.build(
      palette: RitmoPalette.jadeNoir,
      brightness: Brightness.dark,
      reduceTransparency: reduceTransparency,
    );

    return MaterialApp(
      theme: theme,
      home: Builder(
        builder: (context) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              highContrast: highContrast,
            ),
            child: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: RitmoNavBar(
                  mode: AppMode.full,
                  currentIndex: RitmoShellMetrics.defaultTabFor(AppMode.full),
                  onSelectTab: (_) {},
                  onCenterTap: () {},
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  group('RitmoNavBar Glassmorphism Tests', () {
    testWidgets('renders BackdropFilter and ClipPath when glass is enabled', (tester) async {
      await tester.pumpWidget(buildNavBarHarness(reduceTransparency: false));
      await tester.pumpAndSettle();

      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(find.byType(ClipPath), findsOneWidget);

      final backdrop = tester.widget<BackdropFilter>(find.byType(BackdropFilter));
      expect(backdrop.filter, isA<ImageFilter>());
    });

    testWidgets('omits BackdropFilter when reduceTransparency is enabled in theme behavior', (tester) async {
      await tester.pumpWidget(buildNavBarHarness(reduceTransparency: true));
      await tester.pumpAndSettle();

      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('omits BackdropFilter when highContrast is active', (tester) async {
      await tester.pumpWidget(buildNavBarHarness(highContrast: true));
      await tester.pumpAndSettle();

      expect(find.byType(BackdropFilter), findsNothing);
    });
  });
}
