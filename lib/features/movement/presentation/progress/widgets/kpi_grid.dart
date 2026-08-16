import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/application/movement_progress_service.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// شبکهٔ نمایش KPIهای کلیدی (KpiGrid)
/// چیدمان Wrap دو ستونه، بدون اسکرول افقی مخفی.
class KpiGrid extends StatelessWidget {
  const KpiGrid({
    super.key,
    required this.kpiData,
  });

  final MovementKpiData kpiData;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    final cards = <Widget>[];

    // ۱. تعداد جلسات
    if (kpiData.sessionCount > 0) {
      cards.add(_buildKpiCard(
        title: MovementStrings.kpiSessions,
        value: toPersianDigits(kpiData.sessionCount),
        unit: 'جلسه',
        icon: Icons.event_available_rounded,
        colors: colors,
        sportsColor: sportsColor,
      ));
    }

    // ۲. دقیقه فعالیت
    if (kpiData.activeMinutes > 0) {
      cards.add(_buildKpiCard(
        title: MovementStrings.kpiActiveMinutes,
        value: toPersianDigits(kpiData.activeMinutes),
        unit: 'دقیقه',
        icon: Icons.timer_outlined,
        colors: colors,
        sportsColor: sportsColor,
      ));
    }

    // ۳. روزهای فعال
    if (kpiData.activeDaysCount > 0) {
      cards.add(_buildKpiCard(
        title: MovementStrings.kpiActiveDays,
        value: toPersianDigits(kpiData.activeDaysCount),
        unit: 'روز',
        icon: Icons.calendar_today_outlined,
        colors: colors,
        sportsColor: sportsColor,
      ));
    }

    // ۴. پایبندی به برنامه
    if (kpiData.adherenceRate > 0) {
      final pct = (kpiData.adherenceRate * 100).round();
      cards.add(_buildKpiCard(
        title: MovementStrings.kpiAdherence,
        value: toPersianDigits(pct),
        unit: '٪',
        icon: Icons.track_changes_rounded,
        colors: colors,
        sportsColor: sportsColor,
      ));
    }

    // ۵. مجموع حجم قدرتی
    if (kpiData.totalStrengthVolumeKg > 0) {
      cards.add(_buildKpiCard(
        title: MovementStrings.kpiStrengthVolume,
        value: toPersianDigits(kpiData.totalStrengthVolumeKg.round()),
        unit: 'کیلوگرم',
        icon: Icons.fitness_center_rounded,
        colors: colors,
        sportsColor: sportsColor,
      ));
    }

    // ۶. مسافت پیموده شده
    if (kpiData.totalDistanceKm > 0) {
      cards.add(_buildKpiCard(
        title: MovementStrings.kpiDistance,
        value: toPersianDigits(kpiData.totalDistanceKm.toStringAsFixed(1)),
        unit: 'کیلومتر',
        icon: Icons.directions_run_rounded,
        colors: colors,
        sportsColor: sportsColor,
      ));
    }

    if (cards.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - RitmoSpacing.md) / 2;
        return Wrap(
          spacing: RitmoSpacing.md,
          runSpacing: RitmoSpacing.md,
          children: cards.map((c) => SizedBox(width: itemWidth, child: c)).toList(),
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required RitmoColors colors,
    required Color sportsColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(RitmoSpacing.md),
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
              Icon(icon, size: 18, color: sportsColor),
              const SizedBox(width: RitmoSpacing.xs),
              Expanded(
                child: Text(
                  title,
                  style: RitmoTextStyles.caption(colors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: RitmoSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: RitmoTextStyles.sectionHeadline(colors.textPrimary).copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: RitmoTextStyles.caption(colors.textTertiary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
