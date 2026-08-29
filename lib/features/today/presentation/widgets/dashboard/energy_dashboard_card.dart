import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_card.dart';
import 'package:ritmo/core/widgets/ritmo_energy_dial.dart';
import 'package:ritmo/l10n/app_localizations.dart';

/// کارت وضعیت انرژی جاری در داشبورد امروز با طراحی نئومورفیک و لیست تیتروار علل انرژی
/// متصل به سیستم مرجع نئومورفیک ریتمو (RitmoCard.neumorphic)
class EnergyDashboardCard extends StatelessWidget {
  const EnergyDashboardCard({
    super.key,
    required this.isDarkMode,
    required this.currentEnergyPercent,
    required this.currentEnergyLabel,
    required this.currentEnergyDesc,
    this.energyFactors = const [],
    required this.onEnergyTap,
  });

  final bool isDarkMode;
  final double? currentEnergyPercent;
  final String currentEnergyLabel;
  final String currentEnergyDesc;
  final List<String> energyFactors;
  final VoidCallback onEnergyTap;

  List<String> _resolveDisplayReasons(double? percent) {
    if (energyFactors.isNotEmpty) {
      return energyFactors.take(3).toList();
    }

    final p = percent ?? 60.0;
    if (p >= 70) {
      return const [
        'اوج ریتم بیولوژیک روزانه',
        'بازیابی کامل با خواب و استراحت',
        'آمادگی حداکثری برای تمرکز و پروژه‌ها',
      ];
    } else if (p >= 40) {
      return const [
        'ریتم پایدار بعد از ظهر',
        'توان کافی برای مطالعه و روتین‌ها',
        'پیشنهاد تنفس کوتاه قبل از تسک بعدی',
      ];
    } else {
      return const [
        'افت طبیعی انرژی و خستگی ذهنی',
        'فشار تسک‌های انجام‌شده اخیر',
        'اولویت با استراحت یا کارهای سبک',
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;
    final m = context.metrics;

    final Color energyColor;
    final IconData energyIcon;

    final isHigh = currentEnergyLabel == 'بالا' || currentEnergyLabel == 'High';
    final isLow = currentEnergyLabel == 'پایین' || currentEnergyLabel == 'Low';

    if (isHigh) {
      energyColor = colors.success;
      energyIcon = CupertinoIcons.flame_fill;
    } else if (isLow) {
      energyColor = colors.medicalRed;
      energyIcon = CupertinoIcons.moon_fill;
    } else {
      energyColor = colors.energyAccent;
      energyIcon = CupertinoIcons.bolt_fill;
    }

    final energyLabel = isHigh
        ? l10n.energyLevelHigh
        : isLow
            ? l10n.energyLevelLow
            : l10n.energyLevelMedium;

    final energyDesc = isHigh
        ? l10n.energyDescHigh
        : isLow
            ? l10n.energyDescLow
            : l10n.energyDescMedium;

    final reasons = _resolveDisplayReasons(currentEnergyPercent);

    return RitmoCard.neumorphic(
      borderRadius: BorderRadius.circular(28),
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      onTap: onEnergyTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // سمت راست (شروع خوانش RTL): عنوان انرژی همراه آیکون، سطح، توضیح و علل
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ردیف عنوان به همراه نشان دایره‌ای درخشان و جذاب آیکون انرژی
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            energyColor.withValues(alpha: 0.35),
                            energyColor.withValues(alpha: 0.18),
                          ],
                        ),
                        border: Border.all(
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.white.withValues(alpha: 0.85),
                          width: 0.8,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          energyIcon,
                          size: 13,
                          color: energyColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.currentEnergyTitle,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Vazirmatn',
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                Text(
                  energyLabel,
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Vazirmatn',
                    color: energyColor,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  energyDesc,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Vazirmatn',
                    color: colors.textSecondary,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // علل شکل‌گیری این سطح انرژی (تیتروار و خلاصه‌وار)
                for (final reason in reasons)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: energyColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            reason,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Vazirmatn',
                              color: colors.textSecondary,
                              height: 1.25,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // سمت چپ (در RTL انتهای Row): گیج دایره‌ای در بالاترین نقطه + دکمه مدیریت در زیر آن
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              RitmoEnergyDial(
                percentage: currentEnergyPercent,
                isDarkMode: isDarkMode,
                size: 90.0 * m.densityFactor,
                activeColor: energyColor,
              ),
              const SizedBox(height: 8),
              RitmoNeuButton(
                height: 28,
                radius: 14,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                onTap: onEnergyTap,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.manageEnergy,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Vazirmatn',
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      CupertinoIcons.chevron_left,
                      size: 11,
                      color: colors.textSecondary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
