import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/engines.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/features/supplementary_sports/presentation/components/mv_day_slot_card.dart';
import 'package:ritmo/features/supplementary_sports/presentation/components/mv_week_rail.dart';
import 'package:ritmo/features/supplementary_sports/presentation/screens/mv_today_tab.dart';
import 'package:ritmo/features/supplementary_sports/presentation/screens/mv_week_tab.dart';

void main() {
  group('S2-T6 Anchor Display in DaySlotCard, TodayTab, WeekRail, and WeekTab', () {
    testWidgets('MvDaySlotCard renders lock icon and planned time when isLocked == true', (tester) async {
      final lockedSlot = MvSlot(
        id: 'slot_2026-08-27',
        dateIso: '2026-08-27',
        cycleWeek: 1,
        slotType: MvSlotType.sport,
        kindCode: 'FUTSAL',
        headlineFa: 'فوتسال پنجشنبه‌ها',
        targetMinutes: 90,
        plannedTime: '21:00',
        isLocked: true,
        intensityTier: MvIntensityTier.hard,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MvDaySlotCard(slot: lockedSlot),
          ),
        ),
      );

      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
      expect(find.textContaining('ساعت ۲۱:۰۰'), findsOneWidget);
      expect(find.text('فوتسال پنجشنبه‌ها'), findsOneWidget);
    });

    testWidgets('MvWeekRail renders mini lock icon for locked anchor slots', (tester) async {
      final slots = [
        MvSlot(
          id: 'slot_2026-08-22',
          dateIso: '2026-08-22',
          cycleWeek: 1,
          slotType: MvSlotType.strength,
          headlineFa: 'تمرین قدرتی',
          targetMinutes: 30,
          isLocked: false,
          intensityTier: MvIntensityTier.moderate,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
        MvSlot(
          id: 'slot_2026-08-27',
          dateIso: '2026-08-27',
          cycleWeek: 1,
          slotType: MvSlotType.sport,
          kindCode: 'FUTSAL',
          headlineFa: 'فوتسال پنجشنبه‌ها',
          targetMinutes: 90,
          plannedTime: '21:00',
          isLocked: true,
          intensityTier: MvIntensityTier.hard,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MvWeekRail(
              weekSlots: slots,
              selectedDateIso: '2026-08-22',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
    });

    testWidgets('MvTodayTab displays tomorrow anchor notice if tomorrow is a locked anchor slot', (tester) async {
      final todaySlot = MvSlot(
        id: 'slot_2026-08-26',
        dateIso: '2026-08-26', // چهارشنبه
        cycleWeek: 1,
        slotType: MvSlotType.rest,
        headlineFa: 'استراحت',
        targetMinutes: 0,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      final tomorrowLockedSlot = MvSlot(
        id: 'slot_2026-08-27',
        dateIso: '2026-08-27', // پنجشنبه
        cycleWeek: 1,
        slotType: MvSlotType.sport,
        kindCode: 'FUTSAL',
        headlineFa: 'فوتسال پنجشنبه‌ها',
        targetMinutes: 90,
        plannedTime: '21:00',
        isLocked: true,
        intensityTier: MvIntensityTier.hard,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      final weekSlots = [todaySlot, tomorrowLockedSlot];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MvTodayTab(
              weekSlots: weekSlots,
              todaySlot: todaySlot,
              readinessDecision: const MvDecision(value: MvReadinessTier.full, reasonFa: 'آماده'),
              budgetProgress: const MvWeeklyBudgetProgress(moderateEquivalentMinutes: 100, rawMetMinutes: 300, strengthDays: 2),
              bodyMapDistribution: const MvBodyMapDistribution(muscleSessionCounts: {}),
              onStartSession: () {},
              onSlotUpdated: (_) {},
              onCheckinSaved: (_) {},
              onQuickLogSaved: (a, b, c, d) async {},
              onDateSelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('mv_tomorrow_anchor_notice')), findsOneWidget);
      expect(find.textContaining('یادآوری: فردا فوتسال پنجشنبه‌ها (ساعت ۲۱:۰۰)'), findsOneWidget);
    });

    testWidgets('MvTodayTab hides tomorrow anchor notice when tomorrow is not locked', (tester) async {
      final todaySlot = MvSlot(
        id: 'slot_2026-08-26',
        dateIso: '2026-08-26',
        cycleWeek: 1,
        slotType: MvSlotType.rest,
        headlineFa: 'استراحت',
        targetMinutes: 0,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      final tomorrowNormalSlot = MvSlot(
        id: 'slot_2026-08-27',
        dateIso: '2026-08-27',
        cycleWeek: 1,
        slotType: MvSlotType.strength,
        headlineFa: 'تمرین بالا تنه',
        targetMinutes: 30,
        isLocked: false,
        intensityTier: MvIntensityTier.moderate,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      final weekSlots = [todaySlot, tomorrowNormalSlot];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MvTodayTab(
              weekSlots: weekSlots,
              todaySlot: todaySlot,
              readinessDecision: const MvDecision(value: MvReadinessTier.full, reasonFa: 'آماده'),
              budgetProgress: const MvWeeklyBudgetProgress(moderateEquivalentMinutes: 100, rawMetMinutes: 300, strengthDays: 2),
              bodyMapDistribution: const MvBodyMapDistribution(muscleSessionCounts: {}),
              onStartSession: () {},
              onSlotUpdated: (_) {},
              onCheckinSaved: (_) {},
              onQuickLogSaved: (a, b, c, d) async {},
              onDateSelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('mv_tomorrow_anchor_notice')), findsNothing);
    });

    testWidgets('MvWeekTab displays conflict banner when 2 back-to-back locked anchor slots exist', (tester) async {
      final weekSlots = [
        MvSlot(
          id: 'slot_2026-08-26',
          dateIso: '2026-08-26', // چهارشنبه
          cycleWeek: 1,
          slotType: MvSlotType.rest,
          headlineFa: 'استراحت',
          targetMinutes: 0,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
        MvSlot(
          id: 'slot_2026-08-27',
          dateIso: '2026-08-27', // پنجشنبه (Anchor 1)
          cycleWeek: 1,
          slotType: MvSlotType.sport,
          kindCode: 'FUTSAL',
          headlineFa: 'فوتسال',
          targetMinutes: 90,
          plannedTime: '21:00',
          isLocked: true,
          intensityTier: MvIntensityTier.hard,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
        MvSlot(
          id: 'slot_2026-08-28',
          dateIso: '2026-08-28', // جمعه (Anchor 2 - Back to back!)
          cycleWeek: 1,
          slotType: MvSlotType.sport,
          kindCode: 'SWIMMING',
          headlineFa: 'استخر و شنا',
          targetMinutes: 60,
          plannedTime: '10:00',
          isLocked: true,
          intensityTier: MvIntensityTier.moderate,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MvWeekTab(
              weekSlots: weekSlots,
              cycleWeek: 1,
              onSlotUpdated: (_) {},
              onRegenerateWeek: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('mv_conflict_back_to_back')), findsOneWidget);
      expect(find.textContaining('توجه: دو روز ورزش متوالی با تعهد ثابت تنظیم شده است'), findsOneWidget);
    });

    testWidgets('MvWeekTab hides conflict banner when only 1 locked anchor slot exists', (tester) async {
      final weekSlots = [
        MvSlot(
          id: 'slot_2026-08-26',
          dateIso: '2026-08-26',
          cycleWeek: 1,
          slotType: MvSlotType.rest,
          headlineFa: 'استراحت',
          targetMinutes: 0,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
        MvSlot(
          id: 'slot_2026-08-27',
          dateIso: '2026-08-27',
          cycleWeek: 1,
          slotType: MvSlotType.sport,
          kindCode: 'FUTSAL',
          headlineFa: 'فوتسال',
          targetMinutes: 90,
          plannedTime: '21:00',
          isLocked: true,
          intensityTier: MvIntensityTier.hard,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
        MvSlot(
          id: 'slot_2026-08-28',
          dateIso: '2026-08-28',
          cycleWeek: 1,
          slotType: MvSlotType.rest,
          headlineFa: 'استراحت',
          targetMinutes: 0,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MvWeekTab(
              weekSlots: weekSlots,
              cycleWeek: 1,
              onSlotUpdated: (_) {},
              onRegenerateWeek: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('mv_conflict_back_to_back')), findsNothing);
    });
  });
}
