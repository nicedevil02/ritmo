import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/widgets/ritmo_energy_dial.dart';
import 'package:ritmo/l10n/app_localizations.dart';

/// کارت وضعیت انرژی جاری در داشبورد امروز با طراحی نئومورفیک و لیست تیتروار علل انرژی
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

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1B202B) : const Color(0xFFEFF2F6),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.white.withValues(alpha: 0.90),
          width: 1.0,
        ),
        boxShadow: [
          // سایه نرم تیره پایین-راست
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withValues(alpha: 0.48)
                : const Color(0xFFCAD3DF).withValues(alpha: 0.75),
            offset: const Offset(3, 4),
            blurRadius: 10,
          ),
          // هایلایت نورانی بالا-چپ
          BoxShadow(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.white,
            offset: const Offset(-3, -3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onEnergyTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
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
                              color: isDarkMode
                                  ? const Color(0xFF232A38)
                                  : Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: energyColor.withValues(
                                  alpha: isDarkMode ? 0.35 : 0.25,
                                ),
                                width: 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: energyColor.withValues(
                                    alpha: isDarkMode ? 0.38 : 0.28,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 1.5),
                                ),
                                BoxShadow(
                                  color: isDarkMode
                                      ? Colors.black.withValues(alpha: 0.25)
                                      : const Color(0xFFCAD3DF).withValues(alpha: 0.5),
                                  blurRadius: 3,
                                  offset: const Offset(0.8, 1.2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                energyIcon,
                                size: 14,
                                color: energyColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            l10n.currentEnergyTitle,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3), // فاصله بسیار کم بین عنوان و وضعیت انرژی

                      Text(
                        energyLabel,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
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
                          color: colors.textSecondary,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),

                      // علل شکل‌گیری این سطح انرژی (تیتروار و خلاصه‌وار)
                      for (final reason in reasons)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3.5),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 4.5,
                                height: 4.5,
                                decoration: BoxDecoration(
                                  color: energyColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  reason,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDarkMode
                                        ? const Color(0xFFCBD5E1)
                                        : const Color(0xFF475569),
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
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4.5,
                      ),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? const Color(0xFF222835)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.05)
                              : const Color(0xFFD6DCE5),
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isDarkMode
                                ? Colors.black.withValues(alpha: 0.30)
                                : const Color(0xFFCBD3DE).withValues(alpha: 0.65),
                            offset: const Offset(1, 1.5),
                            blurRadius: 3,
                          ),
                          BoxShadow(
                            color: isDarkMode
                                ? Colors.white.withValues(alpha: 0.02)
                                : Colors.white,
                            offset: const Offset(-1, -1),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.manageEnergy,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            CupertinoIcons.chevron_left,
                            size: 12,
                            color: colors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
