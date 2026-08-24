import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/application/movement_readiness_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_live_session.dart';
import 'package:ritmo/features/movement/domain/models/movement_occurrence.dart';
import 'package:ritmo/features/movement/domain/models/movement_tier.dart';
import 'package:ritmo/features/movement/domain/models/movement_week_stats.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/hero_session_card.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/live_session_banner.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/session_card.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/week_rail.dart';

/// وضعیت A صفحهٔ اصلی: کاربر برای امروز جلسه دارد (P-08)
class MovementHasSessionView extends StatelessWidget {
  const MovementHasSessionView({
    super.key,
    required this.occurrence,
    this.dayOccurrences = const [],
    this.activeSession,
    required this.weekStats,
    required this.readiness,
    required this.tier,
    required this.railDays,
    required this.onStartSession,
    required this.onQuickLog,
    required this.onSelectDay,
    this.onDismissOccurrence,
    this.onMoveSession,
    this.onPlanB,
    this.onSkipSession,
    this.onRetroLog,
    this.onReviewWeek,
    this.onResumeActiveSession,
    this.onFinishActiveSession,
    this.onDiscardActiveSession,
    this.onStartSpecificOccurrence,
    this.onQuickLogSpecificOccurrence,
  });

  final MovementOccurrence occurrence;
  final List<MovementOccurrence> dayOccurrences;
  final MovementLiveSession? activeSession;
  final MovementWeekStats weekStats;
  final ReadinessResult readiness;
  final MovementTier tier;
  final List<MovementDayData> railDays;
  final VoidCallback onStartSession;
  final VoidCallback onQuickLog;
  final ValueChanged<DateTime> onSelectDay;
  final VoidCallback? onDismissOccurrence;
  final VoidCallback? onMoveSession;
  final VoidCallback? onPlanB;
  final VoidCallback? onSkipSession;
  final VoidCallback? onRetroLog;
  final VoidCallback? onReviewWeek;
  final VoidCallback? onResumeActiveSession;
  final VoidCallback? onFinishActiveSession;
  final VoidCallback? onDiscardActiveSession;
  final void Function(MovementOccurrence occ)? onStartSpecificOccurrence;
  final void Function(MovementOccurrence occ)? onQuickLogSpecificOccurrence;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    // ۱. متن آمادگی
    final String readinessText;
    if (readiness is ReadinessReady) {
      readinessText = (readiness as ReadinessReady).suggestionFa;
    } else {
      readinessText = 'امروز داده‌ای برای پیشنهاد نداریم. هر مقداری که راحتی تمرین کن.';
    }

    // ۲. قرارداد هفتگی (فقط در صورت اطمینان نمونه)
    final contractLabel = weekStats.weekContractLabel();

    // تعیین وریانت کارت هیرو
    final HeroCardVariant heroVariant;
    if (dayOccurrences.isNotEmpty && dayOccurrences.every((o) => o.isCompleted)) {
      heroVariant = HeroCardVariant.allDone;
    } else if (dayOccurrences.length > 1) {
      heroVariant = HeroCardVariant.multiToday;
    } else if (occurrence.isCompleted) {
      heroVariant = HeroCardVariant.allDone;
    } else {
      heroVariant = HeroCardVariant.ready;
    }

    final secondaryOccurrences = dayOccurrences.where((o) => o.id != occurrence.id).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ریل هفتگی
        WeekRail(
          days: railDays,
          onDaySelected: onSelectDay,
        ),
        const SizedBox(height: RitmoSpacing.md),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: RitmoSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // بنر تمرین زنده در صورت وجود
                if (activeSession != null) ...[
                  LiveSessionBanner(
                    session: activeSession!,
                    onResume: onResumeActiveSession ?? onStartSession,
                    onFinishAndSave: onFinishActiveSession ?? onQuickLog,
                    onDiscard: onDiscardActiveSession ?? () {},
                  ),
                  const SizedBox(height: RitmoSpacing.md),
                ],

                // برچسب قرارداد هفتگی
                if (contractLabel.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: RitmoSpacing.xs),
                    child: Text(
                      contractLabel,
                      style: RitmoTextStyles.sectionHeadline(sportsColor),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: RitmoSpacing.sm),
                ],

                // کارت هیرو جلسه شاخص امروز
                HeroSessionCard(
                  variant: heroVariant,
                  primaryOccurrence: occurrence,
                  totalTodaySessions: dayOccurrences.isEmpty ? 1 : dayOccurrences.length,
                  currentSessionIndex: 1,
                  onPrimaryAction: onStartSession,
                  onMoveAction: onMoveSession,
                  onShortVersionAction: onPlanB,
                  onSkipAction: onSkipSession ?? onDismissOccurrence,
                  onLogManualAction: onRetroLog,
                  onReviewWeekAction: onReviewWeek,
                ),
                const SizedBox(height: RitmoSpacing.md),

                // دکمهٔ ثبت ۵ ثانیه‌ای برای کاربران Tier 1 در صورت عدم تکمیل
                if (tier == MovementTier.one && !occurrence.isCompleted) ...[
                  ElevatedButton.icon(
                    onPressed: onQuickLog,
                    icon: const Icon(Icons.bolt_rounded),
                    label: const Text('ثبت ۵ ثانیه‌ای جلسه'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: sportsColor,
                      foregroundColor: colors.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: RitmoSpacing.md),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(RitmoRadius.field),
                      ),
                    ),
                  ),
                  const SizedBox(height: RitmoSpacing.md),
                ],

                // بخش جلسات بعدی امروز در صورت وجود بیش از ۱ جلسه
                if (secondaryOccurrences.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(
                      right: RitmoSpacing.xs,
                      bottom: RitmoSpacing.sm,
                    ),
                    child: Text(
                      'سایر جلسات امروز',
                      style: RitmoTextStyles.cardTitle(colors.textPrimary),
                    ),
                  ),
                  for (final secOcc in secondaryOccurrences) ...[
                    SessionCard(
                      occurrence: secOcc,
                      onTap: () => onStartSpecificOccurrence?.call(secOcc),
                      onStart: () => onStartSpecificOccurrence?.call(secOcc),
                      onQuickComplete: () => onQuickLogSpecificOccurrence?.call(secOcc),
                      onMove: onMoveSession,
                      onShortVersion: onPlanB,
                      onSkip: onSkipSession,
                      onManualLog: onRetroLog,
                    ),
                    const SizedBox(height: RitmoSpacing.sm),
                  ],
                  const SizedBox(height: RitmoSpacing.sm),
                ],

                // پیشنهاد آمادگی بدنی
                Container(
                  padding: const EdgeInsets.all(RitmoSpacing.md),
                  decoration: BoxDecoration(
                    color: colors.surfaceElevated,
                    borderRadius: BorderRadius.circular(RitmoRadius.card),
                    border: Border.all(color: colors.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 20, color: colors.textSecondary),
                      const SizedBox(width: RitmoSpacing.sm),
                      Expanded(
                        child: Text(
                          readinessText,
                          style: RitmoTextStyles.body(colors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: RitmoSpacing.xl),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
