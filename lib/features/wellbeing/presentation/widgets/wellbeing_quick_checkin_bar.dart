// lib/features/wellbeing/presentation/widgets/wellbeing_quick_checkin_bar.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/util/ritmo_number.dart';
import 'package:ritmo/features/energy/models/energy_mood_models.dart';
import 'package:ritmo/features/reflection/models/reflection_models.dart';
import 'package:ritmo/features/sleep/models/sleep_models.dart';

/// Instant 3-Pillar Check-in Bar for Wellbeing (Mood & Energy, Sleep, Reflection).
class WellbeingQuickCheckinBar extends StatelessWidget {
  const WellbeingQuickCheckinBar({
    super.key,
    required this.latestMood,
    required this.latestEnergy,
    required this.latestSleep,
    required this.todayReflection,
    this.onMoodEnergyTap,
    this.onMoodTap,
    this.onEnergyTap,
    required this.onSleepTap,
    required this.onReflectionTap,
  });

  final MoodLog? latestMood;
  final EnergyLog? latestEnergy;
  final SleepLog? latestSleep;
  final ReflectionEntry? todayReflection;

  final VoidCallback? onMoodEnergyTap;
  final VoidCallback? onMoodTap;
  final VoidCallback? onEnergyTap;
  final VoidCallback onSleepTap;
  final VoidCallback onReflectionTap;

  VoidCallback get handleMoodEnergyTap => onMoodEnergyTap ?? onMoodTap ?? onEnergyTap ?? () {};

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
                    style: RitmoTextStyles.cardTitle(
                      colors.textPrimary,
                    ).copyWith(fontSize: 14),
                  ),
                ],
              ),
              Text(
                '۳ ستون تعادل',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 1. Unified Mood & Energy Pillar (Full-Width Card)
          _buildPillarTile(
            context: context,
            title: 'حال روحی و انرژی',
            subtitle: _formatMoodEnergySubtitle(),
            icon: _resolveMoodEnergyIcon(),
            isRecorded: latestMood != null || latestEnergy != null,
            activeColor: const Color(0xffEC4899),
            colors: colors,
            onTap: handleMoodEnergyTap,
          ),
          const SizedBox(height: 10),

          // 2. Sleep & Reflection Pillars (Side-by-Side)
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
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
              const SizedBox(width: 10),
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
                  size: 16,
                  color: activeColor,
                )
              else
                Icon(
                  CupertinoIcons.plus_circle,
                  size: 16,
                  color: colors.textSecondary.withValues(alpha: 0.4),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _resolveMoodEnergyIcon() {
    if (latestMood != null) {
      final s = latestMood!.valence;
      if (s <= 1) return Icons.sentiment_very_dissatisfied_rounded;
      if (s == 2) return Icons.sentiment_dissatisfied_rounded;
      if (s == 3) return Icons.sentiment_neutral_rounded;
      if (s == 4) return Icons.sentiment_satisfied_rounded;
      return Icons.sentiment_very_satisfied_rounded;
    }
    if (latestEnergy != null) {
      return CupertinoIcons.bolt_fill;
    }
    return CupertinoIcons.heart_fill;
  }

  String _formatMoodEnergySubtitle() {
    final hasMood = latestMood != null;
    final hasEnergy = latestEnergy != null;

    if (!hasMood && !hasEnergy) return 'ثبت خلق و انرژی الان +';

    String moodPart = '';
    if (hasMood) {
      final s = latestMood!.valence;
      if (s <= 1) {
        moodPart = 'دلگیر';
      } else if (s == 2) {
        moodPart = 'بی‌حوصله';
      } else if (s == 3) {
        moodPart = 'معمولی';
      } else if (s == 4) {
        moodPart = 'خوب و آرام';
      } else {
        moodPart = 'عالی و شاداب';
      }
    }

    String energyPart = '';
    if (hasEnergy) {
      final lvl = latestEnergy!.energyLevel;
      if (lvl == EnergyLevel.high) {
        energyPart = 'انرژی بالا ⚡';
      } else if (lvl == EnergyLevel.medium) {
        energyPart = 'انرژی متوسط';
      } else if (lvl == EnergyLevel.low) {
        energyPart = 'انرژی پایین 🔋';
      } else {
        energyPart = 'ثبت شد';
      }
    }

    if (hasMood && hasEnergy) {
      return '$moodPart • $energyPart';
    } else if (hasMood) {
      return moodPart;
    } else {
      return energyPart;
    }
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
