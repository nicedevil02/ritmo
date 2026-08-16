import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/domain/models/movement_occurrence.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// وریانت‌های ۷ گانهٔ کارت شاخص Hero در مرکز حرکت
enum HeroCardVariant {
  emptyPlan,
  restDay,
  ready,
  late,
  multiToday,
  allDone,
  noPlanToday,
}

/// کارت شاخص هیرو با رعایت دقیق محدودیت ارتفاع و عدم پرش چیدمان
class HeroSessionCard extends StatelessWidget {
  const HeroSessionCard({
    super.key,
    required this.variant,
    this.primaryOccurrence,
    this.totalTodaySessions = 1,
    this.currentSessionIndex = 1,
    this.onPrimaryAction,
    this.onSecondaryAction,
    this.onMoveAction,
    this.onShortVersionAction,
    this.onLogManualAction,
    this.onSkipAction,
    this.onLogAnotherAction,
    this.onReviewWeekAction,
  });

  final HeroCardVariant variant;
  final MovementOccurrence? primaryOccurrence;
  final int totalTodaySessions;
  final int currentSessionIndex;
  final VoidCallback? onPrimaryAction;
  final VoidCallback? onSecondaryAction;
  final VoidCallback? onMoveAction;
  final VoidCallback? onShortVersionAction;
  final VoidCallback? onLogManualAction;
  final VoidCallback? onSkipAction;
  final VoidCallback? onLogAnotherAction;
  final VoidCallback? onReviewWeekAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: RitmoSpacing.lg,
        vertical: RitmoSpacing.sm,
      ),
      constraints: const BoxConstraints(
        minHeight: MovementLayout.kHeroMinHeight,
      ),
      padding: const EdgeInsets.all(RitmoSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(RitmoRadius.hero),
        border: Border.all(
          color: colors.border,
          width: RitmoElevation.borderWidthDark,
        ),
      ),
      child: _buildContent(context, colors, sportsColor),
    );
  }

  Widget _buildContent(
    BuildContext context,
    RitmoColors colors,
    Color sportsColor,
  ) {
    switch (variant) {
      case HeroCardVariant.emptyPlan:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  color: sportsColor,
                  size: MovementLayout.kActivityIconSize,
                ),
                const SizedBox(width: RitmoSpacing.sm),
                Expanded(
                  child: Text(
                    MovementStrings.heroBuildWeek,
                    style: RitmoTextStyles.cardTitle(colors.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: RitmoSpacing.sm),
            Text(
              MovementStrings.heroEmptyPlanDesc,
              style: RitmoTextStyles.body(colors.textSecondary),
            ),
            const SizedBox(height: RitmoSpacing.lg),
            SizedBox(
              height: MovementLayout.kPrimaryButtonHeight,
              child: FilledButton.icon(
                onPressed: () {
                  RitmoHapticsPolicy.selection();
                  onPrimaryAction?.call();
                },
                icon: const Icon(Icons.add_rounded),
                label: Text(
                  MovementStrings.centerAddActivity,
                  style: RitmoTextStyles.label(colors.onPrimary),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: sportsColor,
                  foregroundColor: colors.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(RitmoRadius.field),
                  ),
                ),
              ),
            ),
            if (onSecondaryAction != null) ...[
              const SizedBox(height: RitmoSpacing.sm),
              SizedBox(
                height: MovementLayout.kSecondaryButtonHeight,
                child: OutlinedButton(
                  onPressed: () {
                    RitmoHapticsPolicy.tap();
                    onSecondaryAction?.call();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: sportsColor,
                    side: BorderSide(
                      color: sportsColor.withValues(alpha: 0.5),
                      width: RitmoElevation.borderWidthDark,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(RitmoRadius.field),
                    ),
                  ),
                  child: Text(
                    MovementStrings.heroSmartWeek,
                    style: RitmoTextStyles.label(sportsColor),
                  ),
                ),
              ),
            ],
          ],
        );

      case HeroCardVariant.restDay:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.spa_rounded,
                  color: colors.primary,
                  size: MovementLayout.kActivityIconSize,
                ),
                const SizedBox(width: RitmoSpacing.sm),
                Expanded(
                  child: Text(
                    MovementStrings.heroRestDay,
                    style: RitmoTextStyles.cardTitle(colors.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: RitmoSpacing.sm),
            Text(
              MovementStrings.heroRestDayDesc,
              style: RitmoTextStyles.body(colors.textSecondary),
            ),
            const SizedBox(height: RitmoSpacing.lg),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: OutlinedButton.icon(
                onPressed: () {
                  RitmoHapticsPolicy.tap();
                  onSecondaryAction?.call();
                },
                icon: const Icon(Icons.self_improvement_rounded, size: 18),
                label: Text(
                  MovementStrings.heroActionLightMovement,
                  style: RitmoTextStyles.label(colors.primary),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.primary,
                  side: BorderSide(
                    color: colors.primary.withValues(alpha: 0.4),
                    width: RitmoElevation.borderWidthDark,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(RitmoRadius.pill),
                  ),
                ),
              ),
            ),
          ],
        );

      case HeroCardVariant.allDone:
        final activityName = primaryOccurrence?.activityKind?.nameFa ??
            MovementStrings.defaultTodaySessionName;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: colors.primary,
                  size: MovementLayout.kActivityIconSize,
                ),
                const SizedBox(width: RitmoSpacing.sm),
                Expanded(
                  child: Text(
                    MovementStrings.heroAllDone,
                    style: RitmoTextStyles.cardTitle(colors.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: RitmoSpacing.sm),
            Text(
              MovementStrings.heroAllDoneDesc(activityName),
              style: RitmoTextStyles.body(colors.textSecondary),
            ),
            const SizedBox(height: RitmoSpacing.lg),
            Wrap(
              spacing: RitmoSpacing.sm,
              runSpacing: RitmoSpacing.xs,
              children: [
                if (onLogAnotherAction != null)
                  TextButton.icon(
                    onPressed: () {
                      RitmoHapticsPolicy.tap();
                      onLogAnotherAction?.call();
                    },
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                    label: Text(
                      MovementStrings.heroActionLogAnother,
                      style: RitmoTextStyles.label(colors.primary),
                    ),
                  ),
                if (onReviewWeekAction != null)
                  TextButton.icon(
                    onPressed: () {
                      RitmoHapticsPolicy.tap();
                      onReviewWeekAction?.call();
                    },
                    icon: const Icon(Icons.insights_rounded, size: 18),
                    label: Text(
                      MovementStrings.heroActionReviewWeek,
                      style: RitmoTextStyles.label(colors.textSecondary),
                    ),
                  ),
              ],
            ),
          ],
        );

      case HeroCardVariant.noPlanToday:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.wb_sunny_outlined,
                  color: colors.textSecondary,
                  size: MovementLayout.kActivityIconSize,
                ),
                const SizedBox(width: RitmoSpacing.sm),
                Expanded(
                  child: Text(
                    MovementStrings.heroNoPlanToday,
                    style: RitmoTextStyles.cardTitle(colors.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: RitmoSpacing.md),
            SizedBox(
              height: MovementLayout.kPrimaryButtonHeight,
              child: FilledButton.icon(
                onPressed: () {
                  RitmoHapticsPolicy.selection();
                  onPrimaryAction?.call();
                },
                icon: const Icon(Icons.add_rounded),
                label: Text(
                  MovementStrings.centerAddActivity,
                  style: RitmoTextStyles.label(colors.onPrimary),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: sportsColor,
                  foregroundColor: colors.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(RitmoRadius.field),
                  ),
                ),
              ),
            ),
          ],
        );

      case HeroCardVariant.ready:
      case HeroCardVariant.late:
      case HeroCardVariant.multiToday:
        final occ = primaryOccurrence;
        final activityName =
            occ?.activityKind?.nameFa ?? MovementStrings.defaultSessionTitle;
        final isLate = variant == HeroCardVariant.late;
        final isMulti = variant == HeroCardVariant.multiToday;

        String timeStatus = occ?.startTime != null
            ? MovementStrings.atTime(occ!.startTime!)
            : MovementStrings.todayLabel;
        if (isLate) {
          timeStatus = MovementStrings.heroLate;
        } else if (isMulti) {
          timeStatus = MovementStrings.heroSessionProgress(
            currentSessionIndex,
            totalTodaySessions,
          );
        }

        final goalStr = (occ?.goalValue != null && occ?.goalUnit != null)
            ? '${occ!.goalValue!.round()} ${occ.goalUnit}'
            : MovementStrings.goalStandard;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ۱. وضعیت زمانی
            Text(
              timeStatus,
              style: RitmoTextStyles.caption(
                isLate ? colors.warning : colors.textSecondary,
              ).copyWith(
                fontWeight: isLate ? FontWeight.w700 : null,
              ),
            ),
            const SizedBox(height: RitmoSpacing.xs),

            // ۲. نام فعالیت
            Text(
              activityName,
              style: RitmoTextStyles.cardTitle(colors.textPrimary),
            ),
            const SizedBox(height: RitmoSpacing.xs),

            // ۳. هدف
            Text(
              goalStr,
              style: RitmoTextStyles.body(colors.textSecondary),
            ),

            const SizedBox(height: RitmoSpacing.lg),

            // ۴. CTA اصلی — همیشه با Accent ماژول؛ هشدار فقط در متن وضعیت
            SizedBox(
              height: MovementLayout.kPrimaryButtonHeight,
              child: FilledButton.icon(
                onPressed: () {
                  RitmoHapticsPolicy.selection();
                  onPrimaryAction?.call();
                },
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(
                  isLate
                      ? MovementStrings.heroActionDoNow
                      : MovementStrings.heroStart,
                  style: RitmoTextStyles.label(colors.onPrimary),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: sportsColor,
                  foregroundColor: colors.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(RitmoRadius.field),
                  ),
                ),
              ),
            ),

            const SizedBox(height: RitmoSpacing.sm),

            // ۵. اکشن‌های تطبیقی (حداکثر ۳ اکشن)
            Wrap(
              spacing: RitmoSpacing.xs,
              runSpacing: RitmoSpacing.xs,
              children: [
                if (onMoveAction != null)
                  TextButton.icon(
                    onPressed: () {
                      RitmoHapticsPolicy.tap();
                      onMoveAction?.call();
                    },
                    icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                    label: Text(
                      MovementStrings.heroActionMove,
                      style: RitmoTextStyles.caption(colors.textSecondary),
                    ),
                  ),
                if (onShortVersionAction != null && !isLate)
                  TextButton.icon(
                    onPressed: () {
                      RitmoHapticsPolicy.tap();
                      onShortVersionAction?.call();
                    },
                    icon: const Icon(Icons.flash_on_rounded, size: 16),
                    label: Text(
                      MovementStrings.heroActionShortVersion,
                      style: RitmoTextStyles.caption(colors.textSecondary),
                    ),
                  ),
                if (onLogManualAction != null && !isLate)
                  TextButton.icon(
                    onPressed: () {
                      RitmoHapticsPolicy.tap();
                      onLogManualAction?.call();
                    },
                    icon: const Icon(Icons.edit_note_rounded, size: 16),
                    label: Text(
                      MovementStrings.heroActionLogManual,
                      style: RitmoTextStyles.caption(colors.textSecondary),
                    ),
                  ),
                if (onSkipAction != null && isLate)
                  TextButton.icon(
                    onPressed: () {
                      RitmoHapticsPolicy.tap();
                      onSkipAction?.call();
                    },
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: Text(
                      MovementStrings.heroActionSkip,
                      style: RitmoTextStyles.caption(colors.textTertiary),
                    ),
                  ),
              ],
            ),
          ],
        );
    }
  }
}
