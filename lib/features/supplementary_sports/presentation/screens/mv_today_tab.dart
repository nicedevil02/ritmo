import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/supplementary_sports/application/application.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/engines.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/l10n/app_localizations.dart';
import '../components/components.dart';
import '../sheets/sheets.dart';

/// Tab 1: "امروز" (Section 5.1 & S2-T6).
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
  final MvKindUseCase? kindUseCase;
  final Future<void> Function(
    String kindCode,
    int duration,
    MvSessionFeeling? feeling,
    String? note,
  )
  onQuickLogSaved;
  final ValueChanged<String> onDateSelected;
  final double topPadding;

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
    this.kindUseCase,
    required this.onQuickLogSaved,
    required this.onDateSelected,
    this.topPadding = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    final dt = MvCalendar.parseDateIso(todaySlot.dateIso);
    final tomorrowIso = MvCalendar.formatDateIso(
      dt.add(const Duration(days: 1)),
    );
    final tomorrowSlot = weekSlots
        .where((s) => s.dateIso == tomorrowIso)
        .firstOrNull;
    final showTomorrowAnchor =
        tomorrowSlot != null && tomorrowSlot.isLocked && !tomorrowSlot.isRest;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: EdgeInsets.fromLTRB(10, topPadding, 10, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Week Rail
          MvWeekRail(
            weekSlots: weekSlots,
            selectedDateIso: todaySlot.dateIso,
            onDateSelected: onDateSelected,
          ),
          const SizedBox(height: 16),

          // Tomorrow Anchor Notice (S2-T6, S8-T5)
          if (showTomorrowAnchor) ...[
            RitmoCard.neumorphic(
              key: const ValueKey('mv_tomorrow_anchor_banner'),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_clock_rounded,
                    size: 20,
                    color: colors.accent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n != null && tomorrowSlot.plannedTime != null
                          ? l10n.mv_tomorrow_anchor_notice(
                              tomorrowSlot.headlineFa,
                              toPersianDigits(tomorrowSlot.plannedTime),
                            )
                          : (l10n?.mv_tomorrow_anchor_notice(
                                tomorrowSlot.headlineFa,
                                toPersianDigits(tomorrowSlot.plannedTime ?? ''),
                              ) ??
                              'Tomorrow: ${tomorrowSlot.headlineFa}'),
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 2. Readiness Bar (tap to open quick checkin)
          MvReadinessBar(
            decision: readinessDecision,
            onTap: () {
              MvQuickCheckinSheet.show(
                context: context,
                dateIso: todaySlot.dateIso,
                onSave: onCheckinSaved,
              );
            },
          ),
          const SizedBox(height: 16),

          // 3. Hero Card (Max 1 primary and 1 secondary action, AC-02)
          MvHeroCard(
            slot: todaySlot,
            readinessTier: readinessDecision.value,
            isInProgress: isSessionInProgress,
            animationWidget: MvAnimationStage(
              height: 180,
              exerciseId:
                  heroAnimationAsset ??
                  (todaySlot.focusCodes.isNotEmpty
                      ? 'bo009_squats'
                      : 'bo001_side_leg_lift'),
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
                    headlineFa: l10n?.mv_cant_today_option_minimal_title ?? 'Minimal Effective Dose',
                    coachNoteFa: l10n?.mv_cant_today_option_minimal_desc ?? 'Short and light session.',
                  );
                  onSlotUpdated(adapted);
                },
                onMoveToTomorrow: () {
                  final dt = MvCalendar.parseDateIso(todaySlot.dateIso);
                  final tomorrowIso = MvCalendar.formatDateIso(
                    dt.add(const Duration(days: 1)),
                  );
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
                    headlineFa: l10n?.mv_cant_today_option_stretch_title ?? 'Stretch & Recovery',
                  );
                  onSlotUpdated(stretch);
                },
                onSkipEntirely: () {
                  final skipped = todaySlot.copyWith(
                    status: MvSlotStatus.skipped,
                  );
                  onSlotUpdated(skipped);
                },
              );
            },
          ),
          const SizedBox(height: 16),

          // 4. Quick Activity Log (Two-tap action, AC-06, N-01)
          MvQuickLogRow(
            onQuickWalk: () => onQuickLogSaved(
              MvKindCodes.walking,
              30,
              MvSessionFeeling.good,
              null,
            ),
            onQuickStretch: () => onQuickLogSaved(
              MvKindCodes.stretching,
              15,
              MvSessionFeeling.easy,
              null,
            ),
            onCustomLog: () {
              MvQuickLogSheet.show(
                context: context,
                initialKindCode: MvKindCodes.running,
                initialDuration: 30,
                kindUseCase: kindUseCase,
                onSave: (kindCode, dur, feel, note) =>
                    onQuickLogSaved(kindCode, dur, feel, note),
              );
            },
          ),
          const SizedBox(height: 16),

          // 5. Weekly MET-min Budget Ring (AC-07, F-22)
          MvMetricRing(
            currentMet: budgetProgress.currentMetMinutes.toDouble(),
            targetMet: budgetProgress.targetMetMinutes.toDouble(),
            activeDays: budgetProgress.currentActiveDays,
            targetDays: budgetProgress.targetActiveDays,
          ),
          const SizedBox(height: 16),

          // 6. Anatomical Body Map (AC-08, F-21)
          MvBodyMap(
            distribution: bodyMapDistribution,
            onSuggestedActionTap: () {
              // Focus neglected group in next planned session
            },
          ),
          SizedBox(height: metrics.spaceXxl),
        ],
      ),
    );
  }
}
