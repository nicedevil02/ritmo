import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/application/movement_progress_service.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// کارت پیشرفت تمرینات قدرتی (StrengthProgressCard)
/// نمایش حجم تمرین، وضعیت دِلود و نرخ اتمام جلسات.
class StrengthProgressCard extends StatelessWidget {
  const StrengthProgressCard({super.key, required this.strengthData});

  final MovementStrengthProgressData strengthData;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    final completionPct = (strengthData.completionRate * 100).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(RitmoSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                MovementStrings.strengthProgressTitle,
                style: RitmoTextStyles.sectionHeadline(colors.textPrimary),
              ),
              if (strengthData.isDeloadActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(RitmoRadius.pill),
                  ),
                  child: Text(
                    MovementStrings.strengthHubDeloadWeek,
                    style: RitmoTextStyles.caption(
                      colors.accent,
                    ).copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: RitmoSpacing.sm),

          // نرخ تکمیل جلسات دوره
          Row(
            children: [
              Text(
                'نرخ تکمیل دوره:',
                style: RitmoTextStyles.caption(colors.textSecondary),
              ),
              const SizedBox(width: RitmoSpacing.xs),
              Text(
                '${toPersianDigits(completionPct)}٪',
                style: RitmoTextStyles.caption(
                  sportsColor,
                ).copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: RitmoSpacing.md),

          // حجم ست‌های انجام شده
          Container(
            padding: const EdgeInsets.all(RitmoSpacing.md),
            decoration: BoxDecoration(
              color: colors.surfaceSunken,
              borderRadius: BorderRadius.circular(RitmoRadius.field),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      'تعداد ست‌های ثبت‌شده',
                      style: RitmoTextStyles.caption(colors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      toPersianDigits(strengthData.weeklyVolumes.length),
                      style: RitmoTextStyles.cardTitle(colors.textPrimary),
                    ),
                  ],
                ),
                Container(width: 1, height: 32, color: colors.divider),
                Column(
                  children: [
                    Text(
                      'وضعیت پیشرفت',
                      style: RitmoTextStyles.caption(colors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      strengthData.isDeloadActive
                          ? 'هفتهٔ ریکاوری فعال'
                          : 'بارگذاری تدریجی',
                      style: RitmoTextStyles.caption(
                        sportsColor,
                      ).copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
