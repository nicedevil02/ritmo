import 'package:flutter/cupertino.dart';
import 'package:ritmo/core/domain/engines/ritmo_cross_module_engine.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

/// Contextual Neumorphic Banner shown in MvTodayTab when cross-module factors
/// (pregnancy, sleep debt, fasting window, menstrual cycle, or stress/fatigue) adapt the day's training.
class MvContextualBanner extends StatelessWidget {
  final RitmoCrossModuleSnapshot snapshot;
  final VoidCallback? onApplyFastingWindow;
  final VoidCallback? onShowRestorativeMovements;
  final VoidCallback? onApplySomaticMovement;
  final VoidCallback? onApplyPregnancyProtocol;

  const MvContextualBanner({
    super.key,
    required this.snapshot,
    this.onApplyFastingWindow,
    this.onShowRestorativeMovements,
    this.onApplySomaticMovement,
    this.onApplyPregnancyProtocol,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // 1. Pregnancy Safety Protocol (Highest Priority - Ultra-conservative)
    if (snapshot.isPregnancy) {
      return _buildBanner(
        context: context,
        icon: CupertinoIcons.shield_fill,
        iconColor: colors.primary,
        title: 'پروتکل محافظه‌کارانه بارداری',
        subtitle:
            'تمرینات به حرکات ایمن، کشش‌های پریناتال و تنفس هدایت شدند. هرگونه تمرین باید با تأیید پزشک متخصص باشد.',
        action: onApplyPregnancyProtocol != null
            ? GestureDetector(
                onTap: () {
                  RitmoHapticsPolicy.tap();
                  onApplyPregnancyProtocol!();
                },
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    'انطباق به تمرینات سبک پریناتال 🤰',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: colors.primary,
                    ),
                  ),
                ),
              )
            : null,
      );
    }

    // 2. Check Sleep Debt
    if (snapshot.isSleepDebtHigh) {
      return _buildBanner(
        context: context,
        icon: CupertinoIcons.moon_stars_fill,
        iconColor: colors.primary,
        title: 'انطباق هوشمند با خواب دیشب',
        subtitle:
            'به علت خواب کمتر از ۶ ساعت دیشب، برنامهٔ امروز به جلسهٔ سبک تبدیل شد تا بدن فرصت ریکاوری داشته باشد.',
      );
    }

    // 3. Check Fasting
    if (snapshot.isFasting && snapshot.goldenPreIftarWindow != null) {
      return _buildBanner(
        context: context,
        icon: CupertinoIcons.moon_fill,
        iconColor: colors.accent,
        title: 'پروتکل روزه‌داری و تمرین',
        subtitle:
            'ساعت بهینه برای تمرین ملایم: ۴۵ دقیقه مانده به افطار (${snapshot.goldenPreIftarWindow}).',
        action: onApplyFastingWindow != null
            ? GestureDetector(
                onTap: () {
                  RitmoHapticsPolicy.tap();
                  onApplyFastingWindow!();
                },
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colors.accent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    'تنظیم زمان به قبل از افطار 🌙',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: colors.accent,
                    ),
                  ),
                ),
              )
            : null,
      );
    }

    // 4. Check Menstrual Phase (with consent)
    if (snapshot.isMenstrualPhase && snapshot.cycleConsentGranted) {
      return _buildBanner(
        context: context,
        icon: CupertinoIcons.heart_fill,
        iconColor: colors.primary,
        title: 'فاز ریکاوری چرخهٔ زیستی',
        subtitle:
            'با توجه به فاز قاعدگی، حرکات کششی و آرام‌بخش تسکین‌دهنده فعال شدند.',
        action: onShowRestorativeMovements != null
            ? GestureDetector(
                onTap: () {
                  RitmoHapticsPolicy.tap();
                  onShowRestorativeMovements!();
                },
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    'تعدیل برنامه به تمرینات تسکین‌دهنده 🌸',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: colors.primary,
                    ),
                  ),
                ),
              )
            : null,
      );
    }

    // 5. Check High Stress / High Fatigue (Wellbeing & Somatic Movement)
    if (snapshot.isHighStressOrFatigue) {
      return _buildBanner(
        context: context,
        icon: CupertinoIcons.sparkles,
        iconColor: colors.primary,
        title: 'پیشنهاد تن‌آرامی و حرکات سوماتیک',
        subtitle:
            'با توجه به سطح خستگی ثبت‌شده، ۸ دقیقه تمرین سوماتیک و تنفس آرام‌بخش برای آزادسازی تنش پیشنهاد شد.',
        action: onApplySomaticMovement != null
            ? GestureDetector(
                onTap: () {
                  RitmoHapticsPolicy.tap();
                  onApplySomaticMovement!();
                },
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    'انطباق به تمرین سوماتیک و تنفس 🌿',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: colors.primary,
                    ),
                  ),
                ),
              )
            : null,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildBanner({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: RitmoCard.neumorphic(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 16,
                color: iconColor,
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
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.5,
                      color: colors.textSecondary,
                    ),
                  ),
                  ?action,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
