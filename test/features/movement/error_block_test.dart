import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/presentation/common/error_block.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: RitmoTheme.build(
      palette: RitmoPalette.jadeNoir,
      brightness: Brightness.dark,
    ),
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ErrorBlock Widget Tests (Point 4: Banner Mode vs Full Page)', () {
    testWidgets('Banner Mode: renders non-blocking compact banner at top of cached content', (tester) async {
      bool retryTapped = false;

      await tester.pumpWidget(
        _wrap(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Error banner at top of cached content
              ErrorBlock(
                title: 'خطا در به‌روزرسانی زنده',
                message: 'داده‌های زیر از آخرین وضعیت آفلاین نمایش داده می‌شوند',
                isBannerMode: true,
                onRetry: () {
                  retryTapped = true;
                },
              ),
              // 2. Existing cached data below
              Container(
                key: const ValueKey('cached_data_card'),
                padding: const EdgeInsets.all(16.0),
                child: const Text('داده‌های کش‌شدهٔ تمرین امروز'),
              ),
            ],
          ),
        ),
      );

      // Both banner and cached data must be visible simultaneously
      expect(find.text('خطا در به‌روزرسانی زنده'), findsOneWidget);
      expect(find.text('داده‌های زیر از آخرین وضعیت آفلاین نمایش داده می‌شوند'), findsOneWidget);
      expect(find.byKey(const ValueKey('cached_data_card')), findsOneWidget);
      expect(find.text('داده‌های کش‌شدهٔ تمرین امروز'), findsOneWidget);

      // Tap retry on banner
      await tester.tap(find.text(MovementStrings.commonRetry));
      await tester.pumpAndSettle();
      expect(retryTapped, isTrue);

      // Banner mode has compact height (<= 90px)
      final bannerSize = tester.getSize(find.byType(ErrorBlock));
      expect(bannerSize.height, lessThanOrEqualTo(90.0));
    });

    testWidgets('Full Page Mode: renders full centered block when no cached data exists', (tester) async {
      bool retryTapped = false;

      await tester.pumpWidget(
        _wrap(
          ErrorBlock(
            title: 'خطا در دریافت برنامه',
            message: 'ارتباط با سرور برقرار نشد، لطفاً دوباره تلاش کنید',
            isBannerMode: false,
            onRetry: () {
              retryTapped = true;
            },
          ),
        ),
      );

      expect(find.text('خطا در دریافت برنامه'), findsOneWidget);
      expect(find.text('ارتباط با سرور برقرار نشد، لطفاً دوباره تلاش کنید'), findsOneWidget);
      expect(find.text(MovementStrings.commonRetry), findsOneWidget);

      await tester.tap(find.text(MovementStrings.commonRetry));
      await tester.pumpAndSettle();
      expect(retryTapped, isTrue);
    });
  });
}
