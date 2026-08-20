// C-43, C-44: PregnancyHeader
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/cycle/presentation/widgets/weekly_share_card.dart';
import 'package:ritmo/features/health/data/pregnancy_helpers.dart';
import 'package:ritmo/features/health/data/pregnancy_repository.dart';
import 'package:ritmo/features/health/presentation/widgets/pregnancy_report.dart';

class PregnancyHeader extends StatelessWidget {
  const PregnancyHeader({
    super.key,
    required this.currentWeek,
    required this.currentDayInWeek,
    required this.remainingDays,
    required this.pregTone,
    required this.eddSource,
    required this.startDate,
    required this.onShowPrivacy,
    required this.onShowSettings,
    this.showCountdown = true,
  });

  final int currentWeek;
  final int currentDayInWeek;
  final int remainingDays;
  final String pregTone;
  final String eddSource;
  final DateTime startDate;
  final VoidCallback onShowPrivacy;
  final VoidCallback onShowSettings;
  final bool showCountdown;

  Widget _buildHeaderActionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 36,
          height: 36,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.22 : 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withValues(alpha: isDark ? 0.35 : 0.2),
              width: 1,
            ),
          ),
          child: Icon(icon, size: 17, color: color),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ga = GestationalAge(currentWeek, currentDayInWeek);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: isDark ? 0.12 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Row: Title + Action Cluster
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Title & Tone
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Text('👶', style: TextStyle(fontSize: 15)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    pregTone == 'neutral' || pregTone == 'calm'
                        ? 'بارداری شما'
                        : 'دوران شیرین بارداری 🎀',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),

              // Glass Action Cluster
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: 'گزارش ویژه پزشک زنان',
                    child: _buildHeaderActionButton(
                      icon: CupertinoIcons.doc_text_fill,
                      color: colors.accent,
                      tooltip: 'گزارش پزشک',
                      onTap: () async {
                        await PregnancyReportScreen.show(
                          context,
                          pregnancyId: 'preg_default',
                          lmpDate: startDate,
                        );
                      },
                      isDark: isDark,
                    ),
                  ),
                  Tooltip(
                    message: 'اشتراک‌گذاری کارت رشد',
                    child: _buildHeaderActionButton(
                      icon: CupertinoIcons.share,
                      color: colors.primary,
                      tooltip: 'اشتراک‌گذاری',
                      onTap: () async => await WeeklyShareCardScreen.show(
                        context,
                        gestationalAge: ga,
                      ),
                      isDark: isDark,
                    ),
                  ),
                  Tooltip(
                    message: 'تنظیمات و گزینه‌ها',
                    child: _buildHeaderActionButton(
                      icon: CupertinoIcons.ellipsis_vertical,
                      color: colors.accent,
                      tooltip: 'تنظیمات بارداری',
                      onTap: onShowSettings,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Sub Row: Status Badges (Privacy + EDD Source) & Human Countdown Summary
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              // UX-15 Privacy Badge
              InkWell(
                onTap: onShowPrivacy,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.success.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: colors.success.withValues(alpha: 0.3),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.lock_fill,
                        size: 11,
                        color: colors.success,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'اطلاعات فقط روی گوشی',
                        style: TextStyle(
                          fontSize: 10,
                          color: colors.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (eddSource == 'ultrasound' ||
                  eddSource == 'doctor_edd' ||
                  eddSource == 'doctorEdd') ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: colors.accent.withValues(alpha: 0.3),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    eddSource == 'ultrasound'
                        ? 'سونوگرافی 🩺'
                        : 'تایید پزشک 🩺',
                    style: TextStyle(
                      fontSize: 10,
                      color: colors.accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],

              if (showCountdown) ...[
                // Human Countdown Summary Pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: isDark ? 0.2 : 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'هفته ${PersianDigits.toFa(currentWeek.toString())} + ${PersianDigits.toFa(currentDayInWeek.toString())} روز',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '• ${PregnancyHelpers.formatHumanCountdown(remainingDays)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
