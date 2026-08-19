import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/application/movement_progress_service.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// کارت توزیع کار گروه‌های عضلانی (BodyMapCard)
/// ارتفاع استاندارد kBodyMapHeight، طراحی خنثی و غیرجنسیتی همراه با معادل متنی اجباری.
class BodyMapCard extends StatelessWidget {
  const BodyMapCard({super.key, required this.items});

  final List<MovementMuscleWorkloadItem> items;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final semanticSummary =
        'توزیع کار عضلانی: ${items.map((i) => '${i.muscleGroup}: ${toPersianDigits(i.setsCount)} ست (${toPersianDigits(i.percentage)}٪)').join('، ')}';

    return Semantics(
      label: semanticSummary,
      child: Container(
        width: double.infinity,
        height: MovementLayout.kBodyMapHeight,
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
              MovementStrings.bodyMapTitle,
              style: RitmoTextStyles.sectionHeadline(colors.textPrimary),
            ),
            const SizedBox(height: RitmoSpacing.xs),
            Text(
              'میزان حجم تمرین انجام‌شده روی هر گروه عضلانی:',
              style: RitmoTextStyles.caption(colors.textSecondary),
            ),
            const SizedBox(height: RitmoSpacing.md),

            // فهرست معادل متنی اجباری با نوارهای بصری خنثی
            Expanded(
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: RitmoSpacing.sm),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Row(
                    children: [
                      SizedBox(
                        width: 90,
                        child: Text(
                          item.muscleGroup,
                          style: RitmoTextStyles.caption(colors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: RitmoSpacing.sm),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(RitmoRadius.pill),
                          child: LinearProgressIndicator(
                            value: (item.percentage / 100).clamp(0.05, 1.0),
                            minHeight: 8,
                            backgroundColor: colors.surfaceSunken,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              sportsColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: RitmoSpacing.sm),
                      SizedBox(
                        width: 80,
                        child: Text(
                          '${toPersianDigits(item.setsCount)} ست (${toPersianDigits(item.percentage)}٪)',
                          style: RitmoTextStyles.caption(
                            colors.textSecondary,
                          ).copyWith(fontSize: 10),
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
