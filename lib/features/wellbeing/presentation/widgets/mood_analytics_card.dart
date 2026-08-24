import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/analytics/mood_engine.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/util/ritmo_number.dart';
import 'package:ritmo/features/energy/models/energy_mood_models.dart';

/// کارت‌های تحلیلی جامع «حال»، روند چندروزه، همبستگی و تفکیک بخش‌های روز
class MoodAnalyticsCard extends StatelessWidget {
  const MoodAnalyticsCard({
    super.key,
    required this.output,
  });

  final MoodEngineOutput? output;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final out = output;
    final dominant = out?.dominantMood;
    final daypart = out?.moodByDaypart ?? const {};
    final correlation = out?.correlationInsight;
    final trend = out?.moodTrend ?? const [];

    final hasData = dominant != null || trend.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ─── کارت اصلی تحلیل روند حال و همبستگی ───
        Container(
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xffEC4899).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          CupertinoIcons.heart_fill,
                          color: Color(0xffEC4899),
                          size: 17,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'تحلیل حالِ این بازه',
                        style: RitmoTextStyles.cardTitle(colors.textPrimary),
                      ),
                    ],
                  ),
                  if (dominant != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xffEC4899).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xffEC4899).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        'حال غالب: ${dominant.label}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xffEC4899),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: RitmoSpacing.md),
              if (!hasData) ...[
                Container(
                  padding: const EdgeInsets.all(RitmoSpacing.md),
                  decoration: BoxDecoration(
                    color: colors.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colors.border.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(CupertinoIcons.chart_bar_alt_fill, size: 16, color: colors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'با ثبت روزانهٔ احوال روحی، نمودار میله‌ای روند و مقایسه بخش‌های روز در اینجا شکل می‌گیرد.',
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.textSecondary,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Dominant mood summary banner
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xffEC4899).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xffEC4899).withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        _resolveVectorMoodIcon(dominant?.defaultValence ?? 3),
                        size: 26,
                        color: const Color(0xffEC4899),
                      ),
                    ),
                    const SizedBox(width: RitmoSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'حال روحی: ${dominant?.label ?? "متعادل"}',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'میانگین شاخص خلق در این بازه',
                            style: RitmoTextStyles.caption(colors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: RitmoSpacing.md),

                // Mini Trend Bars
                if (trend.isNotEmpty) ...[
                  _buildTrendBars(trend, colors),
                  const SizedBox(height: RitmoSpacing.md),
                ],

                // Correlation Insight
                if (correlation != null && correlation.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(RitmoSpacing.md),
                    decoration: BoxDecoration(
                      color: colors.surfaceSunken,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.border.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(CupertinoIcons.lightbulb_fill, size: 16, color: colors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            correlation,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: colors.textPrimary,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: RitmoSpacing.lg),

        // ─── کارت حال در بخش‌های روز ───
        if (hasData)
          Container(
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
                  'حال در بخش‌های روز',
                  style: RitmoTextStyles.cardTitle(colors.textPrimary),
                ),
                const SizedBox(height: RitmoSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _buildDaypartBox(
                        context,
                        title: 'صبح',
                        icon: CupertinoIcons.sunrise_fill,
                        mood: daypart['morning'],
                        accentColor: const Color(0xffF59E0B),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildDaypartBox(
                        context,
                        title: 'ظهر',
                        icon: CupertinoIcons.sun_max_fill,
                        mood: daypart['afternoon'],
                        accentColor: const Color(0xff10B981),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildDaypartBox(
                        context,
                        title: 'عصر',
                        icon: CupertinoIcons.sunset_fill,
                        mood: daypart['evening'],
                        accentColor: const Color(0xffEC4899),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildDaypartBox(
                        context,
                        title: 'شب',
                        icon: CupertinoIcons.moon_stars_fill,
                        mood: daypart['night'],
                        accentColor: const Color(0xff8B5CF6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTrendBars(List<double> trend, RitmoColors colors) {
    // Show up to last 14 days of trends
    final visible = trend.length > 14 ? trend.sublist(trend.length - 14) : trend;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'نوسان خلق در روزهای اخیر',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
              Text(
                '${RitmoNumber.faInt(visible.length)} روز ثبت‌شده',
                style: TextStyle(fontSize: 10, color: colors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 38,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: visible.map((val) {
                // Valence is 1..5, normalize to height factor 0.2..1.0
                final hFactor = ((val - 1.0) / 4.0).clamp(0.2, 1.0);
                final barColor = val >= 4.0
                    ? const Color(0xff10B981)
                    : (val >= 3.0 ? const Color(0xffEC4899) : const Color(0xffF59E0B));

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Container(
                      height: 38 * hFactor,
                      decoration: BoxDecoration(
                        color: barColor.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaypartBox(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Mood? mood,
    required Color accentColor,
  }) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(RitmoSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: mood != null
              ? accentColor.withValues(alpha: 0.3)
              : colors.border.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: accentColor),
              const SizedBox(width: 5),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (mood != null) ...[
            Icon(
              _resolveVectorMoodIcon(mood.defaultValence),
              size: 20,
              color: accentColor,
            ),
            const SizedBox(height: 2),
            Text(
              mood.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
          ] else ...[
            Text(
              '—',
              style: TextStyle(fontSize: 12, color: colors.textSecondary.withValues(alpha: 0.5)),
            ),
          ],
        ],
      ),
    );
  }

  IconData _resolveVectorMoodIcon(int valence) {
    if (valence <= 1) return Icons.sentiment_very_dissatisfied_rounded;
    if (valence == 2) return Icons.sentiment_dissatisfied_rounded;
    if (valence == 3) return Icons.sentiment_neutral_rounded;
    if (valence == 4) return Icons.sentiment_satisfied_rounded;
    return Icons.sentiment_very_satisfied_rounded;
  }
}

