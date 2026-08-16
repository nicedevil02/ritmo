import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/agenda_renderer_registry.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/application/movement_log_service.dart';
import 'package:ritmo/features/movement/application/movement_occurrence_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_occurrence.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';
import 'package:ritmo/features/movement/presentation/movement_routes.dart';

/// رندرر اختصاصی ردیف‌های ورزشی در اجندا و تقویم (SportAgendaRenderer)
/// امکان مشاهدهٔ جزئیات و تکمیل مستقیم بدون دستکاری کدهای تقویم
class SportAgendaRenderer extends AgendaTileRenderer {
  const SportAgendaRenderer({
    this.occurrenceService,
    this.logService,
  });

  final MovementOccurrenceService? occurrenceService;
  final MovementLogService? logService;

  IconData _iconForFamily(String? family) {
    return switch (family) {
      'running' => Icons.directions_run_rounded,
      'cycling' => Icons.directions_bike_rounded,
      'strength' => Icons.fitness_center_rounded,
      'swimming' => Icons.pool_rounded,
      'yoga_mobility' => Icons.self_improvement_rounded,
      'hiking' => Icons.hiking_rounded,
      _ => Icons.directions_walk_rounded,
    };
  }

  @override
  Widget build(BuildContext context, AgendaItem item, {required VoidCallback onChanged}) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;
    final isDone = item.completion == AgendaCompletion.done;
    final isSkipped = item.completion == AgendaCompletion.skipped;
    final isPartial = item.completion == AgendaCompletion.partial;

    final family = item.meta['family'] as String?;
    final occService = occurrenceService ?? MovementOccurrenceService();
    final lgService = logService ?? MovementLogService();

    final timeOfDay = item.timeOfDay;
    final timeText = timeOfDay != null && timeOfDay.isNotEmpty
        ? toPersianDigits(timeOfDay)
        : null;

    final duration = item.durationMinutes;
    final durationText = duration != null && duration > 0
        ? '${toPersianDigits(duration)} دقیقه'
        : null;

    return Semantics(
      label: '${item.title}، ${isDone ? "تکمیل شده" : "برنامه‌ریزی شده"}',
      child: Container(
        margin: const EdgeInsets.only(bottom: RitmoSpacing.xs),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(RitmoRadius.card),
          border: Border.all(
            color: isDone
                ? colors.border.withValues(alpha: 0.5)
                : sportsColor.withValues(alpha: 0.25),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(RitmoRadius.card),
          onTap: () {
            // دیپ‌لینک به جزئیات جلسه یا مرکز حرکت
            Navigator.of(context).pushNamed(
              MovementRoutes.occurrence,
              arguments: {
                'occurrenceId': item.sourceId,
                'dateIso': item.dateStr,
              },
            ).then((_) => onChanged());
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: RitmoSpacing.md,
              vertical: RitmoSpacing.sm,
            ),
            child: Row(
              children: [
                // آیکون خانواده ورزشی
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: sportsColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _iconForFamily(family),
                    size: 18,
                    color: sportsColor,
                  ),
                ),
                const SizedBox(width: RitmoSpacing.sm),

                // عنوان و زیرعنوان
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.title,
                        style: RitmoTextStyles.cardTitle(colors.textPrimary).copyWith(
                          decoration: isDone || isSkipped ? TextDecoration.lineThrough : null,
                          color: isDone ? colors.textTertiary : colors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.subtitle != null && item.subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.subtitle!,
                          style: RitmoTextStyles.caption(colors.textTertiary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                // ساعت و مدت زمان
                if (timeText != null || durationText != null) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (timeText != null)
                        Text(
                          timeText,
                          style: RitmoTextStyles.badge(colors.textSecondary),
                        ),
                      if (durationText != null)
                        Text(
                          durationText,
                          style: RitmoTextStyles.caption(colors.textTertiary).copyWith(fontSize: 10),
                        ),
                    ],
                  ),
                  const SizedBox(width: RitmoSpacing.sm),
                ],

                // دکمهٔ تکمیل از داخل تقویم / اجندا (Touch Target >= 48x48)
                Semantics(
                  label: isDone ? 'لغو تکمیل' : MovementStrings.agendaSportActionComplete,
                  button: true,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton(
                      icon: Icon(
                        isDone
                            ? CupertinoIcons.checkmark_circle_fill
                            : (isPartial
                                ? Icons.timelapse_rounded
                                : CupertinoIcons.circle),
                        color: isDone
                            ? colors.success
                            : (isPartial ? colors.warning : colors.textTertiary),
                        size: 24,
                      ),
                      onPressed: () async {
                        final newStatus = isDone
                            ? MovementOccurrenceStatus.planned
                            : MovementOccurrenceStatus.completed;

                        await occService.updateOccurrenceStatus(item.sourceId, newStatus);
                        if (!isDone) {
                          try {
                            final occ = await occService.getOccurrenceById(item.sourceId);
                            if (occ != null) {
                              await lgService.logRetroWorkout(
                                activityKindId: occ.activityKindId,
                                dateIso: occ.dateIso,
                                startTime: occ.startTime,
                                durationSec: ((occ.goalType == 'duration' ? occ.goalValue?.toInt() : 30) ?? 30) * 60,
                                matchedOccurrenceId: occ.id,
                              );
                            }
                          } catch (_) {}
                        }
                        onChanged();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
