import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/engines.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/features/supplementary_sports/presentation/screens/screens.dart';
import 'package:ritmo/features/supplementary_sports/presentation/sheets/sheets.dart';

import 'package:ritmo/l10n/app_localizations.dart';

Widget createTestApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('fa'),
    theme: ThemeData.light(),
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  group('Phase P5 Screens & Sheets Tests', () {
    const testSlot = MvSlot(
      id: 'slot_1',
      dateIso: '2026-08-25',
      slotType: MvSlotType.strength,
      headlineFa: 'قدرت بالاتنه',
      targetMinutes: 30,
      createdAt: 100,
      updatedAt: 100,
    );

    final weekSlots = List.generate(7, (i) {
      return MvSlot(
        id: 'slot_$i',
        dateIso: '2026-08-${22 + i}',
        slotType: i % 2 == 0 ? MvSlotType.strength : MvSlotType.rest,
        headlineFa: i % 2 == 0 ? 'تمرین روز $i' : 'استراحت',
        targetMinutes: i % 2 == 0 ? 30 : 0,
        createdAt: 100,
        updatedAt: 100,
      );
    });

    testWidgets('MvTodayTab renders core sections', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          MvTodayTab(
            weekSlots: weekSlots,
            todaySlot: testSlot,
            readinessDecision: const MvDecision<MvReadinessTier>(
              value: MvReadinessTier.full,
              reasonFa: 'آمادگی کامل بدنی',
            ),
            budgetProgress: const MvWeeklyBudgetProgress(
              moderateEquivalentMinutes: 120,
              rawMetMinutes: 200,
              strengthDays: 1,
              targetMin: 150,
              strengthDaysTarget: 2,
            ),
            bodyMapDistribution: const MvBodyMapDistribution(
              muscleSessionCounts: {},
            ),
            onStartSession: () {},
            onSlotUpdated: (_) {},
            onCheckinSaved: (_) {},
            onQuickLogSaved: (kind, dur, feel, note) async {},
            onDateSelected: (_) {},
          ),
        ),
      );

      expect(find.text('قدرت بالاتنه'), findsOneWidget);
      expect(find.text('شروع جلسه'), findsOneWidget);
      expect(find.text('نمی‌تونم'), findsOneWidget);
      expect(find.text('ثبت سریع فعالیت'), findsOneWidget);
      expect(find.text('نقشهٔ عضلانی این هفته'), findsOneWidget);
      expect(find.text('دقیقهٔ فعال این هفته'), findsOneWidget);
    });

    testWidgets('MvWeekTab renders 7 day cards and cycle header', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          MvWeekTab(
            weekSlots: weekSlots,
            cycleWeek: 2,
            isDeloadWeek: true,
            onSlotUpdated: (_) {},
            onRegenerateWeek: () {},
          ),
        ),
      );

      expect(find.text('برنامهٔ هفتگی (هفتهٔ 2)'), findsOneWidget);
      expect(find.text('هفته سبک'), findsOneWidget);
      expect(find.text('تمرین روز 0'), findsOneWidget);
      expect(find.text('استراحت'), findsWidgets);
    });

    testWidgets('MvProgressTab renders active streak, stats and PRs', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          const MvProgressTab(
            continuousActiveWeeks: 4,
            totalSessionsCount: 12,
            totalMetMinutes: 1800,
            personalRecords: [
              MvPersonalRecord(
                id: '1',
                kind: 'شنا سوئدی',
                prType: MvPrType.maxReps,
                value: 25,
                achievedAt: 100,
              ),
            ],
            bodyMapDistribution: MvBodyMapDistribution(muscleSessionCounts: {}),
          ),
        ),
      );

      expect(find.text('هفته‌های فعال پیوسته'), findsOneWidget);
      expect(find.text('۴ هفته'), findsOneWidget);
      expect(find.text('شنا سوئدی'), findsOneWidget);
    });

    testWidgets('MvLibraryScreen filters by search and apartment mode', (
      tester,
    ) async {
      final testPool = [
        const MvExercise(
          id: '1',
          name: 'شنا سوئدی',
          category: 'CHEST',
          noisy: false,
          impact: 0,
        ),
        const MvExercise(
          id: '2',
          name: 'برپی پرشی',
          category: 'CARDIO',
          noisy: true,
          impact: 3,
        ),
      ];

      await tester.pumpWidget(
        createTestApp(MvLibraryScreen(allExercises: testPool)),
      );

      expect(find.text('شنا سوئدی'), findsOneWidget);
      expect(find.text('برپی پرشی'), findsOneWidget);

      // Tap Apartment friendly filter
      await tester.tap(find.text('بی‌صدا (آپارتمانی)'));
      await tester.pumpAndSettle();

      expect(find.text('شنا سوئدی'), findsOneWidget);
      expect(find.text('برپی پرشی'), findsNothing);
    });

    testWidgets('MvSettingsScreen displays toggles and triggers save', (
      tester,
    ) async {
      MvUserProfile? savedProfile;
      const profile = MvUserProfile(
        daysPerWeek: 3,
        createdAt: 100,
        updatedAt: 100,
      );

      await tester.pumpWidget(
        createTestApp(
          MvSettingsScreen(
            initialProfile: profile,
            onProfileSaved: (p) => savedProfile = p,
          ),
        ),
      );

      expect(find.text('تنظیمات ورزشی'), findsOneWidget);
      expect(find.text('حالت همسایه‌پسند (آپارتمانی)'), findsOneWidget);

      await tester.tap(find.text('ذخیره'));
      expect(savedProfile, isNotNull);
    });

    testWidgets('MvOnboardingScreen 3-question completion calls onComplete', (
      tester,
    ) async {
      MvUserProfile? createdProfile;

      await tester.pumpWidget(
        createTestApp(
          MvOnboardingScreen(onComplete: (p) async => createdProfile = p),
        ),
      );

      expect(find.text('برنامهٔ ورزشی اختصاصی تو'), findsOneWidget);
      await tester.tap(find.text('شروع برنامه و ورود به ریتمو'));
      expect(createdProfile, isNotNull);
      expect(createdProfile!.onboardingCompleted, isTrue);
    });

    testWidgets('MvCantTodaySheet renders all escape options', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          MvCantTodaySheet(
            slot: testSlot,
            onMinimalDose: () {},
            onMoveToTomorrow: () {},
            onChangeToStretch: () {},
            onSkipEntirely: () {},
          ),
        ),
      );

      expect(find.text('برنامه برای شرایط امروزت'), findsOneWidget);
      expect(find.text('حداقل مؤثر (۱۰ دقیقه سبک)'), findsOneWidget);
      expect(find.text('تبدیل به ۵ دقیقه کشش و آرامش'), findsOneWidget);
      expect(find.text('انتقال جلسه به فردا'), findsOneWidget);
      expect(find.text('استراحت کامل برای امروز'), findsOneWidget);
    });

    testWidgets('MvQuickLogSheet saves with selected duration', (tester) async {
      int? savedDuration;

      await tester.pumpWidget(
        createTestApp(
          MvQuickLogSheet(onSave: (k, d, f, n) async => savedDuration = d),
        ),
      );

      expect(find.text('ثبت سریع فعالیت'), findsOneWidget);
      await tester.tap(find.text('ثبت فعالیت (20 دقیقه)'));
      expect(savedDuration, equals(20));
    });
  });
}
