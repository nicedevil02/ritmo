import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/app_mode/app_mode_service.dart';
import 'package:ritmo/core/navigation/shell_metrics.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/today/presentation/widgets/ritmo_nav_bar.dart';

void main() {
  Widget harness(
    AppMode mode, {
    int? currentIndex,
    ValueChanged<int>? onSelectTab,
    VoidCallback? onCenterTap,
    double width = 380,
    double textScale = 1.0,
    RitmoDensityLevel density = RitmoDensityLevel.comfortable,
  }) {
    return MaterialApp(
      theme: RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
        density: density,
      ),
      home: Builder(
        builder: (context) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: width,
                  child: RitmoNavBar(
                    mode: mode,
                    currentIndex: currentIndex ?? RitmoShellMetrics.defaultTabFor(mode),
                    onSelectTab: onSelectTab ?? (_) {},
                    onCenterTap: onCenterTap ?? () {},
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  group('NAV0-5 — قرارداد ارتفاع نوار ناوبری', () {
    for (final level in RitmoDensityLevel.values) {
      testWidgets('در حالت ساده ارتفاع در چگالی ${level.name} مطابق توکن است', (tester) async {
        await tester.pumpWidget(harness(AppMode.simple, density: level));
        await tester.pumpAndSettle();

        expect(
          tester.getSize(find.byType(RitmoNavBar)).height,
          equals(RitmoMetrics.of(level).navBarHeight),
        );
      });

      testWidgets('در حالت کامل ارتفاع در چگالی ${level.name} مطابق توکن است', (tester) async {
        await tester.pumpWidget(harness(AppMode.full, density: level));
        await tester.pumpAndSettle();

        expect(
          tester.getSize(find.byType(RitmoNavBar)).height,
          equals(RitmoMetrics.of(level).navBarHeight),
        );
      });
    }

    testWidgets('در عرض ۳۲۰ و متن بزرگ، نه سرریز نه تغییر ارتفاع', (tester) async {
      await tester.pumpWidget(
        harness(AppMode.full, currentIndex: 0, width: 320, textScale: 1.3),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(RitmoNavBar)).height,
        equals(RitmoMetrics.of(RitmoDensityLevel.comfortable).navBarHeight),
      );
    });
  });

  group('NAV2 — برچسب مقاصد در نوار نئومورفیک', () {
    testWidgets('در حالت کامل برچسب مقصد فعال پنهان و بقیه آشکارند', (tester) async {
      await tester.pumpWidget(harness(AppMode.full, currentIndex: 3));
      await tester.pumpAndSettle();

      expect(find.text('دستیار'), findsNothing); // Active label is hidden
      expect(find.text('تقویم'), findsOneWidget); // Inactive labels are shown
      expect(find.text('سیستم‌ها'), findsOneWidget);
      expect(find.text('بینش‌ها'), findsOneWidget);
    });

    testWidgets('وقتی خانه فعال است، برچسب خانه پنهان و بقیه نشان داده می‌شوند', (tester) async {
      await tester.pumpWidget(
        harness(
          AppMode.full,
          currentIndex: RitmoShellMetrics.homeTabIndexFor(AppMode.full),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('خانه'), findsNothing); // Home active label is hidden
      expect(find.text('تقویم'), findsOneWidget); // Other labels are shown
      expect(find.text('دستیار'), findsOneWidget);
      expect(find.text('سیستم‌ها'), findsOneWidget);
      expect(find.text('بینش‌ها'), findsOneWidget);
    });
  });

  group('NAV1 — تعامل', () {
    testWidgets('لمس یک مقصد، اندیس درست را برمی‌گرداند', (tester) async {
      int? selectedIndex;
      await tester.pumpWidget(
        harness(
          AppMode.full,
          currentIndex: 2,
          onSelectTab: (index) => selectedIndex = index,
        ),
      );
      await tester.pumpAndSettle();

      final assistant = find.byIcon(CupertinoIcons.sparkles);
      expect(assistant, findsOneWidget);
      await tester.tap(assistant);
      await tester.pumpAndSettle();

      expect(selectedIndex, equals(3));
    });

    testWidgets('لمس دکمهٔ مرکزی، کال‌بک مرکزی را صدا می‌زند', (tester) async {
      var centerTaps = 0;
      await tester.pumpWidget(
        harness(
          AppMode.full,
          currentIndex: 4,
          onCenterTap: () => centerTaps++,
        ),
      );
      await tester.pumpAndSettle();

      final home = find.byIcon(CupertinoIcons.house_fill);
      expect(home, findsOneWidget);
      await tester.tap(home);
      await tester.pumpAndSettle();

      expect(centerTaps, equals(1));
    });
  });
}
