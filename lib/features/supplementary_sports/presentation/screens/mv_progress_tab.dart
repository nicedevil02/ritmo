import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/engines.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import '../components/components.dart';

/// Tab 3: "پیشرفت" (Section 5.3).
/// Displays streak stats, body map, personal records, and honest trends.
class MvProgressTab extends StatelessWidget {
  final int? continuousActiveWeeks;
  final int totalSessionsCount;
  final double totalMetMinutes;
  final List<MvPersonalRecord> personalRecords;
  final MvBodyMapDistribution bodyMapDistribution;
  final bool hasEnoughDataForTrends;

  const MvProgressTab({
    super.key,
    required this.continuousActiveWeeks,
    required this.totalSessionsCount,
    required this.totalMetMinutes,
    required this.personalRecords,
    required this.bodyMapDistribution,
    this.hasEnoughDataForTrends = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.ritmoColors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: EdgeInsets.all(metrics.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Continuous Active Weeks Hero / Insufficient Data State
          if (continuousActiveWeeks == null)
            const MvInsufficientData(
              title: 'هفته‌های فعال پیوسته',
              requirementDescription:
                  'برای محاسبهٔ روند پیوستگی، حداقل به ثبت جلسات در هفته نیاز است.',
            )
          else
            Container(
              padding: EdgeInsets.all(metrics.spaceLg),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors.primary, colors.primary.withValues(alpha: 0.8)],
                ),
                borderRadius: BorderRadius.circular(metrics.radiusHero),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(metrics.spaceMd),
                    decoration: BoxDecoration(
                      color: colors.onPrimary.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.local_fire_department_rounded,
                      color: colors.onPrimary,
                      size: metrics.iconLg,
                    ),
                  ),
                  SizedBox(width: metrics.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'هفته‌های فعال پیوسته',
                          style: textTheme.labelMedium?.copyWith(
                            color: colors.onPrimary.withValues(alpha: 0.9),
                          ),
                        ),
                        SizedBox(height: metrics.spaceXs),
                        Text(
                          '$continuousActiveWeeks هفته',
                          style: textTheme.headlineMedium?.copyWith(
                            color: colors.onPrimary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(height: metrics.spaceLg),

          // 2. Stats Grid
          if (totalSessionsCount == 0)
            const MvInsufficientData(
              title: 'آمار کل فعالیت',
              requirementDescription:
                  'هنوز فعالیتی ثبت نشده است. با ثبت اولین جلسه آمار نمایش داده می‌شود.',
            )
          else
            Row(
              children: [
                Expanded(
                  child: MvStatTile(
                    title: 'کل جلسات',
                    value: totalSessionsCount.toString(),
                    unit: 'جلسه',
                    icon: Icons.fitness_center_rounded,
                  ),
                ),
                SizedBox(width: metrics.spaceMd),
                Expanded(
                  child: MvStatTile(
                    title: 'کل فعالیت',
                    value: (totalMetMinutes / 60).toStringAsFixed(1),
                    unit: 'ساعت',
                    icon: Icons.timer_rounded,
                  ),
                ),
              ],
            ),
          SizedBox(height: metrics.spaceLg),

          // 3. Body Map
          if (bodyMapDistribution.muscleSessionCounts.values.every((c) => c == 0))
            const MvInsufficientData(
              title: 'نقشهٔ عضلانی این هفته',
              requirementDescription:
                  'برای نمایش توزیع عضلانی، حداقل به ثبت یک جلسهٔ تمرینی نیاز است.',
            )
          else
            MvBodyMap(distribution: bodyMapDistribution),
          SizedBox(height: metrics.spaceLg),

          // 4. Personal Records (PR) Section
          Text(
            'رکوردهای شخصی (PR)',
            style: textTheme.titleSmall?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: metrics.spaceSm),

          if (personalRecords.isEmpty)
            const MvInsufficientData(
              title: 'رکوردهای شخصی',
              requirementDescription:
                  'با انجام اولین جلسهٔ تمرینی، رکوردهایت اینجا ثبت می‌شود.',
            )
          else
            ...personalRecords.map((pr) {
              return Container(
                margin: EdgeInsets.only(bottom: metrics.spaceSm),
                padding: EdgeInsets.all(metrics.spaceMd),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(metrics.radiusCard),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.emoji_events_rounded,
                      color: colors.warning,
                      size: metrics.iconMd,
                    ),
                    SizedBox(width: metrics.spaceMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pr.isExercisePr ? pr.exerciseId : pr.kind,
                            style: textTheme.bodyMedium?.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            pr.prType.titleFa,
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      pr.formattedValue,
                      style: textTheme.titleMedium?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              );
            }),
          SizedBox(height: metrics.spaceLg),

          // 5. Honest Trends or Insufficient Data (Rule 7)
          if (!hasEnoughDataForTrends)
            const MvInsufficientData(
              title: 'تحلیل جامع روند هفتگی',
              requirementDescription:
                  'پس از ثبت حداقل ۴ هفته تمرین، نمودار پیشرفت و حجم نمایش داده می‌شود.',
            ),
          SizedBox(height: metrics.spaceXxl),
        ],
      ),
    );
  }
}
