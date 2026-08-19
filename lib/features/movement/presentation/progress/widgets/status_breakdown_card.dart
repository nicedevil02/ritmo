import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/application/movement_progress_service.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// کارت تفکیک تحلیلی وضعیت جلسات (StatusBreakdownCard)
/// لحن خنثی و تحلیلی؛ عدم استفاده از رنگ قرمز برای جلسات ردشده.
class StatusBreakdownCard extends StatelessWidget {
  const StatusBreakdownCard({super.key, required this.data});

  final MovementStatusBreakdownData data;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    if (data.total == 0) {
      return const SizedBox.shrink();
    }

    final items = [
      {
        'label': 'کامل انجام‌شده',
        'count': data.completedCount,
        'color': sportsColor,
      },
      {
        'label': 'نیمه‌تمام',
        'count': data.partialCount,
        'color': colors.accent,
      },
      {
        'label': 'جابه‌جاشده',
        'count': data.movedCount,
        'color': colors.textSecondary,
      },
      {
        'label': 'ردشده یا استراحت',
        'count': data.skippedCount,
        'color':
            colors.textTertiary, // استفاده از رنگ خنثی و عدم استفاده از قرمز
      },
    ];

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
            MovementStrings.statusBreakdownTitle,
            style: RitmoTextStyles.sectionHeadline(colors.textPrimary),
          ),
          const SizedBox(height: RitmoSpacing.sm),
          Text(
            'تحلیل وضعیت اجرایی برنامه‌ریزی‌ها:',
            style: RitmoTextStyles.caption(colors.textSecondary),
          ),
          const SizedBox(height: RitmoSpacing.md),

          // نوار توزیع چندرنگ
          ClipRRect(
            borderRadius: BorderRadius.circular(RitmoRadius.pill),
            child: SizedBox(
              height: 10,
              child: Row(
                children: items.map((it) {
                  final count = it['count'] as int;
                  final color = it['color'] as Color;
                  if (count == 0) return const SizedBox.shrink();

                  return Expanded(
                    flex: count,
                    child: Container(color: color),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: RitmoSpacing.md),

          // راهنما و جزئیات
          Column(
            children: items.map((it) {
              final label = it['label'] as String;
              final count = it['count'] as int;
              final color = it['color'] as Color;
              final pct = data.total > 0 ? (count / data.total) * 100 : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: RitmoSpacing.xs),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: RitmoSpacing.sm),
                    Expanded(
                      child: Text(
                        label,
                        style: RitmoTextStyles.caption(colors.textPrimary),
                      ),
                    ),
                    Text(
                      '${toPersianDigits(count)} جلسه (${toPersianDigits(pct.toStringAsFixed(0))}٪)',
                      style: RitmoTextStyles.caption(colors.textSecondary),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
