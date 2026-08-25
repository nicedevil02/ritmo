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
                exerciseId: todaySlot.focusCodes.isNotEmpty ? 'bo009_squats' : 'bo001_side_leg_lift',
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
          SizedBox(height: metrics.spaceXl),

          // 4. Quick Log Activity Row
          Padding(
            padding: EdgeInsets.symmetric(horizontal: metrics.spaceLg),
            child: MvQuickLogRow(
              onQuickWalk: () => onQuickLogSaved('walking', 20, MvSessionFeeling.good, null),
              onQuickStretch: () => onQuickLogSaved('stretching', 10, MvSessionFeeling.good, null),
              onCustomLog: () {
                MvQuickLogSheet.show(
                  context: context,
                  onSave: onQuickLogSaved,
                );
              },
            ),
          ),
          SizedBox(height: metrics.spaceXl),

          // 5. Body Map Muscle Workload (N-03)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: metrics.spaceLg),
            child: MvBodyMap(
              distribution: bodyMapDistribution,
              onSuggestedActionTap: () {
                if (bodyMapDistribution.neglectedMuscleGroupCode != null) {
                  final groupCode = bodyMapDistribution.neglectedMuscleGroupCode!;
                  final adapted = todaySlot.copyWith(
                    focusCodes: [groupCode],
                    targetMinutes: 15,
                    headlineFa: 'تقویت عضلات $groupCode',
                  );
                  onSlotUpdated(adapted);
                }
              },
            ),
          ),
          SizedBox(height: metrics.spaceXl),

          // 6. Metric Ring (Weekly MET-min progress)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: metrics.spaceLg),
            child: MvMetricRing(
              currentMet: budgetProgress.currentMetMinutes,
              targetMet: budgetProgress.targetMetMinutes,
              activeDays: budgetProgress.currentActiveDays,
              targetDays: budgetProgress.targetActiveDays,
            ),
          ),
          SizedBox(height: metrics.spaceXxl),
        ],
      ),
    );
  }
}
