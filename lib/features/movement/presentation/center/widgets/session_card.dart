import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/domain/models/movement_occurrence.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';
import 'package:ritmo/features/movement/presentation/common/movement_semantics.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';
import 'package:ritmo/features/movement/presentation/common/status_chip.dart';

/// کارت جلسه در لیست روز مرکز حرکت با ۷ حالت و اکشن‌های کم‌خطر
class SessionCard extends StatelessWidget {
  const SessionCard({
    super.key,
    required this.occurrence,
    required this.onTap,
    this.onStart,
    this.onManualLog,
    this.onMove,
    this.onShortVersion,
    this.onSkip,
    this.onEditPlan,
    this.onDelete,
    this.onQuickComplete,
  });

  final MovementOccurrence occurrence;
  final VoidCallback onTap;
  final VoidCallback? onStart;
  final VoidCallback? onManualLog;
  final VoidCallback? onMove;
  final VoidCallback? onShortVersion;
  final VoidCallback? onSkip;
  final VoidCallback? onEditPlan;
  final VoidCallback? onDelete;
  final VoidCallback? onQuickComplete;

  IconData _getActivityIcon(String? iconName) {
    return switch (iconName) {
      'directions_run' => Icons.directions_run_rounded,
      'directions_bike' => Icons.directions_bike_rounded,
      'pool' => Icons.pool_rounded,
      'sports_soccer' => Icons.sports_soccer_rounded,
      'hiking' => Icons.hiking_rounded,
      'self_improvement' => Icons.self_improvement_rounded,
      'fitness_center' => Icons.fitness_center_rounded,
      _ => Icons.directions_walk_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    final isCompleted = occurrence.isCompleted;
    final isSkipped = occurrence.status == MovementOccurrenceStatus.skipped;
    final activityName = occurrence.activityKind?.nameFa ?? 'جلسهٔ حرکتی';
    final timeStr = occurrence.startTime != null
        ? 'ساعت ${toPersianDigits(occurrence.startTime)}'
        : 'امروز';
    final goalStr = (occurrence.goalValue != null && occurrence.goalUnit != null)
        ? '${occurrence.goalValue!.round()} ${occurrence.goalUnit}'
        : 'هدف استاندارد';

    final semanticsLabel = MovementSemantics.sessionCardLabel(
      title: activityName,
      timeOrDuration: timeStr,
      targetOrType: goalStr,
      status: occurrence.status.name,
    );

    // رنگ نوار Accent
    Color accentColor = sportsColor;
    if (isCompleted) {
      accentColor = colors.primary;
    } else if (isSkipped) {
      accentColor = colors.disabled;
    } else if (occurrence.status == MovementOccurrenceStatus.late) {
      accentColor = colors.warning;
    }

    final cardContent = AnimatedOpacity(
      duration: RitmoMotion.effective(context, RitmoMotion.state),
      opacity: isCompleted ? 0.65 : (isSkipped ? 0.50 : 1.0),
      child: Container(
        constraints: const BoxConstraints(
          minHeight: MovementLayout.kSessionCardMinHeight,
        ),
        margin: const EdgeInsets.symmetric(
          horizontal: RitmoSpacing.lg,
          vertical: RitmoSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: BorderRadius.circular(RitmoRadius.card),
          border: Border.all(
            color: colors.border,
            width: RitmoElevation.borderWidthDark,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(RitmoRadius.card),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                RitmoHapticsPolicy.selection();
                onTap();
              },
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ۱. نوار Accent عمودی
                    Container(
                      width: MovementLayout.kAccentBarWidth,
                      color: accentColor,
                    ),

                    // ۲. بدنهٔ کارت
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: RitmoSpacing.md,
                          vertical: RitmoSpacing.sm,
                        ),
                        child: Row(
                          children: [
                            // آیکون فعالیت
                            Container(
                              width: MovementLayout.kActivityIconSize + 12,
                              height: MovementLayout.kActivityIconSize + 12,
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isCompleted
                                    ? Icons.check_rounded
                                    : _getActivityIcon(occurrence.activityKind?.icon),
                                color: accentColor,
                                size: MovementLayout.kActivityIconSize,
                              ),
                            ),
                            const SizedBox(width: RitmoSpacing.md),

                            // نام و مشخصات زمان · هدف
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    activityName,
                                    style: RitmoTextStyles.label(colors.textPrimary).copyWith(
                                      fontWeight: FontWeight.w700,
                                      decoration: isCompleted ? TextDecoration.none : null,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2.0),
                                  Text(
                                    '$timeStr · $goalStr',
                                    style: RitmoTextStyles.caption(colors.textSecondary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: RitmoSpacing.xs),

                            // چیپ وضعیت
                            StatusChip(
                              status: occurrence.status,
                              compact: false,
                            ),

                            // منوی بیشتر یا اکشن سریع
                            PopupMenuButton<String>(
                              icon: Icon(
                                Icons.more_vert_rounded,
                                color: colors.textSecondary,
                                size: 20,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(RitmoRadius.card),
                              ),
                              color: colors.surfaceElevated,
                              onSelected: (val) {
                                switch (val) {
                                  case 'start':
                                    onStart?.call();
                                    break;
                                  case 'manual':
                                    onManualLog?.call();
                                    break;
                                  case 'move':
                                    onMove?.call();
                                    break;
                                  case 'short':
                                    onShortVersion?.call();
                                    break;
                                  case 'skip':
                                    onSkip?.call();
                                    break;
                                  case 'edit':
                                    onEditPlan?.call();
                                    break;
                                  case 'delete':
                                    onDelete?.call();
                                    break;
                                }
                              },
                              itemBuilder: (ctx) => [
                                if (!isCompleted)
                                  PopupMenuItem(
                                    value: 'start',
                                    child: Row(
                                      children: [
                                        Icon(Icons.play_arrow_rounded, color: sportsColor, size: 18),
                                        const SizedBox(width: RitmoSpacing.sm),
                                        Text(MovementStrings.menuStart, style: RitmoTextStyles.label(colors.textPrimary)),
                                      ],
                                    ),
                                  ),
                                if (!isCompleted)
                                  PopupMenuItem(
                                    value: 'manual',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_note_rounded, color: colors.textSecondary, size: 18),
                                        const SizedBox(width: RitmoSpacing.sm),
                                        Text(MovementStrings.menuManualLog, style: RitmoTextStyles.label(colors.textPrimary)),
                                      ],
                                    ),
                                  ),
                                PopupMenuItem(
                                  value: 'move',
                                  child: Row(
                                    children: [
                                      Icon(Icons.swap_horiz_rounded, color: colors.textSecondary, size: 18),
                                      const SizedBox(width: RitmoSpacing.sm),
                                      Text(MovementStrings.menuMove, style: RitmoTextStyles.label(colors.textPrimary)),
                                    ],
                                  ),
                                ),
                                if (!isCompleted)
                                  PopupMenuItem(
                                    value: 'short',
                                    child: Row(
                                      children: [
                                        Icon(Icons.flash_on_rounded, color: colors.textSecondary, size: 18),
                                        const SizedBox(width: RitmoSpacing.sm),
                                        Text(MovementStrings.menuShortVersion, style: RitmoTextStyles.label(colors.textPrimary)),
                                      ],
                                    ),
                                  ),
                                if (!isCompleted && !isSkipped)
                                  PopupMenuItem(
                                    value: 'skip',
                                    child: Row(
                                      children: [
                                        Icon(Icons.close_rounded, color: colors.warning, size: 18),
                                        const SizedBox(width: RitmoSpacing.sm),
                                        Text(MovementStrings.menuSkip, style: RitmoTextStyles.label(colors.warning)),
                                      ],
                                    ),
                                  ),
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_calendar_rounded, color: colors.textSecondary, size: 18),
                                      const SizedBox(width: RitmoSpacing.sm),
                                      Text(MovementStrings.menuEditPlan, style: RitmoTextStyles.label(colors.textPrimary)),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline_rounded, color: colors.error, size: 18),
                                      const SizedBox(width: RitmoSpacing.sm),
                                      Text(MovementStrings.menuDelete, style: RitmoTextStyles.label(colors.error)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // سوایپ فقط برای اقدامات کم‌خطر (انجام شد یا جابه‌جایی)
    if (!isCompleted && onQuickComplete != null) {
      return Dismissible(
        key: ValueKey('session_card_${occurrence.id}'),
        direction: DismissDirection.startToEnd,
        confirmDismiss: (_) async {
          RitmoHapticsPolicy.selection();
          onQuickComplete!();
          return false; // برای اینکه کارت حذف نشود و فقط اکشن اجرا شود
        },
        background: Container(
          margin: const EdgeInsets.symmetric(
            horizontal: RitmoSpacing.lg,
            vertical: RitmoSpacing.xs,
          ),
          padding: const EdgeInsets.symmetric(horizontal: RitmoSpacing.xl),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(RitmoRadius.card),
          ),
          alignment: Alignment.centerRight,
          child: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: colors.primary),
              const SizedBox(width: RitmoSpacing.sm),
              Text(
                MovementStrings.statusCompleted,
                style: RitmoTextStyles.label(colors.primary),
              ),
            ],
          ),
        ),
        child: Semantics(
          label: semanticsLabel,
          container: true,
          excludeSemantics: true,
          child: cardContent,
        ),
      );
    }

    return Semantics(
      label: semanticsLabel,
      container: true,
      excludeSemantics: true,
      child: cardContent,
    );
  }
}
