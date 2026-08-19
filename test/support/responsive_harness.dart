import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

/// مجموعهٔ رسمی دستگاه‌های مرجع برای تست چیدمان (R-07).
/// هر عدد از یک دستگاه واقعی می‌آید، نه از حدس.
const kRitmoTestViewports = <String, Size>{
  'compact-short': Size(320, 568), // بدترین حالت واقعی
  'compact': Size(360, 640), // اندروید اقتصادی رایج
  'regular': Size(390, 844), // حالت مرجع طراحی
  'large': Size(430, 932), // پلاس
};

const kRitmoTestTextScales = <double>[1.0, 1.3, 1.6];

/// ویجت را در محیط واقعی برنامه می‌پیچد: RTL، تم ریتمو، مقیاس متن، نوارهای سیستمی.
Widget wrapResponsive(
  Widget child, {
  required Size size,
  double textScale = 1.0,
  EdgeInsets padding = const EdgeInsets.only(top: 24, bottom: 16),
  double keyboardInset = 0,
  Brightness brightness = Brightness.light,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: RitmoTheme.lightTheme,
    darkTheme: RitmoTheme.darkTheme,
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    home: MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
        padding: padding,
        viewInsets: EdgeInsets.only(bottom: keyboardInset),
        platformBrightness: brightness,
      ),
      child: Directionality(textDirection: TextDirection.rtl, child: child),
    ),
  );
}

/// هر سرریز RenderFlex را جمع می‌کند و در صورت وجود، تست را با پیام خوانا می‌شکند.
/// این تابع هرگز خطا را خفه نمی‌کند.
Future<void> expectNoOverflow(
  WidgetTester tester, {
  required String label,
}) async {
  final errors = <FlutterErrorDetails>[];
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.toString().contains('overflowed') ||
        details.summary.toString().contains('overflowed') ||
        details.exceptionAsString().contains('overflowed')) {
      errors.add(details);
    } else {
      previousOnError?.call(details);
    }
  };

  try {
    await tester.pumpAndSettle();
  } finally {
    FlutterError.onError = previousOnError;
  }

  if (errors.isNotEmpty) {
    fail(
      '[$label] Detected ${errors.length} overflow errors:\n${errors.map((e) => e.toString()).join('\n---\n')}',
    );
  }
}

/// حلقهٔ استاندارد: ۴ دستگاه × ۳ مقیاس = ۱۲ حالت برای هر ویجت.
void testAcrossViewports(
  String description,
  Widget Function() build, {
  bool withKeyboard = false,
}) {
  for (final viewportEntry in kRitmoTestViewports.entries) {
    for (final textScale in kRitmoTestTextScales) {
      final testLabel =
          '$description [${viewportEntry.key} (${viewportEntry.value.width.toInt()}x${viewportEntry.value.height.toInt()}) @ ${textScale}x${withKeyboard ? " +KB" : ""}]';
      testWidgets(testLabel, (tester) async {
        tester.view.physicalSize = viewportEntry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          wrapResponsive(
            build(),
            size: viewportEntry.value,
            textScale: textScale,
            keyboardInset: withKeyboard ? 300.0 : 0.0,
          ),
        );

        await expectNoOverflow(tester, label: testLabel);
      });
    }
  }
}
