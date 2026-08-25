import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/engines.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import '../components/components.dart';
import '../sheets/sheets.dart';

/// Tab 1: "امروز" (Section 5.1).
/// Central focal screen answering "What to do now, why, and where I am headed".
class MvTodayTab extends StatelessWidget {
  final List<MvSlot> weekSlots;
  final MvSlot todaySlot;
  final MvDecision<MvReadinessTier> readinessDecision;
  final MvWeeklyBudgetProgress budgetProgress;
  final MvBodyMapDistribution bodyMapDistribution;
  final String? heroAnimationAsset;
  final VoidCallback onStartSession;
  final VoidCallback? onContinueSession;
  final bool isSessionInProgress;
  final ValueChanged<MvSlot> onSlotUpdated;
  final ValueChanged<MvDailyCheckin> onCheckinSaved;
  final Future<void> Function(String kindCode, int duration, MvSessionFeeling? feeling, String? note) onQuickLogSaved;
  final ValueChanged<String> onDateSelected;

  const MvTodayTab({
    super.key,
    required this.weekSlots,
    required this.todaySlot,
    required this.readinessDecision,
    required this.budgetProgress,
    required this.bodyMapDistribution,
    this.heroAnimationAsset,
    required this.onStartSession,
    this.onContinueSession,
    this.isSessionInProgress = false,
    required this.onSlotUpdated,
    required this.onCheckinSaved,
    required this.onQuickLogSaved,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = context.metrics;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(vertical: metrics.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Week Rail
          MvWeekRail(
            weekSlots: weekSlots,
            selectedDateIso: todaySlot.dateIso,
            onDateSelected: onDateSelected,
          ),
          SizedBox(height: metrics.spaceMd),

          // 2. Readiness Bar (tap to open quick checkin)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: metrics.spaceLg),
            child: MvReadinessBar(
              decision: readinessDecision,
              onTap: () {
                MvQuickCheckinSheet.show(
                  context: context,
                  dateIso: todaySlot.dateIso,
                  onSave: onCheckinSaved,
                );
              },
            ),
          ),
          SizedBox(height: metrics.spaceLg),

          // 3. Hero Card (Max 1 primary and 1 secondary action, AC-02)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: metrics.spaceLg),
            child: MvHeroCard(
              slot: todaySlot,
              readinessTier: readinessDecision.value,
              isInProgress: isSessionInProgress,
              animationWidget: MvAnimationStage(
                height: 180,
                exerciseId: heroAnimationAsset ??
                    (todaySlot.focusCodes.isNotEmpty ? 'bo009_squats' : 'bo001_side_leg_lift'),
                animationAsset: heroAnimationAsset,
              ),
              onStart: onStartSession,
              onContinue: onContinueSession,
              onCantToday: () {
                MvCantTodaySheet.show(
                  context: context,
                  slot: todaySlot,
                  onMinimalDose: () {
                    final adapted = todaySlot.copyWith(
                      targetMinutes: 10,
                      headlineFa: 'حداقل مؤثر ۱۰ دقیقه‌ای',
                      coachNoteFa: 'جلسهٔ کوتاه و سبک برای حفظ پیوستگی.',
                    );
                    onSlotUpdated(adapted);
                  },
                  onMoveToTomorrow: () {
                    final dt = MvCalendar.parseDateIso(todaySlot.dateIso);
                    final tomorrowIso = MvCalendar.formatDateIso(dt.add(const Duration(days: 1)));
                    final moved = todaySlot.copyWith(
                      status: MvSlotStatus.moved,
                      movedToDateIso: tomorrowIso,
                    );
                    onSlotUpdated(moved);
                  },
                  onChangeToStretch: () {
                    final stretch = todaySlot.copyWith(
                      slotType: MvSlotType.mobility,
                      targetMinutes: 10,
                      headlineFa: 'کشش و آرامش عضلات',
                    );
                    onSlotUpdated(stretch);
                  },
                  onSkipEntirely: () {
                    final skipped = todaySlot.copyWith(status: MvSlotStatus.skipped);
                    onSlotUpdated(skipped);
                  },
                );
              },
            ),
          ),
          SizedBox(height: metrics.spaceLg),

          // 4. Quick Activity Log (Two-tap action, AC-06, N-01)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: metrics.spaceLg),
            child: MvQuickLogRow(
              onQuickWalk: () => onQuickLogSaved('walking', 30, MvSessionFeeling.good, null),
              onQuickStretch: () => onQuickLogSaved('stretching', 15, MvSessionFeeling.easy, null),
              onCustomLog: () {
                MvQuickLogSheet.show(
                  context: context,
                  initialKindCode: 'cardio',
                  initialDuration: 30,
                  onSave: (kindCode, dur, feel, note) => onQuickLogSaved(kindCode, dur, feel, note),
                );
              },
            ),
          ),
          SizedBox(height: metrics.spaceLg),

          // 5. Weekly MET-min Budget Ring (AC-07, F-22)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: metrics.spaceLg),
            child: MvMetricRing(
              currentMet: budgetProgress.currentMetMinutes.toDouble(),
              targetMet: budgetProgress.targetMetMinutes.toDouble(),
              activeDays: budgetProgress.currentActiveDays,
              targetDays: budgetProgress.targetActiveDays,
            ),
          ),
          SizedBox(height: metrics.spaceLg),

          // 6. Anatomical Body Map (AC-08, F-21)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: metrics.spaceLg),
            child: MvBodyMap(
              distribution: bodyMapDistribution,
              onSuggestedActionTap: () {
                // Focus neglected group in next planned session
              },
            ),
          ),
          SizedBox(height: metrics.spaceXxl),
        ],
      ),
    );
  }
}
