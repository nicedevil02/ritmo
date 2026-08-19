import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/domain/models/movement_personal_record.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';
import 'package:shamsi_date/shamsi_date.dart';

/// فهرست رکوردهای شخصی واقعی (PrList)
/// فقط رکوردهای واقعی ثبت‌شده؛ هر ردیف = نام، مقدار + واحد، تاریخ جلالی، نوع رکورد.
class PrList extends StatelessWidget {
  const PrList({super.key, required this.records});

  final List<MovementPersonalRecord> records;

  String _formatJalali(DateTime dt) {
    try {
      final j = Jalali.fromDateTime(dt);
      return '${toPersianDigits(j.day)} ${j.formatter.mN} ${toPersianDigits(j.year)}';
    } catch (_) {
      return dt.toIso8601String().substring(0, 10);
    }
  }

  String _getRecordTypeLabel(String type) {
    switch (type) {
      case 'max_weight':
        return 'بیشترین وزنه';
      case 'max_reps':
        return 'بیشترین تکرار';
      case 'max_duration':
        return 'طولانی‌ترین مدت';
      case 'max_distance':
        return 'بیشترین مسافت';
      default:
        return 'رکورد شخصی';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

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
            children: [
              Icon(Icons.emoji_events_outlined, color: sportsColor, size: 22),
              const SizedBox(width: RitmoSpacing.xs),
              Text(
                MovementStrings.prListTitle,
                style: RitmoTextStyles.sectionHeadline(colors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: RitmoSpacing.md),

          if (records.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: RitmoSpacing.md),
              child: Center(
                child: Text(
                  MovementStrings.prNoRecords,
                  style: RitmoTextStyles.caption(colors.textTertiary),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: records.length,
              separatorBuilder: (context, index) =>
                  Divider(color: colors.border, height: RitmoSpacing.md),
              itemBuilder: (context, index) {
                final pr = records[index];
                final name =
                    pr.exerciseOrActivityNameFa ??
                    pr.exerciseId ??
                    pr.activityKindId ??
                    'تمرین';

                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                name,
                                style: RitmoTextStyles.label(
                                  colors.textPrimary,
                                ),
                              ),
                              if (pr.isEstimated) ...[
                                const SizedBox(width: RitmoSpacing.xs),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.accent.withValues(
                                      alpha: 0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      RitmoRadius.badge,
                                    ),
                                  ),
                                  child: Text(
                                    'تخمینی',
                                    style: RitmoTextStyles.caption(
                                      colors.accent,
                                    ).copyWith(fontSize: 10),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_getRecordTypeLabel(pr.recordType)} • ${_formatJalali(pr.achievedAt)}',
                            style: RitmoTextStyles.caption(colors.textTertiary),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${toPersianDigits(pr.value % 1 == 0 ? pr.value.toInt() : pr.value)} ${pr.unit}',
                      style: RitmoTextStyles.cardTitle(
                        sportsColor,
                      ).copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
