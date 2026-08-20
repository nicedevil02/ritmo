import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/assistant/presentation/widgets/confidence_leaflet.dart';

void main() {
  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      theme: RitmoTheme.darkTheme,
      home: Scaffold(
        body: Center(
          child: child,
        ),
      ),
    );
  }

  group('ConfidenceLeaflet Widget Tests (PSN-47)', () {
    testWidgets('Scenario 1: High confidence renders correct label and expands used fields', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          const ConfidenceLeaflet(
            confidence: 'high',
            usedFields: ['sleep_hours', 'routine_streak'],
            annotations: ['تحلیل با اتکا به داده‌های ۳۰ روز گذشته انجام شد.'],
          ),
        ),
      );

      // Verify compact label
      expect(find.text('اطمینان بالا'), findsOneWidget);

      // Tap to expand
      await tester.tap(find.text('اطمینان بالا'));
      await tester.pumpAndSettle();

      // Verify details are visible and populated
      expect(find.text('داده‌های پشتوانه:'), findsOneWidget);
      expect(find.text('sleep_hours'), findsOneWidget);
      expect(find.text('routine_streak'), findsOneWidget);
      expect(find.text('یادداشت‌های پردازش:'), findsOneWidget);
      expect(find.text('تحلیل با اتکا به داده‌های ۳۰ روز گذشته انجام شد.'), findsOneWidget);
    });

    testWidgets('Scenario 2: None confidence renders fallback message and annotations', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          const ConfidenceLeaflet(
            confidence: 'none',
            usedFields: [],
            annotations: ['دادهٔ این تحلیل ناکافی بود و هیچ رکوردی یافت نشد.'],
          ),
        ),
      );

      // Verify compact label for none
      expect(find.text('داده کافی نیست'), findsOneWidget);

      // Tap to expand
      await tester.tap(find.text('داده کافی نیست'));
      await tester.pumpAndSettle();

      // Verify annotation is shown explaining why confidence is none
      expect(find.text('داده‌های پشتوانه:'), findsNothing);
      expect(find.text('یادداشت‌های پردازش:'), findsOneWidget);
      expect(find.text('دادهٔ این تحلیل ناکافی بود و هیچ رکوردی یافت نشد.'), findsOneWidget);
    });
  });
}
