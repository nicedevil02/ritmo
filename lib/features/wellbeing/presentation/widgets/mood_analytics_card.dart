import 'package:flutter/material.dart';
import 'package:ritmo/core/analytics/mood_engine.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/energy/models/energy_mood_models.dart';

/// کارت‌های تحلیلی جامع «حال»، همبستگی و تفکیک بخش‌های روز
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

    final hasData = dominant != null || out?.moodTrend.isNotEmpty == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // کارت اصلی حال و همبستگی
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
                      Icon(
                        Icons.sentiment_satisfied_alt,
                        color: colors.reflectionAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
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
                        color: colors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'حال غالب: ${dominant.label}',
                        style: RitmoTextStyles.caption(colors.primary),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: RitmoSpacing.md),
              if (!hasData) ...[
                Text(
                  'با ثبت روزانهٔ حال روحی، نمودار روند و تحلیل بخش‌های روز در اینجا شکل می‌گیرد.',
                  style: RitmoTextStyles.caption(colors.textSecondary),
                ),
              ] else ...[
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.primaryContainer.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        dominant?.emoji ?? '🙂',
                        style: RitmoTextStyles.cardTitle(colors.textPrimary).copyWith(fontSize: 28),
                      ),
                    ),
                    const SizedBox(width: RitmoSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'حال روحی: ${dominant?.label ?? "متعادل"}',
                            style: RitmoTextStyles.titleMedium(colors.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'بر اساس ثبت‌های روحی شما در این بازه',
                            style: RitmoTextStyles.caption(colors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (correlation != null && correlation.isNotEmpty) ...[
                  const SizedBox(height: RitmoSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(RitmoSpacing.md),
                    decoration: BoxDecoration(
                      color: colors.surfaceElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.insights, size: 16, color: colors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            correlation,
                            style: RitmoTextStyles.caption(colors.textPrimary),
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

        // کارت حال در بخش‌های روز
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
                        icon: Icons.wb_twilight,
                        mood: daypart['morning'],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildDaypartBox(
                        context,
                        title: 'بعدازظهر',
                        icon: Icons.wb_sunny_outlined,
                        mood: daypart['afternoon'],
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
                        icon: Icons.wb_twilight_outlined,
                        mood: daypart['evening'],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildDaypartBox(
                        context,
                        title: 'شب',
                        icon: Icons.nightlight_round,
                        mood: daypart['night'],
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

  Widget _buildDaypartBox(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Mood? mood,
  }) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(RitmoSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: colors.textSecondary),
              const SizedBox(width: 4),
              Text(title, style: RitmoTextStyles.caption(colors.textSecondary)),
            ],
          ),
          const SizedBox(height: 6),
          if (mood != null) ...[
            Text(
              mood.emoji,
              style: RitmoTextStyles.cardTitle(colors.textPrimary).copyWith(fontSize: 18),
            ),
            const SizedBox(height: 2),
            Text(
              mood.label,
              style: RitmoTextStyles.caption(colors.textPrimary),
            ),
          ] else ...[
            Text(
              '—',
              style: RitmoTextStyles.caption(colors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
