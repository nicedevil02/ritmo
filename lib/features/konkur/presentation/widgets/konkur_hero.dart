import 'package:flutter/material.dart';
// Just in case, but let's build our own to be safe.
import 'package:ritmo/core/analytics/konkur_engine.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/konkur/presentation/widgets/konkur_formatters.dart';

class KonkurHero extends StatelessWidget {

  const KonkurHero({
    super.key,
    required this.data,
    required this.onSetDateTap,
  });
  final KonkurEngineOutput data;
  final VoidCallback onSetDateTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // A beautiful purple-to-violet gradient for the background
    final gradient = LinearGradient(
      colors: isDarkMode
          ? [
              const Color(0xFF7C3AED).withValues(alpha: 0.35),
              const Color(0xFF8B5CF6).withValues(alpha: 0.15),
            ]
          : [
              const Color(0xFF8B5CF6).withValues(alpha: 0.85),
              const Color(0xFFA78BFA).withValues(alpha: 0.95),
            ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final textColor = isDarkMode ? colors.textPrimary : Colors.white;
    final subtitleColor = isDarkMode ? colors.textSecondary : Colors.white.withValues(alpha: 0.85);
    final m = context.metrics;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: m.spaceLg, vertical: m.spaceSm),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(m.radiusHero),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: isDarkMode ? 0.15 : 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: colors.primary.withValues(alpha: isDarkMode ? 0.3 : 0.5),
          width: 1.5,
        ),
      ),
      child: RitmoGlassCardLight(
        color: Colors.transparent,
        border: Border.all(color: Colors.transparent),
        shadows: const [],
        child: Padding(
          padding: EdgeInsets.all(m.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'روزشمار کنکور',
                          style: RitmoTextStyles.caption(subtitleColor),
                        ),
                        SizedBox(height: m.spaceXs),
                        if (data.daysUntilExam >= 0) ...[
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  toPersianDigits(data.daysUntilExam),
                                  style: RitmoTextStyles.displayLarge(textColor).copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(width: m.spaceSm),
                                Text(
                                  'روز تا آزمون سرنوشت‌ساز',
                                  style: RitmoTextStyles.caption(textColor),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          GestureDetector(
                            onTap: onSetDateTap,
                            child: Row(
                              children: [
                                Text(
                                  'تاریخ کنکور را تعیین کنید',
                                  style: RitmoTextStyles.cardTitle(
                                    isDarkMode ? colors.accent : colors.warning,
                                  ).copyWith(
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                                SizedBox(width: m.spaceXs),
                                Icon(
                                  Icons.calendar_month,
                                  size: m.iconSm,
                                  color: isDarkMode ? colors.accent : colors.warning,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  _buildReadinessIndicator(data.overallReadiness, textColor, m),
                ],
              ),
              const Divider(color: Colors.white24, height: 24, thickness: 1),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMetricItem(
                    icon: Icons.timer,
                    label: 'مطالعه این هفته',
                    value: formatDuration(data.studyMinutesThisWeek),
                    textColor: textColor,
                    subtitleColor: subtitleColor,
                    m: m,
                  ),
                  _buildMetricItem(
                    icon: Icons.local_fire_department,
                    label: 'استریک استمرار',
                    value: data.studyStreakDays > 0
                        ? '${toPersianDigits(data.studyStreakDays)} روز 🔥'
                        : 'شروع کن 💪',
                    textColor: textColor,
                    subtitleColor: subtitleColor,
                    m: m,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadinessIndicator(double readiness, Color textColor, RitmoMetrics m) {
    final percent = (readiness * 100).toInt();
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 70 * m.densityFactor,
              height: 70 * m.densityFactor,
              child: CircularProgressIndicator(
                value: readiness,
                backgroundColor: Colors.white24,
                color: const Color(0xFF10B981),
                strokeWidth: 6 * m.densityFactor,
                strokeCap: StrokeCap.round,
              ),
            ),
            Text(
              '${toPersianDigits(percent)}٪',
              style: RitmoTextStyles.cardTitle(textColor).copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(height: m.spaceXs),
        Text(
          'آمادگی کل',
          style: RitmoTextStyles.caption(textColor.withValues(alpha: 0.9)),
        ),
      ],
    );
  }

  Widget _buildMetricItem({
    required IconData icon,
    required String label,
    required String value,
    required Color textColor,
    required Color subtitleColor,
    required RitmoMetrics m,
  }) {
    return Row(
      children: [
        Icon(icon, size: m.iconMd, color: textColor.withValues(alpha: 0.9)),
        SizedBox(width: m.spaceSm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: RitmoTextStyles.badge(subtitleColor),
            ),
            Text(
              value,
              style: RitmoTextStyles.badge(textColor).copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
