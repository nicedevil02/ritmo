import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/domain/models/movement_workout_log.dart';
import 'package:ritmo/features/movement/presentation/common/metric_stat.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// بلوک نمایش متریک‌های واقعی جلسهٔ انجام‌شده بدون نمایش موارد فاقد داده
class SummaryMetricBlock extends StatelessWidget {
  const SummaryMetricBlock({
    super.key,
    required this.workoutLog,
  });

  final MovementWorkoutLog workoutLog;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final metrics = workoutLog.metricMap ?? {};
    final distanceKm = (metrics['distanceKm'] as num?)?.toDouble();
    final lapsCount = metrics['lapsCount'] as int?;
    final count = metrics['count'] as int?;
    final calories = (metrics['calories'] as num?)?.toInt();
    final isCaloriesEstimated = metrics['caloriesEstimated'] as bool? ?? true;

    final statItems = <Widget>[];

    // ۱. مدت زمان (همیشه معتبر)
    statItems.add(
      MetricStat(
        label: 'مدت زمان',
        value: toPersianDigits((workoutLog.durationSec / 60).round()),
        unit: 'دقیقه',
      ),
    );

    // ۲. مسافت در صورت وجود
    if (distanceKm != null && distanceKm > 0) {
      statItems.add(
        MetricStat(
          label: 'مسافت طی‌شده',
          value: toPersianDigits(distanceKm.toStringAsFixed(2)),
          unit: 'کیلومتر',
        ),
      );
    }

    // ۳. تعداد دور در صورت وجود
    if (lapsCount != null && lapsCount > 0) {
      statItems.add(
        MetricStat(
          label: 'تعداد دورها',
          value: toPersianDigits(lapsCount),
          unit: 'دور',
        ),
      );
    }

    // ۴. تعداد تکرار در صورت وجود
    if (count != null && count > 0) {
      statItems.add(
        MetricStat(
          label: 'تعداد تکرار',
          value: toPersianDigits(count),
          unit: 'حرکت',
        ),
      );
    }

    // ۵. کالری فقط در صورت وجود داده با برچسب تخمینی
    if (calories != null && calories > 0) {
      statItems.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            MetricStat(
              label: 'کالری مصرفی',
              value: toPersianDigits(calories),
              unit: 'کیلوکالری',
            ),
            if (isCaloriesEstimated) ...[
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.surfaceSunken,
                  borderRadius: BorderRadius.circular(RitmoRadius.badge),
                ),
                child: Text(
                  MovementStrings.summaryEstimated,
                  style: RitmoTextStyles.caption(colors.textTertiary).copyWith(fontSize: 10),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(RitmoSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        border: Border.all(color: colors.border),
      ),
      child: Wrap(
        spacing: RitmoSpacing.xl,
        runSpacing: RitmoSpacing.lg,
        children: statItems,
      ),
    );
  }
}
