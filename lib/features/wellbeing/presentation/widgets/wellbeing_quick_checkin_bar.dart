// lib/features/wellbeing/presentation/widgets/wellbeing_quick_checkin_bar.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/util/ritmo_number.dart';
import 'package:ritmo/features/energy/models/energy_mood_models.dart';
import 'package:ritmo/features/reflection/models/reflection_models.dart';
import 'package:ritmo/features/sleep/models/sleep_models.dart';

/// Instant 4-Pillar Check-in Bar for Wellbeing (Mood, Energy, Sleep, Reflection).
class WellbeingQuickCheckinBar extends StatelessWidget {
  const WellbeingQuickCheckinBar({
    super.key,
    required this.latestMood,
    required this.latestEnergy,
    required this.latestSleep,
    required this.todayReflection,
    required this.onMoodTap,
    required this.onEnergyTap,
    required this.onSleepTap,
    required this.onReflectionTap,
  });

  final MoodLog? latestMood;
  final EnergyLog? latestEnergy;
  final SleepLog? latestSleep;
  final ReflectionEntry? todayReflection;

  final VoidCallback onMoodTap;
  final VoidCallback onEnergyTap;
  final VoidCallback onSleepTap;
  final VoidCallback onReflectionTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(RitmoSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? colors.surface : colors.surface,
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        border: Border.all(
          color: colors.border.withValues(alpha: 0.6),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.25)
                : colors.shadow.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
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
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      CupertinoIcons.sparkles,
                      size: 15,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ارزیابی و چک‌این سریع امروز',
                    style: RitmoTextStyles.cardTitle(colors.textPrimary)
                        .copyWith(fontSize: 14),
                  ),
                ],
              ),
              Text(
                '۴ ستون تعادل',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2x2 Grid of Quick Check-in Tiles
          Row(
            children: [
              Expanded(
                child: _buildPillarTile(
                  context: context,
                  title: 'حس‌وحال الان',
                  subtitle: _formatMoodSubtitle(),
                  icon: _resolveMoodIcon(),
                  isRecorded: latestMood != null,
                  activeColor: const Color(0xffEC4899),
                  colors: colors,
                  onTap: onMoodTap,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildPillarTile(
                  context: context,
                  title: 'سطح انرژی',
                  subtitle: _formatEnergySubtitle(),
                  icon: CupertinoIcons.bolt_fill,
                  isRecorded: latestEnergy != null,
                  activeColor: const Color(0xffF59E0B),
                  colors: colors,
                  onTap: onEnergyTap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildPillarTile(
                  context: context,
                  title: 'خواب دیشب',
                  subtitle: _formatSleepSubtitle(),
                  icon: CupertinoIcons.moon_stars_fill,
                  isRecorded: latestSleep != null,
                  activeColor: const Color(0xff8B5CF6),
                  colors: colors,
                  onTap: onSleepTap,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildPillarTile(
                  context: context,
                  title: 'بازتاب روز',
                  subtitle: todayReflection != null
                      ? 'ثبت شد ✓'
                      : 'نوشتن حس روز +',
                  icon: Icons.edit_note_rounded,
                  isRecorded: todayReflection != null,
                  activeColor: const Color(0xff10B981),
                  colors: colors,
                  onTap: onReflectionTap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPillarTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isRecorded,
    required Color activeColor,
    required RitmoColors colors,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: isRecorded
                ? activeColor.withValues(alpha: 0.08)
                : colors.surfaceSunken.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isRecorded
                  ? activeColor.withValues(alpha: 0.35)
                  : colors.border.withValues(alpha: 0.4),
              width: isRecorded ? 1.2 : 0.9,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isRecorded
                      ? activeColor.withValues(alpha: 0.16)
                      : colors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isRecorded
                        ? activeColor.withValues(alpha: 0.3)
                        : colors.border.withValues(alpha: 0.2),
                  ),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    size: 18,
                    color: isRecorded ? activeColor : colors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: isRecorded ? activeColor : colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isRecorded)
                Icon(
                  CupertinoIcons.checkmark_circle_fill,
                  size: 14,
                  color: activeColor,
                )
              else
                Icon(
                  CupertinoIcons.plus_circle,
                  size: 14,
                  color: colors.textSecondary.withValues(alpha: 0.4),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _resolveMoodIcon() {
    if (latestMood == null) return CupertinoIcons.heart_fill;
    final s = latestMood!.valence;
    if (s <= 1) return Icons.sentiment_very_dissatisfied_rounded;
    if (s == 2) return Icons.sentiment_dissatisfied_rounded;
    if (s == 3) return Icons.sentiment_neutral_rounded;
    if (s == 4) return Icons.sentiment_satisfied_rounded;
    return Icons.sentiment_very_satisfied_rounded;
  }

  String _formatMoodSubtitle() {
    if (latestMood == null) return 'ثبت حس الان +';
    final s = latestMood!.valence;
    if (s <= 1) return 'خیلی بد';
    if (s == 2) return 'کمی خسته';
    if (s == 3) return 'معمولی';
    if (s == 4) return 'خوب و آرام';
    return 'عالی و پرانرژی';
  }

  String _formatEnergySubtitle() {
    if (latestEnergy == null) return 'ثبت انرژی +';
    final lvl = latestEnergy!.energyLevel;
    if (lvl == EnergyLevel.high) return 'انرژی بالا';
    if (lvl == EnergyLevel.medium) return 'انرژی متوسط';
    if (lvl == EnergyLevel.low) return 'انرژی پایین';
    return 'ثبت شد';
  }

  String _formatSleepSubtitle() {
    if (latestSleep == null) return 'ثبت خواب +';
    final mins = latestSleep!.durationMinutes;
    final h = mins ~/ 60;
    final m = mins % 60;
    if (m == 0) return '${RitmoNumber.faInt(h)} ساعت';
    return '${RitmoNumber.faInt(h)} ساعت و ${RitmoNumber.faInt(m)} دقیقه';
  }
}
