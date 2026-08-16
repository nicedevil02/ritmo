import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/presentation/common/metric_stat.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: RitmoTheme.build(
      palette: RitmoPalette.jadeNoir,
      brightness: Brightness.dark,
    ),
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MetricStat Widget Tests', () {
    testWidgets('Renders label, value with unit and Persian digits', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const MetricStat(
            label: 'مدت فعال',
            value: '45',
            unit: 'دقیقه',
          ),
        ),
      );

      expect(find.text('مدت فعال'), findsOneWidget);
      expect(find.text('۴۵ دقیقه'), findsOneWidget);
    });

    testWidgets('No data renders dash (—) and semantics label "ثبت‌نشده" (zero fake zero)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const MetricStat(
            label: 'ضربان قلب',
            value: null,
          ),
        ),
      );

      expect(find.text('ضربان قلب'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
      final semantics = tester.getSemantics(find.byType(MetricStat));
      expect(semantics.label, contains(MovementStrings.commonNotRecorded));
    });

    testWidgets('Estimated value appends "(تخمینی)"', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const MetricStat(
            label: 'کالری',
            value: '250',
            unit: 'کیلوکالری',
            isEstimated: true,
          ),
        ),
      );

      expect(find.textContaining('۲۵۰ کیلوکالری (تخمینی)'), findsOneWidget);
    });
  });
}
