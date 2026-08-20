import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_colors.dart';
import 'package:ritmo/features/cycle/models/pregnancy_models.dart';

class PregStep1Tone extends StatelessWidget {
  const PregStep1Tone({
    super.key,
    required this.data,
    required this.onDataChanged,
    required this.onNext,
    required this.colors,
    required this.isDark,
  });

  final PregnancyOnboardingData data;
  final ValueChanged<PregnancyOnboardingData> onDataChanged;
  final VoidCallback onNext;
  final RitmoColors colors;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final primaryColor = colors.primary;

    return SingleChildScrollView(
      key: const ValueKey('preg_step_1_tone'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              height: 64,
              width: 64,
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.heart_fill,
                color: primaryColor,
                size: 32,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'قراره کنارت باشیم تا روز تولد',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: colors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'هر چیزی که وارد می‌کنی فقط روی همین گوشی می‌ماند.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: colors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Warm Tone Option
          _buildToneOptionCard(
            tone: PregnancyTone.warm,
            icon: CupertinoIcons.sparkles,
            title: 'گرم و صمیمی',
            subtitle: 'پیام‌ها دلگرم‌کننده و همراه با ایموجی',
          ),
          const SizedBox(height: 12),

          // Neutral Tone Option
          _buildToneOptionCard(
            tone: PregnancyTone.neutral,
            icon: CupertinoIcons.doc_text_fill,
            title: 'آرام و ساده',
            subtitle: 'فقط اطلاعات، بدون ایموجی و تبریک',
          ),
        ],
      ),
    );
  }

  Widget _buildToneOptionCard({
    required PregnancyTone tone,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = data.tone == tone;
    final primaryColor = colors.primary;

    return InkWell(
      onTap: () => onDataChanged(data.copyWith(tone: tone)),
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: isDark ? 0.2 : 0.08)
              : (isDark
                  ? Colors.black.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : colors.border.withValues(alpha: 0.5),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? primaryColor.withValues(alpha: 0.2)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.04)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? primaryColor : colors.textSecondary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? primaryColor : colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: colors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                CupertinoIcons.checkmark_alt_circle_fill,
                color: primaryColor,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}
