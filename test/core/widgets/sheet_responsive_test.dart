import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/widgets/ritmo_sheet_scaffold.dart';
import '../../support/responsive_harness.dart';

void main() {
  group('Sheet responsiveness (R-30)', () {
    for (final entry in kRitmoTestViewports.entries) {
      for (final scale in kRitmoTestTextScales) {
        testWidgets('RitmoSheetScaffold fits on ${entry.key} at scale $scale', (tester) async {
          tester.view.physicalSize = entry.value;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);

          await tester.pumpWidget(
            wrapResponsive(
              Builder(
                builder: (context) {
                  return RitmoSheetScaffold(
                    title: 'عنوان شیت آزمایشی با متن نسبتاً طولانی فارسی',
                    subtitle: 'توضیحات تکمیلی زیر عنوان برای شبیه‌سازی وضعیت واقعی',
                    footer: ElevatedButton(
                      onPressed: () {},
                      child: const Text('دکمهٔ ذخیره و ادامه'),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: List.generate(
                        25,
                        (index) => ListTile(
                          title: Text('گزینهٔ شمارهٔ $index برای شبیه‌سازی محتوای بلند'),
                          subtitle: const Text('توضیح کوتاه نمونه جهت بررسی رفتار اسکرول'),
                        ),
                      ),
                    ),
                  );
                },
              ),
              size: entry.value,
              textScale: scale,
            ),
          );

          await expectNoOverflow(tester, label: '${entry.key} @ $scale');

          // Ensure close icon is within screen bounds
          final closeFinder = find.byIcon(Icons.close);
          expect(closeFinder, findsOneWidget);
          final closeRect = tester.getRect(closeFinder);
          expect(closeRect.top, greaterThanOrEqualTo(0));
          expect(closeRect.bottom, lessThanOrEqualTo(entry.value.height));

          // Ensure footer button is within screen bounds
          final footerFinder = find.text('دکمهٔ ذخیره و ادامه');
          expect(footerFinder, findsOneWidget);
          final footerRect = tester.getRect(footerFinder);
          expect(footerRect.top, greaterThanOrEqualTo(0));
          expect(footerRect.bottom, lessThanOrEqualTo(entry.value.height));
        });

        testWidgets('RitmoSheetScaffold fits with keyboard on ${entry.key} at scale $scale', (tester) async {
          tester.view.physicalSize = entry.value;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);

          await tester.pumpWidget(
            wrapResponsive(
              Builder(
                builder: (context) {
                  return RitmoSheetScaffold(
                    title: 'شیت با صفحه‌کلید باز',
                    footer: ElevatedButton(
                      onPressed: () {},
                      child: const Text('تأیید'),
                    ),
                    child: Column(
                      children: [
                        const TextField(
                          decoration: InputDecoration(labelText: 'ورودی متنی'),
                        ),
                        ...List.generate(
                          10,
                          (index) => Text('ردیف متنی نمونه شماره $index'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              size: entry.value,
              textScale: scale,
              keyboardInset: 300,
            ),
          );

          await expectNoOverflow(tester, label: '${entry.key} @ $scale (KB)');

          final closeFinder = find.byIcon(Icons.close);
          expect(closeFinder, findsOneWidget);
          final closeRect = tester.getRect(closeFinder);
          expect(closeRect.top, greaterThanOrEqualTo(0));
          expect(closeRect.bottom, lessThanOrEqualTo(entry.value.height));
        });
      }
    }
  });
}
