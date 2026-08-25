import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/engines.dart';
import 'package:ritmo/features/supplementary_sports/presentation/screens/screens.dart';
import 'package:ritmo/l10n/app_localizations.dart';

Widget createTestApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('fa'),
    home: Scaffold(body: child),
  );
}

void main() {
  group('S8-T8 Progress Tab Insights Tests', () {
    testWidgets('Empty insights renders nothing for insights section (no generic fallback)', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          const MvProgressTab(
            insights: [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('mv_insights_section')), findsNothing);
      expect(find.text('بینش‌های پیشرفت'), findsNothing);
    });

    testWidgets('Populated insights renders deterministic insight cards with permitted keys', (tester) async {
      const sampleInsights = [
        MvInsight(
          key: 'mv_insight_best_day',
          titleFa: 'روز طلایی تمرین',
          descriptionFa: 'به نظر می‌رسد روزهای دوشنبه با بیشترین نرخ تکمیل، مناسب‌ترین زمان برای تمرین شماست.',
          params: {'bestDay': 3, 'dayName': 'دوشنبه', 'count': 6},
        ),
        MvInsight(
          key: 'mv_insight_anchor_adherence',
          titleFa: 'پایبندی به لنگرها',
          descriptionFa: 'در ۴ هفتهٔ گذشته، نرخ حضور شما در جلسات ثابت لنگر ۸۵٪ ثبت شده است.',
          params: {'adherenceRate': 85, 'weeks': 4},
        ),
      ];

      await tester.pumpWidget(
        createTestApp(
          const MvProgressTab(
            insights: sampleInsights,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('mv_insights_section')), findsOneWidget);
      expect(find.text('بینش‌های پیشرفت'), findsOneWidget);
      expect(find.byKey(const ValueKey('mv_insight_best_day')), findsOneWidget);
      expect(find.byKey(const ValueKey('mv_insight_anchor_adherence')), findsOneWidget);
      expect(find.text('روز طلایی تمرین'), findsOneWidget);
      expect(find.text('پایبندی به لنگرها'), findsOneWidget);
    });
  });
}
