import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/l10n/app_localizations.dart';

/// Day Slot Card for Week Tab (Section 5.2 & 5.10).
/// Refactored to RitmoCard.neumorphic with canonical badges.
class MvDaySlotCard extends StatelessWidget {
  final MvSlot slot;
  final VoidCallback? onTap;
  final VoidCallback? onConvertToRest;
  final VoidCallback? onMoveToTomorrow;
  final VoidCallback? onDelete;

  const MvDaySlotCard({
    super.key,
    required this.slot,
    this.onTap,
    this.onConvertToRest,
    this.onMoveToTomorrow,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    final dt = MvCalendar.parseDateIso(slot.dateIso);
    final weekdayName = MvCalendar.persianWeekdayName(
      MvCalendar.dateTimeToSat0(dt),
    );

    final Color statusColor;
    switch (slot.status) {
      case MvSlotStatus.done:
        statusColor = colors.success;
        break;
      case MvSlotStatus.partial:
      case MvSlotStatus.moved:
        statusColor = colors.warning;
        break;
      case MvSlotStatus.skipped:
        statusColor = colors.textSecondary;
        break;
      case MvSlotStatus.planned:
        statusColor = slot.isRest ? colors.textSecondary : colors.primary;
        break;
    }

    return RitmoCard.neumorphic(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Day Indicator Box
          RitmoNeuSurface(
            width: 44,
            height: 44,
            radius: 12,
            sunken: true,
            padding: EdgeInsets.zero,
            child: Center(
              child: Text(
                toPersianDigits(dt.day.toString()),
                style: textTheme.titleMedium?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Title and details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      weekdayName,
                      style: textTheme.labelSmall?.copyWith(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (slot.isRest) ...[
                      RitmoCardBadge(
                        key: const ValueKey('mv_slot_anchor_badge'),
                        label: slot.isLocked
                            ? (l10n?.mv_slot_anchor_badge_label ?? 'استراحت ثابت')
                            : (l10n?.mv_slot_rest_badge_label ?? 'استراحت'),
                        color: slot.isLocked ? colors.accent : colors.textSecondary,
                        icon: slot.isLocked ? Icons.lock_rounded : null,
                        isOutlined: !slot.isLocked,
                      ),
                    ] else if (slot.isLocked) ...[
                      RitmoCardBadge(
                        key: const ValueKey('mv_slot_anchor_badge'),
                        label: l10n?.mv_slot_anchor_badge_label ?? 'ورزش ثابت',
                        color: colors.accent,
                        icon: Icons.lock_rounded,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  slot.headlineFa,
                  style: textTheme.bodyLarge?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!slot.isRest) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${toPersianDigits(slot.targetMinutes.toString())} ${l10n?.mv_unit_min ?? 'min'} · ${slot.intensityTier.titleFa}${slot.plannedTime != null ? ' · ${l10n?.mv_at_time(toPersianDigits(slot.plannedTime)) ?? 'at ${slot.plannedTime}'}' : ''}',
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Status Badge
          RitmoCardBadge(
            label: slot.status.titleFa,
            color: statusColor,
          ),
          if (onDelete != null || onConvertToRest != null || onMoveToTomorrow != null) ...[
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              key: ValueKey('day_slot_menu_${slot.dateIso}'),
              icon: Icon(
                Icons.more_vert_rounded,
                size: 20,
                color: colors.textSecondary,
              ),
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: colors.surfaceElevated,
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_rounded, size: 18, color: colors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n?.mv_day_detail_edit_tooltip ?? 'ویرایش برنامه',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!slot.isRest) ...[
                  PopupMenuItem(
                    value: 'rest',
                    child: Row(
                      children: [
                        Icon(
                          Icons.spa_rounded,
                          size: 18,
                          color: colors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n?.mv_action_convert_rest ?? 'تبدیل به روز استراحت',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'tomorrow',
                    child: Row(
                      children: [
                        Icon(
                          Icons.event_repeat_rounded,
                          size: 18,
                          color: colors.accent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n?.mv_action_move_tomorrow ?? 'انتقال به فردا',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: colors.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n?.mv_plan_delete_action ?? 'حذف برنامهٔ این روز',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
              onSelected: (val) {
                if (val == 'edit') {
                  onTap?.call();
                } else if (val == 'rest') {
                  onConvertToRest?.call();
                } else if (val == 'tomorrow') {
                  onMoveToTomorrow?.call();
                } else if (val == 'delete') {
                  onDelete?.call();
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}
