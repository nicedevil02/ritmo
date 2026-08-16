import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/application/movement_progress_service.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// کارت توزیع خانواده‌های ورزشی (DistributionCard)
/// نمایش درصدها حتماً همراه با مقدار مطلق (تعداد جلسه).
class DistributionCard extends StatelessWidget {
  const DistributionCard({
    super.key,
    required this.items,
  });

  final List<MovementDistributionItem> items;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

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
          Text(
            MovementStrings.distributionTitle,
            style: RitmoTextStyles.sectionHeadline(colors.textPrimary),
          ),
          const SizedBox(height: RitmoSpacing.sm),
          Text(
            'تنوع فعالیت‌های انجام‌شده در این دوره:',
            style: RitmoTextStyles.caption(colors.textSecondary),
          ),
          const SizedBox(height: RitmoSpacing.md),

          ...items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: RitmoSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(item.nameFa, style: RitmoTextStyles.body(colors.textPrimary)),
                      Text(
                        '${toPersianDigits(item.count)} جلسه (${toPersianDigits(item.percentage)}٪)',
                        style: RitmoTextStyles.caption(sportsColor).copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(RitmoRadius.pill),
                    child: LinearProgressIndicator(
                      value: (item.percentage / 100).clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: colors.surfaceSunken,
                      valueColor: AlwaysStoppedAnimation<Color>(sportsColor),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
