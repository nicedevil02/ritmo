import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/application/movement_readiness_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_occurrence.dart';
import 'package:ritmo/features/movement/domain/models/movement_tier.dart';
import 'package:ritmo/features/movement/domain/models/movement_week_stats.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/hero_session_card.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/week_rail.dart';

/// وضعیت A صفحهٔ اصلی: کاربر برای امروز جلسه دارد (P-08)
class MovementHasSessionView extends StatelessWidget {
  const MovementHasSessionView({
    super.key,
    required this.occurrence,
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
  });

  final MovementOccurrence occurrence;
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

                // کارت قهرمان جلسهٔ امروز
                HeroSessionCard(
                  variant: occurrence.isCompleted
                      ? HeroCardVariant.allDone
                      : HeroCardVariant.ready,
                  primaryOccurrence: occurrence,
                  onPrimaryAction: onStartSession,
                  onMoveAction: onMoveSession,
                  onShortVersionAction: onPlanB,
                  onSkipAction: onSkipSession ?? onDismissOccurrence,
                  onLogManualAction: onRetroLog,
                  onReviewWeekAction: onReviewWeek,
                ),
                const SizedBox(height: RitmoSpacing.lg),

                // دکمه‌های اقدام اصلی (بر اساس Tier)
                if (tier == MovementTier.one) ...[
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
                ] else ...[
                  ElevatedButton.icon(
                    onPressed: onStartSession,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('شروع تمرین'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: sportsColor,
                      foregroundColor: colors.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: RitmoSpacing.md),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(RitmoRadius.field),
                      ),
                    ),
                  ),
                  const SizedBox(height: RitmoSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: onQuickLog,
                    icon: const Icon(Icons.bolt_rounded),
                    label: const Text('ثبت سریع (انجام شد)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.textPrimary,
                      side: BorderSide(color: colors.borderSubtle),
                      padding: const EdgeInsets.symmetric(vertical: RitmoSpacing.sm),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(RitmoRadius.field),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: RitmoSpacing.md),

                // پیشنهاد آمادگی (زیر دکمه)
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
