import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/courses/presentation/widgets/course_formatters.dart';

class CoursesWeeklyHero extends StatelessWidget {

  const CoursesWeeklyHero({
    super.key,
    required this.weeklyDoneSessions,
    required this.weeklyTargetSessions,
    required this.weeklyStudyMinutes,
    required this.studyStreakDays,
  });
  final int weeklyDoneSessions;
  final int weeklyTargetSessions;
  final int weeklyStudyMinutes;
  final int studyStreakDays;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final m = context.metrics;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final progress = weeklyTargetSessions > 0
        ? (weeklyDoneSessions / weeklyTargetSessions).clamp(0.0, 1.0)
        : 0.0;

    return RitmoTheme.glassCardLight(
      color: isDarkMode
          ? colors.primary.withValues(alpha: 0.15)
          : colors.primary.withValues(alpha: 0.1),
      border: Border.all(
        color: colors.primary.withValues(alpha: 0.3),
        width: 1.5,
      ),
      child: Container(
        padding: EdgeInsets.all(m.spaceLg),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(m.radiusHero),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDarkMode
                ? [
                    colors.primary.withValues(alpha: 0.4),
                    colors.primary.withValues(alpha: 0.1),
                  ]
                : [
                    colors.primary.withValues(alpha: 0.08),
                    colors.card.withValues(alpha: 0.9),
                  ],
          ),
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
                      padding: EdgeInsets.all(m.spaceSm),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        CupertinoIcons.book_fill,
                        color: colors.primary,
                        size: m.iconMd,
                      ),
                    ),
                    SizedBox(width: m.spaceSm),
                    Text(
                      'خلاصه وضعیت هفته',
                      style: RitmoTextStyles.cardTitle(colors.textPrimary),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: m.spaceSm, vertical: m.spaceXs),
                  decoration: BoxDecoration(
                    color: colors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(m.radiusCard),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.flame_fill,
                        color: colors.success,
                        size: m.iconSm * 0.8,
                      ),
                      SizedBox(width: m.spaceXs),
                      Text(
                        '${toPersianDigits(studyStreakDays)} روز استریک',
                        style: RitmoTextStyles.badge(colors.success).copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: m.spaceLg),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'پیشرفت هدف هفتگی',
                        style: RitmoTextStyles.caption(colors.textSecondary),
                      ),
                      SizedBox(height: m.spaceXs),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Row(
                          textBaseline: TextBaseline.alphabetic,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          children: [
                            Text(
                              toPersianDigits(weeklyDoneSessions),
                              style: RitmoTextStyles.headlineMedium(colors.textPrimary).copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              ' / ${toPersianDigits(weeklyTargetSessions)} جلسه',
                              style: RitmoTextStyles.caption(colors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 40 * m.densityFactor,
                  width: 1,
                  color: colors.border.withValues(alpha: 0.5),
                ),
                SizedBox(width: m.spaceLg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'کل زمان مطالعه',
                        style: RitmoTextStyles.caption(colors.textSecondary),
                      ),
                      SizedBox(height: m.spaceXs),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Row(
                          textBaseline: TextBaseline.alphabetic,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          children: [
                            Text(
                              toPersianDigits(weeklyStudyMinutes),
                              style: RitmoTextStyles.headlineMedium(colors.textPrimary).copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              ' دقیقه',
                              style: RitmoTextStyles.caption(colors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: m.spaceMd),
            ClipRRect(
              borderRadius: BorderRadius.circular(RitmoRadius.pill),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8 * m.densityFactor,
                backgroundColor: colors.border.withValues(alpha: 0.5),
                valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
              ),
            ),
            if (weeklyDoneSessions >= weeklyTargetSessions && weeklyTargetSessions > 0) ...[
              SizedBox(height: m.spaceSm),
              Text(
                'هدف هفتگی محقق شد! عالیه 🎉💪',
                style: RitmoTextStyles.badge(colors.success).copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
