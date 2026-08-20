import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_colors.dart';
import 'package:ritmo/features/cycle/models/pregnancy_models.dart';

class PregStep3Context extends StatelessWidget {
  const PregStep3Context({
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
      key: const ValueKey('preg_step_3_context'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'شرایط و اتصالات بارداری',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'تنظیمات مربوط به وضعیت پزشکی و هماهنگی بخش‌های برنامه',
            style: TextStyle(
              fontSize: 12.5,
              color: colors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),

          // 1. Multiple pregnancy
          _buildToggleRow(
            title: 'بارداری چندقلو',
            subtitle: 'در صورتی که بارداری دوقلو یا بیشتر است',
            icon: CupertinoIcons.person_2_fill,
            value: data.isMultiple,
            onChanged: (val) => onDataChanged(data.copyWith(isMultiple: val)),
          ),
          const SizedBox(height: 12),

          // 2. High risk
          _buildToggleRow(
            title: 'بارداری پرخطر بر اساس نظر پزشک',
            subtitle: 'در صورت تشخیص پزشک معالج جهت مراقبت‌های ویژه',
            icon: CupertinoIcons.bandage_fill,
            value: data.isHighRisk,
            onChanged: (val) => onDataChanged(data.copyWith(isHighRisk: val)),
          ),
          const SizedBox(height: 12),

          // 3. Pause cycle predictions
          _buildToggleRow(
            title: 'توقف پیش‌بینی و یادآوری پریود',
            subtitle: 'در طول دورهٔ بارداری پیش‌بینی‌های قاعدگی متوقف می‌شوند',
            icon: CupertinoIcons.bell_slash_fill,
            value: data.pauseCyclePredictions,
            onChanged: (val) => onDataChanged(data.copyWith(pauseCyclePredictions: val)),
          ),
          const SizedBox(height: 12),

          // 4. Suspend worship
          _buildToggleRow(
            title: 'تعلیق نماز و روزه در عبادات',
            subtitle: 'هماهنگی خودکار وضعیت عبادات و روزه‌های قضا در اپلیکیشن',
            icon: CupertinoIcons.sparkles,
            value: data.suspendWorship,
            onChanged: (val) => onDataChanged(data.copyWith(suspendWorship: val)),
          ),
          const SizedBox(height: 24),

          // Calming note card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: isDark ? 0.12 : 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: primaryColor.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  CupertinoIcons.shield_lefthalf_fill,
                  color: primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'سابقهٔ چرخه‌ات دست‌نخورده می‌ماند و بعد از زایمان برمی‌گردد. هیچ داده‌ای حذف نمی‌شود.',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final primaryColor = colors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: value
            ? primaryColor.withValues(alpha: isDark ? 0.14 : 0.06)
            : (isDark
                ? Colors.black.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: value
              ? primaryColor.withValues(alpha: 0.5)
              : colors.border.withValues(alpha: 0.4),
          width: value ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: value
                  ? primaryColor.withValues(alpha: 0.2)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.04)),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: value ? primaryColor : colors.textSecondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: value ? primaryColor : colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            activeTrackColor: primaryColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
