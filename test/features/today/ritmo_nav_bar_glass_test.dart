import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/app_mode/app_mode_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/today/presentation/widgets/ritmo_nav_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildTestApp({
  required Widget child,
  bool isDark = false,
  bool isGlass = true,
  double blurSigma = 20.0,
}) {
  final themeData = RitmoTheme.build(
    palette: RitmoPalette.jadeNoir,
    brightness: isDark ? Brightness.dark : Brightness.light,
    reduceTransparency: !isGlass,
    glassBlurSigma: blurSigma,
  );

  return MaterialApp(
    theme: themeData,
    home: Scaffold(
      body: Stack(
        children: [
          const Center(child: Text('Content Under Glass')),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: child,
          ),
        ],
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('RitmoNavBar Dynamic Glassmorphism Tests', () {
    testWidgets('Full Mode renders with BackdropFilter when glass is enabled', (tester) async {
      int selectedTab = 2; // Home

      await tester.pumpWidget(
        _buildTestApp(
          isGlass: true,
          blurSigma: 25.0,
          child: RitmoNavBar(
            mode: AppMode.full,
            currentIndex: selectedTab,
            onSelectTab: (idx) => selectedTab = idx,
            onCenterTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RitmoNavBar), findsOneWidget);
      expect(find.text('تقویم'), findsOneWidget);
      expect(find.text('دستیار'), findsOneWidget);
      expect(find.text('سیستم‌ها'), findsOneWidget);
      expect(find.text('پروفایل'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsWidgets);
    });

    testWidgets('Simple Mode renders with BackdropFilter when glass is enabled', (tester) async {
      int selectedTab = 1; // Home

      await tester.pumpWidget(
        _buildTestApp(
          isGlass: true,
          blurSigma: 20.0,
          child: RitmoNavBar(
            mode: AppMode.simple,
            currentIndex: selectedTab,
            onSelectTab: (idx) => selectedTab = idx,
            onCenterTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RitmoNavBar), findsOneWidget);
      expect(find.text('کارها'), findsOneWidget);
      expect(find.text('تقویم'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsWidgets);
    });

    testWidgets('Renders fallback without BackdropFilter when glass is disabled', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          isGlass: false,
          child: RitmoNavBar(
            mode: AppMode.full,
            currentIndex: 2,
            onSelectTab: (_) {},
            onCenterTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RitmoNavBar), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('Tapping non-active item triggers onSelectTab', (tester) async {
      int selectedTab = 2; // Home

      await tester.pumpWidget(
        _buildTestApp(
          isGlass: true,
          child: RitmoNavBar(
            mode: AppMode.full,
            currentIndex: selectedTab,
            onSelectTab: (idx) => selectedTab = idx,
            onCenterTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on Calendar (tab index 4)
      await tester.tap(find.text('تقویم'));
      await tester.pumpAndSettle();

      expect(selectedTab, equals(4));
    });
  });
}
