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

  const MvDaySlotCard({super.key, required this.slot, this.onTap});

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
                Row(
                  children: [
                    Text(
                      weekdayName,
                      style: textTheme.labelSmall?.copyWith(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (slot.isLocked) ...[
                      const SizedBox(width: 6),
                      RitmoCardBadge(
                        key: const ValueKey('mv_slot_anchor_badge'),
                        label: l10n?.mv_slot_anchor_badge_label ?? 'Fixed',
                        color: colors.accent,
                        icon: Icons.lock_rounded,
                      ),
                    ],
                    if (slot.isRest) ...[
                      const SizedBox(width: 6),
                      RitmoCardBadge(
                        label: l10n?.mv_slot_rest_badge_label ?? 'Rest',
                        color: colors.textSecondary,
                        isOutlined: true,
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
        ],
      ),
    );
  }
}
