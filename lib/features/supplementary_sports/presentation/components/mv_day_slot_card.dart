import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/l10n/app_localizations.dart';

/// Day Slot Card for Week Tab (Section 5.2 & 5.10).
class MvDaySlotCard extends StatelessWidget {
  final MvSlot slot;
  final VoidCallback? onTap;

  const MvDaySlotCard({super.key, required this.slot, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.ritmoColors;
    final metrics = context.metrics;
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(metrics.radiusCard),
        child: Container(
          padding: EdgeInsets.all(metrics.spaceLg),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(metrics.radiusCard),
            border: Border.all(color: colors.border.withValues(alpha: 0.7)),
          ),
          child: Row(
            children: [
              // Day Indicator Box
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.surfaceElevated,
                  borderRadius: BorderRadius.circular(metrics.radiusField),
                  border: Border.all(color: colors.border),
                ),
                child: Center(
                  child: Text(
                    dt.day.toString(),
                    style: textTheme.titleMedium?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SizedBox(width: metrics.spaceMd),

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
                          SizedBox(width: metrics.spaceXs),
                          Container(
                            key: const ValueKey('mv_slot_anchor_badge'),
                            padding: EdgeInsets.symmetric(
                              horizontal: metrics.spaceXs,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(
                                RitmoRadius.pill,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.lock_rounded,
                                  key: const ValueKey('mv_slot_lock_icon'),
                                  size: metrics.iconSm,
                                  color: colors.accent,
                                ),
                                SizedBox(width: metrics.spaceXs),
                                Text(
                                  l10n?.mv_slot_anchor_badge_label ?? 'Fixed',
                                  style: textTheme.labelSmall?.copyWith(
                                    color: colors.accent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (slot.isRest) ...[
                          SizedBox(width: metrics.spaceSm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.surfaceSunken,
                              borderRadius: BorderRadius.circular(
                                RitmoRadius.pill,
                              ),
                            ),
                            child: Text(
                              l10n?.mv_slot_rest_badge_label ?? 'Rest',
                              style: textTheme.labelSmall?.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: metrics.spaceXs),
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
                      SizedBox(height: metrics.spaceXs),
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
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: metrics.spaceSm,
                  vertical: metrics.spaceXs,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(RitmoRadius.pill),
                ),
                child: Text(
                  slot.status.titleFa,
                  style: textTheme.labelSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
