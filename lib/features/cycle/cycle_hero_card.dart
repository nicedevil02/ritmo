import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';

/// فازهای مختلف چرخه بدن
enum CyclePhase {
  menstrual, // قاعدگی
  follicular, // فولیکولار
  ovulatory, //تخمک‌گذاری
  luteal, // لوتئال
}

/// مدل داده‌ای برای تنظیمات ظاهری هر فاز
class PhaseDesignTheme {
  const PhaseDesignTheme({
    required this.title,
    required this.description,
    required this.baseColor,
    required this.gradientColors,
    required this.icon,
  });
  final String title;
  final String description;
  final Color baseColor;
  final List<Color> gradientColors;
  final IconData icon;

  static PhaseDesignTheme getTheme(CyclePhase phase, RitmoColors colors) {
    switch (phase) {
      case CyclePhase.menstrual:
        return PhaseDesignTheme(
          title: 'فاز قاعدگی',
          description: 'زمان استراحت، تغذیه گرم و مراقبت ملایم از خود.',
          baseColor: colors.error,
          gradientColors: [
            colors.error,
            colors.error.withValues(alpha: 0.85),
            colors.accent,
          ],
          icon: Icons.water_drop,
        );
      case CyclePhase.follicular:
        return PhaseDesignTheme(
          title: 'فاز فولیکولار',
          description:
              'افزایش سطح انرژی! زمان ایده‌آل برای برنامه‌ریزی و یادگیری.',
          baseColor: colors.accent,
          gradientColors: [
            colors.accent,
            colors.accent.withValues(alpha: 0.85),
            colors.primary,
          ],
          icon: Icons.wb_sunny_outlined,
        );
      case CyclePhase.ovulatory:
        return PhaseDesignTheme(
          title: 'فاز تخمک‌گذاری',
          description:
              'اوج درخشش و ارتباطات اجتماعی. کارهای گروهی عالی پیش می‌روند.',
          baseColor: colors.accent,
          gradientColors: [
            colors.accent,
            colors.accent.withValues(alpha: 0.85),
            colors.primary,
          ],
          icon: Icons.auto_awesome,
        );
      case CyclePhase.luteal:
        return PhaseDesignTheme(
          title: 'فاز لوتئال',
          description:
              'کاهش تدریجی انرژی. به سمت کارهای انفرادی و آرامش حرکت کنید.',
          baseColor: colors.primary,
          gradientColors: [
            colors.primary,
            colors.primary.withValues(alpha: 0.85),
            colors.accent,
          ],
          icon: Icons.nights_stay_outlined,
        );
    }
  }
}

/// کارت هیرو پرمیوم چرخه بدن
class CycleHeroCard extends StatelessWidget {
  const CycleHeroCard({
    super.key,
    required this.currentPhase,
    required this.currentDay,
    required this.totalDaysInPhase,
    this.onTap,
  });

  final CyclePhase currentPhase;
  final int currentDay;
  final int totalDaysInPhase;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = PhaseDesignTheme.getTheme(currentPhase, colors);
    final m = context.metrics;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            minHeight: 180 * m.densityFactor,
          ),
          margin: EdgeInsets.all(m.spaceLg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(m.radiusHero),
            gradient: LinearGradient(
              colors: theme.gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.baseColor.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(m.spaceXl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(m.spaceSm),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        theme.icon,
                        color: Colors.white,
                        size: m.iconLg,
                      ),
                    ),
                    SizedBox(width: m.spaceMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              theme.title,
                              style: RitmoTextStyles.sectionHeadline(Colors.white),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            toPersianDigits(
                              'روز $currentDay از $totalDaysInPhase',
                            ),
                            style: RitmoTextStyles.caption(
                              Colors.white.withValues(alpha: 0.9),
                            ).copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: m.spaceSm),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: m.spaceMd,
                        vertical: m.spaceXs,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(m.radiusHero),
                      ),
                      child: Text(
                        'پرمیوم',
                        style: RitmoTextStyles.badge(Colors.white).copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: m.spaceMd),
                Text(
                  theme.description,
                  style: RitmoTextStyles.body(
                    Colors.white.withValues(alpha: 0.95),
                  ).copyWith(height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
