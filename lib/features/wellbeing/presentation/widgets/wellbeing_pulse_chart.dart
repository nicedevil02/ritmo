import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/util/ritmo_date.dart';
import 'package:ritmo/core/util/ritmo_number.dart';
import 'package:ritmo/features/wellbeing/presentation/widgets/wellbeing_day_sheet.dart';

class WellbeingPulseDayData {
  const WellbeingPulseDayData({
    required this.dateStr,
    this.sleepHours,
    this.energyLevel,
    this.moodScore,
    this.hasReflection = false,
  });

  final String dateStr;
  final double? sleepHours; // e.g. 7.5
  final double? energyLevel; // 1..3
  final double? moodScore; // 1..5
  final bool hasReflection;
}

class WellbeingPulseChart extends StatelessWidget {
  const WellbeingPulseChart({super.key, required this.days, this.onDayTap});

  final List<WellbeingPulseDayData> days;
  final ValueChanged<WellbeingPulseDayData>? onDayTap;

  // Bars are never rendered narrower than this, so large day ranges (e.g. a
  // 90-day view) scroll horizontally instead of collapsing to a negative or
  // near-zero width, which previously crashed the layout.
  static const double _minBarWidth = 14.0;
  static const double _maxBarWidth = 40.0;
  static const double _barGap = 4.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(RitmoSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                days.length <= 7
                    ? 'نبض هفته'
                    : (days.length <= 14
                          ? 'نبض دو هفته'
                          : (days.length <= 30
                                ? 'نبض یک ماه'
                                : 'نبض ${RitmoNumber.faInt(days.length)} روز اخیر')),
                style: RitmoTextStyles.cardTitle(colors.textPrimary),
              ),
              const Spacer(),
              _buildLegendPill(context, 'خواب', colors.sleepAccent),
              const SizedBox(width: 8),
              _buildLegendPill(context, 'انرژی', colors.energyAccent),
              const SizedBox(width: 8),
              _buildLegendPill(context, 'حال', colors.reflectionAccent),
            ],
          ),
          const SizedBox(height: RitmoSpacing.lg),
          SizedBox(
            height: 160,
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                if (days.isEmpty) return const SizedBox.shrink();

                // Width each bar would get if all days were squeezed into the
                // available width with a fixed gap between them.
                final fitWidth =
                    (constraints.maxWidth - (days.length - 1) * _barGap) /
                    days.length;
                final barWidth = fitWidth.clamp(_minBarWidth, _maxBarWidth);
                final needsScroll = fitWidth < _minBarWidth;

                final bars = <Widget>[];
                for (var i = 0; i < days.length; i++) {
                  if (i > 0) bars.add(const SizedBox(width: _barGap));
                  bars.add(_buildDayBar(context, days[i], barWidth));
                }

                final row = Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: needsScroll
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.spaceBetween,
                  children: bars,
                );

                if (!needsScroll) return row;

                // Too many days to fit at the minimum readable bar width:
                // scroll horizontally instead of shrinking bars further (which
                // previously produced a negative width and crashed).
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: row,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendPill(BuildContext context, String label, Color color) {
    final colors = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: RitmoTextStyles.caption(colors.textSecondary)),
      ],
    );
  }

  Widget _buildDayBar(
    BuildContext context,
    WellbeingPulseDayData d,
    double width,
  ) {
    final colors = context.colors;

    // Sleep bar height ratio (max 12h = 1.0)
    final sleepRatio = d.sleepHours == null
        ? 0.0
        : (d.sleepHours! / 12.0).clamp(0.0, 1.0);

    // Energy / Mood position ratio
    final energyRatio = d.energyLevel != null
        ? ((d.energyLevel! - 1.0) / 2.0).clamp(0.0, 1.0)
        : (d.moodScore != null
              ? ((d.moodScore! - 1.0) / 4.0).clamp(0.0, 1.0)
              : null);

    return GestureDetector(
      onTap: () {
        if (onDayTap != null) {
          onDayTap!(d);
        } else {
          _showDayDetailDialog(context, d);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Chart area
            Expanded(
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  // Sleep background bar
                  if (d.sleepHours != null)
                    FractionallySizedBox(
                      heightFactor: math.max(0.08, sleepRatio),
                      child: Container(
                        width: width * 0.7,
                        decoration: BoxDecoration(
                          color: colors.sleepAccent.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),

                  // Energy/Mood dot
                  if (energyRatio != null)
                    Positioned(
                      bottom: energyRatio * 110.0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: d.moodScore != null
                              ? (d.moodScore! >= 4
                                    ? colors.success
                                    : (d.moodScore! <= 2
                                          ? colors.error
                                          : colors.cautionAccent))
                              : colors.energyAccent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: colors.energyAccent.withValues(alpha: 0.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // Reflection tick under axis
            if (d.hasReflection)
              Icon(Icons.check, size: 10, color: colors.reflectionAccent)
            else
              const SizedBox(height: 10),
            const SizedBox(height: 2),
            // Day label
            Text(
              _dayLabel(d.dateStr),
              style: RitmoTextStyles.caption(
                colors.textSecondary,
              ).copyWith(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  String _dayLabel(String dateStr) {
    final dt = RitmoDate.tryParseDayKey(dateStr);
    if (dt == null) return '';
    return RitmoNumber.fa(dt.day.toString());
  }

  void _showDayDetailDialog(BuildContext context, WellbeingPulseDayData d) {
    WellbeingDaySheet.show(context: context, day: d);
  }
}
