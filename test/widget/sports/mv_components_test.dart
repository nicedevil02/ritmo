import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/insight_engine.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/features/supplementary_sports/presentation/components/components.dart';

Widget createTestApp(Widget child) {
  return MaterialApp(
    theme: ThemeData.light(),
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  group('Phase P4 Design System Components Tests', () {
    testWidgets('MvPrimaryAction renders and triggers onPressed', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        createTestApp(
          MvPrimaryAction(
            label: 'شروع جلسه',
            onPressed: () => tapped = true,
          ),
        ),
      );

      expect(find.text('شروع جلسه'), findsOneWidget);
      await tester.tap(find.byType(MvPrimaryAction));
      expect(tapped, isTrue);
    });

    testWidgets('MvChip renders label and selection styling', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          const MvChip(
            label: 'سینه و بازو',
            isSelected: true,
          ),
        ),
      );

      expect(find.text('سینه و بازو'), findsOneWidget);
    });

    testWidgets('MvReadinessBar displays tier and explanation', (tester) async {
      const decision = MvDecision<MvReadinessTier>(
        value: MvReadinessTier.full,
        reasonFa: 'آمادگی بدنی عالی',
      );

      await tester.pumpWidget(
        createTestApp(
          const MvReadinessBar(decision: decision),
        ),
      );

      expect(find.text('آمادگی کامل'), findsOneWidget);
      expect(find.text('آمادگی بدنی عالی'), findsOneWidget);
    });

    testWidgets('MvHeroCard renders title, subtitle and exactly primary and secondary actions', (tester) async {
      const slot = MvSlot(
        id: '1',
        dateIso: '2026-08-25',
        headlineFa: 'قدرت بالاتنه',
        targetMinutes: 30,
        createdAt: 100,
        updatedAt: 100,
      );

      await tester.pumpWidget(
        createTestApp(
          MvHeroCard(
            slot: slot,
            onStart: () {},
            onCantToday: () {},
          ),
        ),
      );

      expect(find.text('قدرت بالاتنه'), findsOneWidget);
      expect(find.text('شروع جلسه'), findsOneWidget);
      expect(find.text('نمی‌تونم'), findsOneWidget);
    });

    testWidgets('MvDaySlotCard displays day and headline', (tester) async {
      const slot = MvSlot(
        id: '1',
        dateIso: '2026-08-25',
        headlineFa: 'قدرت پایین‌تنه',
        targetMinutes: 45,
        createdAt: 100,
        updatedAt: 100,
      );

      await tester.pumpWidget(
        createTestApp(
          const MvDaySlotCard(slot: slot),
        ),
      );

      expect(find.text('قدرت پایین‌تنه'), findsOneWidget);
      expect(find.text('45 دقیقه · متوسط'), findsOneWidget);
    });

    testWidgets('MvQuickLogRow renders quick activity items', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          MvQuickLogRow(
            onQuickWalk: () {},
            onQuickStretch: () {},
            onCustomLog: () {},
          ),
        ),
      );

      expect(find.text('پیاده‌روی ۲۰ دقیقه'), findsOneWidget);
      expect(find.text('۱۰ دقیقه نرمش سبک'), findsOneWidget);
    });

    testWidgets('MvBodyMap renders muscle groups and suggestion action', (tester) async {
      const distribution = MvBodyMapDistribution(
        muscleSessionCounts: {'CHEST': 2, 'BACK': 0},
        neglectedMuscleGroupCode: 'BACK',
        suggestedActionFa: 'پشت کار نکرده — ۱۵ دقیقه بسازم؟',
      );

      await tester.pumpWidget(
        createTestApp(
          const MvBodyMap(distribution: distribution),
        ),
      );

      expect(find.text('نقشهٔ عضلانی این هفته'), findsOneWidget);
      expect(find.text('پشت کار نکرده — ۱۵ دقیقه بسازم؟'), findsOneWidget);
    });

    testWidgets('MvMetricRing and MvStatTile render statistics correctly', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          const Column(
            children: [
              MvMetricRing(
                currentMet: 300,
                targetMet: 500,
                activeDays: 2,
                targetDays: 4,
              ),
              MvStatTile(
                title: 'هفته‌های فعال',
                value: '۵',
                unit: 'هفته',
              ),
            ],
          ),
        ),
      );

      expect(find.text('دقیقهٔ فعال این هفته'), findsOneWidget);
      expect(find.text('300 / 500'), findsOneWidget);
      expect(find.text('هفته‌های فعال'), findsOneWidget);
      expect(find.text('۵'), findsOneWidget);
    });

    testWidgets('MvEmptyState and MvInsufficientData render properly', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          const Column(
            children: [
              MvEmptyState(
                icon: Icons.fitness_center,
                title: 'بدون برنامه',
                description: 'برنامه‌ای تنظیم نشده است.',
              ),
              MvInsufficientData(
                requirementDescription: 'برای نمایش نمودار حداقل ۷ روز ثبت نیاز است.',
              ),
            ],
          ),
        ),
      );

      expect(find.text('بدون برنامه'), findsOneWidget);
      expect(find.text('هنوز دادهٔ کافی نیست'), findsOneWidget);
      expect(find.text('برای نمایش نمودار حداقل ۷ روز ثبت نیاز است.'), findsOneWidget);
    });

    testWidgets('MvSheetScaffold renders header, body and bottom action', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          const MvSheetScaffold(
            title: 'شیت آزمایشی',
            subtitle: 'توضیحات کوتاه',
            body: Text('محتوای شیت'),
            bottomAction: Text('دکمه پایین'),
          ),
        ),
      );

      expect(find.text('شیت آزمایشی'), findsOneWidget);
      expect(find.text('توضیحات کوتاه'), findsOneWidget);
      expect(find.text('محتوای شیت'), findsOneWidget);
      expect(find.text('دکمه پایین'), findsOneWidget);
    });

    testWidgets('MvAudioToggle toggles on tap', (tester) async {
      bool isEnabled = false;
      await tester.pumpWidget(
        createTestApp(
          MvAudioToggle(
            isAudioEnabled: isEnabled,
            onToggle: (v) => isEnabled = v,
          ),
        ),
      );

      await tester.tap(find.byType(MvAudioToggle));
      expect(isEnabled, isTrue);
    });
  });
}
