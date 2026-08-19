import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/utils/ritmo_date_picker.dart';
import '../../support/responsive_harness.dart';

void main() {
  group('R-31 / R-44: RitmoDatePicker Month & Day Resilience', () {
    testWidgets('RitmoDatePicker displays without overflow on 320x568 at 1.6x scale', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        wrapResponsive(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                RitmoDatePicker.show(
                  context: context,
                  initialDate: DateTime(2026, 8, 19),
                  firstDate: DateTime(2020, 1, 1),
                  lastDate: DateTime(2030, 12, 29),
                );
              },
              child: const Text('Open Date Picker'),
            ),
          ),
          size: const Size(320, 568),
          textScale: 1.6,
        ),
      );

      await tester.tap(find.text('Open Date Picker'));
      await tester.pumpAndSettle();

      await expectNoOverflow(tester, label: 'DatePicker @ 320x568 1.6x');

      // Now switch to Month picker
      final monthYearFinder = find.byKey(const ValueKey('month_year_header_btn'));
      if (monthYearFinder.evaluate().isNotEmpty) {
        await tester.tap(monthYearFinder);
        await tester.pumpAndSettle();
        await expectNoOverflow(tester, label: 'DatePicker Months @ 320x568 1.6x');
      }
    });
  });
}
