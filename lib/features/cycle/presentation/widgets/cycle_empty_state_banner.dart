// C-43, C-44: CycleEmptyStateBanner
// F-39: Reasoned, transparent state banners explaining prediction status & empty states.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/cycle/models/cycle_forecast_models.dart';
import 'package:ritmo/l10n/app_localizations.dart';
import 'package:shamsi_date/shamsi_date.dart';

class CycleEmptyStateBanner extends StatelessWidget {
  const CycleEmptyStateBanner({
    super.key,
    required this.periodsCount,
    required this.isPregnancyMode,
    required this.calendarMonth,
    required this.forecast,
    this.onRecordFirstPeriod,
  });

  final int periodsCount;
  final bool isPregnancyMode;
  final Jalali calendarMonth;
  final List<PredictedCycle> forecast;
  final VoidCallback? onRecordFirstPeriod;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    // Determine which reasoned state banner to show, if any
    if (isPregnancyMode) {
      return _buildBanner(
        icon: CupertinoIcons.heart_fill,
        title: l10n?.cyclePregnancyBannerTitle ?? 'حالت بارداری فعال است',
        description:
            l10n?.cyclePregnancyBannerDesc ??
            'پیش‌بینی دوره‌ها و پنجره‌های باروری در این حالت متوقف شده است.',
        bannerColor: colors.primary,
        colors: colors,
        isDark: isDark,
      );
    }

    if (periodsCount == 0) {
      return _buildBanner(
        icon: CupertinoIcons.calendar_badge_plus,
        title: l10n?.cycleNoPeriodsBannerTitle ?? 'هنوز دوره‌ای ثبت نشده است',
        description:
            l10n?.cycleNoPeriodsBannerDesc ??
            'برای دریافت پیش‌بینی‌های دقیق و شناسایی الگوهای بدنی، اولین دوره خود را ثبت کنید.',
        bannerColor: colors.error,
        colors: colors,
        isDark: isDark,
        actionLabel: l10n?.cycleRecordFirstPeriod ?? 'ثبت اولین دوره',
        onAction: onRecordFirstPeriod,
      );
    }

    if (periodsCount < 3) {
      return _buildBanner(
        icon: CupertinoIcons.info_circle_fill,
        title: l10n?.cycleEarlyDataBannerTitle ?? 'پیش‌بینی با داده‌های اولیه',
        description:
            l10n?.cycleEarlyDataBannerDesc ??
            'پیش‌بینی فعلی بر اساس تنظیمات اولیه است. با ثبت حداقل ۳ چرخه، الگوی شخصی شما فعال می‌شود.',
        bannerColor: colors.textSecondary,
        colors: colors,
        isDark: isDark,
      );
    }

    // Check if viewed month is beyond forecast horizon
    if (forecast.isNotEmpty) {
      final lastForecastDay = forecast.last.predictedEnd;
      final monthStart = Jalali(
        calendarMonth.year,
        calendarMonth.month,
        1,
      ).toDateTime();
      if (monthStart.isAfter(lastForecastDay)) {
        return _buildBanner(
          icon: CupertinoIcons.sparkles,
          title: l10n?.cycleBeyondHorizonBannerTitle ?? 'فراتر از افق پیش‌بینی',
          description:
              l10n?.cycleBeyondHorizonBannerDesc ??
              'پیش‌بینی چرخه‌ها تا حداکثر ۲۴ ماه آینده بر اساس ثبات چرخه‌های قبلی محاسبه می‌شود.',
          bannerColor: colors.textSecondary,
          colors: colors,
          isDark: isDark,
        );
      }
    }

    return const SizedBox.shrink();
  }

  Widget _buildBanner({
    required IconData icon,
    required String title,
    required String description,
    required Color bannerColor,
    required RitmoColors colors,
    required bool isDark,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bannerColor.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: bannerColor.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: bannerColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: RitmoTextStyles.caption(
                    colors.textPrimary,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: RitmoTextStyles.badge(
                    colors.textSecondary,
                  ).copyWith(height: 1.35),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: onAction,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: bannerColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        actionLabel,
                        style: RitmoTextStyles.badge(
                          Colors.white,
                        ).copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
