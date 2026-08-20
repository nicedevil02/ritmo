import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/application/movement_progress_service.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// کارت نمودار روند فعالیت (TrendChartCard)
/// ارتفاع استاندارد kChartCardHeight، جملهٔ تفسیر اجباری، پیام دادهٔ کم، و جدول دسترس‌پذیری.
class TrendChartCard extends StatelessWidget {
  const TrendChartCard({super.key, required this.trendData});

  final MovementTrendData trendData;

  void _showTableDialog(BuildContext context) {
    final colors = context.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Material(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(RitmoRadius.sheet),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(RitmoSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'جدول داده‌های روند فعالیت',
                  style: RitmoTextStyles.cardTitle(colors.textPrimary),
                ),
                const SizedBox(height: RitmoSpacing.md),
                Table(
                  border: TableBorder.all(color: colors.border),
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: colors.surfaceSunken),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            'بازه',
                            style: RitmoTextStyles.label(colors.textPrimary),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            'تعداد جلسات',
                            style: RitmoTextStyles.label(colors.textPrimary),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            'دقیقه فعالیت',
                            style: RitmoTextStyles.label(colors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                    ...trendData.points.map((pt) {
                      return TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              pt.label,
                              style: RitmoTextStyles.caption(
                                colors.textSecondary,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              toPersianDigits(pt.sessionCount),
                              style: RitmoTextStyles.caption(
                                colors.textPrimary,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              toPersianDigits(pt.activeMinutes),
                              style: RitmoTextStyles.caption(
                                colors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    final semanticText = trendData.hasEnoughData
        ? 'نمودار روند فعالیت: ${trendData.interpretationSentence}. شامل ${trendData.points.length} بازه زمانی.'
        : MovementStrings.trendNeedMoreData;

    return Semantics(
      label: semanticText,
      child: Container(
        width: double.infinity,
        height: MovementLayout.kChartCardHeight,
        padding: const EdgeInsets.all(RitmoSpacing.lg),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(RitmoRadius.card),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // هدر و دکمهٔ نمایش جدول
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  MovementStrings.trendChartTitle,
                  style: RitmoTextStyles.sectionHeadline(colors.textPrimary),
                ),
                if (trendData.hasEnoughData)
                  TextButton.icon(
                    onPressed: () => _showTableDialog(context),
                    icon: const Icon(Icons.table_chart_outlined, size: 16),
                    label: Text(
                      MovementStrings.trendTableView,
                      style: RitmoTextStyles.caption(sportsColor),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(48, 36),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: RitmoSpacing.xs),

            // جملهٔ تفسیر اجباری
            Text(
              trendData.interpretationSentence,
              style: RitmoTextStyles.body(colors.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),

            // محتوای نمودار یا پیام دادهٔ ناکافی
            if (!trendData.hasEnoughData)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: RitmoSpacing.sm,
                  ),
                  child: Text(
                    MovementStrings.trendNeedMoreData,
                    style: RitmoTextStyles.caption(colors.textTertiary),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              _buildBarChart(sportsColor, colors),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart(Color sportsColor, RitmoColors colors) {
    final maxSessions = trendData.points.fold<int>(
      1,
      (max, pt) => pt.sessionCount > max ? pt.sessionCount : max,
    );

    return SizedBox(
      height: 90,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: trendData.points.map((pt) {
          final heightRatio = (pt.sessionCount / maxSessions).clamp(0.1, 1.0);

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    toPersianDigits(pt.sessionCount),
                    style: RitmoTextStyles.caption(
                      sportsColor,
                    ).copyWith(fontSize: 10, height: 1.2),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    height: 42 * heightRatio,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: sportsColor.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    pt.label,
                    style: RitmoTextStyles.caption(
                      colors.textTertiary,
                    ).copyWith(fontSize: 9, height: 1.2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
