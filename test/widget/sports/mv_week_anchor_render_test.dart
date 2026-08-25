import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/engines.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/features/supplementary_sports/presentation/components/components.dart';
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
  group('S8-T5 Week & Today Tab Anchor Rendering Tests', () {
    const lockedSlot = MvSlot(
      id: 'slot_thu',
      dateIso: '2026-08-27',
      slotType: MvSlotType.sport,
      kindCode: 'FUTSAL',
      headlineFa: 'فوتسال هفتگی',
      targetMinutes: 90,
      plannedTime: '21:00',
      isLocked: true,
      createdAt: 100,
      updatedAt: 100,
    );

    const normalSlot = MvSlot(
      id: 'slot_wed',
      dateIso: '2026-08-26',
      slotType: MvSlotType.strength,
      headlineFa: 'قدرت بالاتنه',
      targetMinutes: 30,
      isLocked: false,
      createdAt: 100,
      updatedAt: 100,
    );

    testWidgets('MvDaySlotCard renders lock icon and anchor badge when locked', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          const MvDaySlotCard(slot: lockedSlot),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('فوتسال هفتگی'), findsOneWidget);
      expect(find.byKey(const ValueKey('mv_slot_lock_icon')), findsOneWidget);
      expect(find.byKey(const ValueKey('mv_slot_anchor_badge')), findsOneWidget);
      expect(find.text('ورزش ثابت'), findsOneWidget);
    });

    testWidgets('MvTodayTab renders tomorrow anchor banner when next day is locked', (tester) async {
      final weekSlots = [
        normalSlot,
        lockedSlot, // tomorrow (2026-08-27)
      ];

      await tester.pumpWidget(
        createTestApp(
          MvTodayTab(
            weekSlots: weekSlots,
            todaySlot: normalSlot,
            readinessDecision: const MvDecision<MvReadinessTier>(
              value: MvReadinessTier.full,
              reasonFa: 'آمادگی کامل',
            ),
            budgetProgress: const MvWeeklyBudgetProgress(
              moderateEquivalentMinutes: 0,
              rawMetMinutes: 0,
              strengthDays: 0,
              targetMin: 150,
              targetOptimal: 300,
              strengthDaysTarget: 2,
            ),
            bodyMapDistribution: const MvBodyMapDistribution(
              muscleSessionCounts: {},
            ),
            onStartSession: () {},
            onSlotUpdated: (_) {},
            onCheckinSaved: (_) {},
            onQuickLogSaved: (a, b, c, d) async {},
            onDateSelected: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('mv_tomorrow_anchor_banner')), findsOneWidget);
      expect(find.textContaining('یادآوری: فردا فوتسال هفتگی'), findsOneWidget);
    });
  });
}
