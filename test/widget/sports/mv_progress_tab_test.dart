import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/engines.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/features/supplementary_sports/presentation/screens/mv_progress_tab.dart';

void main() {
  group('S5-T4 MvProgressTab Dual Currency & Phrasing Tests', () {
    testWidgets('Fresh User (0 sessions, empty repos) renders MvInsufficientData on all cards without crash or fake numbers', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MvProgressTab(
              continuousActiveWeeks: null,
              totalSessionsCount: 0,
              totalMetMinutes: 0.0,
              weeklyBudget: null,
              loadSnapshot: null,
              monthlyKindMinutes: null,
              personalRecords: [],
              activeCampaign: null,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Expect insufficient data widgets for health, load, distribution, PRs
      expect(find.text('سلامت این هفته'), findsOneWidget);
      expect(find.text('بار تمرینی و تعادل فشار'), findsOneWidget);
      expect(find.text('توزیع ورزش‌ها در این ماه'), findsOneWidget);
      expect(find.text('رکوردهای شخصی'), findsOneWidget);

      // Verify specific guidance descriptions
      expect(find.textContaining('چند جلسهٔ دیگر لازم است'), findsOneWidget);
      expect(find.textContaining('هنوز در این هفته فعالیتی ثبت نشده است'), findsOneWidget);
    });

    testWidgets('Experienced User (6+ weeks data) renders all 5 cards populated with honest probability phrasing', (tester) async {
      const kindsMap = <String, MvMovementKind>{
        'HIKING': MvMovementKind(
          code: 'HIKING',
          titleFa: 'کوهنوردی',
          emoji: '🥾',
          family: MovementFamily.outdoor,
          baseMet: 7.5,
          metLow: 5.0,
          metHigh: 9.0,
          primaryMetric: MovementMetric.elevation,
          isOutdoor: true,
          isSocial: false,
          needsVenue: false,
          jointImpact: 2,
          isCustom: false,
          isEnabled: true,
          usageCount: 0,
          sortOrder: 0,
        ),
        'FUTSAL': MvMovementKind(
          code: 'FUTSAL',
          titleFa: 'فوتسال',
          emoji: '⚽',
          family: MovementFamily.sport,
          baseMet: 8.0,
          metLow: 6.0,
          metHigh: 10.0,
          primaryMetric: MovementMetric.duration,
          isOutdoor: false,
          isSocial: true,
          needsVenue: true,
          jointImpact: 3,
          isCustom: false,
          isEnabled: true,
          usageCount: 0,
          sortOrder: 0,
        ),
      };

      const budget = MvWeeklyBudgetProgress(
        moderateEquivalentMinutes: 240,
        rawMetMinutes: 1800.0,
        strengthDays: 2,
        targetMin: 150,
        targetOptimal: 300,
        strengthDaysTarget: 2,
      );

      const load = MvLoadSnapshot(
        acuteLoad: 1200,
        chronicWeeklyLoad: 1000.0,
        ratio: 1.20,
        bandKey: 'mv_load_band_optimal',
        bandTitleFa: 'مطلوب و سازنده',
      );

      const campaign = MvCampaign(
        id: 'camp_damavand_1',
        titleFa: 'صعود به قله دماوند',
        goalCode: 'OUTDOOR',
        startDate: '2026-08-01',
        weeks: 12,
        status: 'ACTIVE',
        createdAt: 1700000000,
        updatedAt: 1700000000,
      );

      const prs = [
        MvPersonalRecord(
          id: 'pr_hike_elev',
          kind: 'HIKING',
          prType: MvPrType.maxElevation,
          value: 950.0,
          achievedAt: 1700000000,
        ),
        MvPersonalRecord(
          id: 'pr_futsal_dur',
          kind: 'FUTSAL',
          prType: MvPrType.longestDuration,
          value: 90.0,
          achievedAt: 1700000000,
        ),
      ];

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MvProgressTab(
              continuousActiveWeeks: 6,
              totalSessionsCount: 24,
              totalMetMinutes: 7200.0,
              weeklyBudget: budget,
              loadSnapshot: load,
              monthlyKindMinutes: {'HIKING': 480, 'FUTSAL': 240},
              kindsMap: kindsMap,
              personalRecords: prs,
              activeCampaign: campaign,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Health Card
      expect(find.text('سلامت این هفته (توصیه بهداشت جهانی)'), findsOneWidget);
      expect(find.text('فعالیت معادل متوسط'), findsOneWidget);
      expect(find.text('روزهای قدرتی و مقاومتی'), findsOneWidget);

      // 2. Training Load Card
      expect(find.text('بار تمرینی (۷ روز به ۲۸ روز)'), findsOneWidget);
      expect(find.text('مطلوب و سازنده'), findsOneWidget);
      expect(find.textContaining('به نظر می‌رسد در ۴ هفتهٔ گذشته'), findsOneWidget);

      // 3. Kind Distribution Card
      expect(find.text('توزیع ورزش‌ها در ماه جاری'), findsOneWidget);
      expect(find.textContaining('بیشترین تمرکز فعالیت شما بر کوهنوردی'), findsOneWidget);

      // 4. PRs Card
      expect(find.text('رکوردهای شخصی به تفکیک ورزش'), findsOneWidget);
      expect(find.text('🥾 کوهنوردی'), findsWidgets);
      expect(find.text('⚽ فوتسال'), findsWidgets);

      // 5. Active Campaign Card
      expect(find.text('دورهٔ هدف‌دار فعال'), findsOneWidget);
      expect(find.text('صعود به قله دماوند'), findsOneWidget);

      // 6. Streak Hero
      expect(find.text('هفته‌های فعال پیوسته'), findsOneWidget);
    });
  });
}
