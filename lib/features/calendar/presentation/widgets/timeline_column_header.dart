import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_card.dart';
import 'package:ritmo/features/calendar/presentation/utils/calendar_geometry.dart';

class SplitDayRange {
  const SplitDayRange({
    required this.startMinutes,
    required this.endMinutes,
    required this.titleFa,
    required this.rangeLabel,
    required this.icon,
    required this.accentColor,
  });

  final int startMinutes;
  final int endMinutes;
  final String titleFa;
  final String rangeLabel;
  final IconData icon;
  final Color accentColor;

  static const morning = SplitDayRange(
    startMinutes: 0,
    endMinutes: CalendarGeometry.splitBoundaryMinutes,
    titleFa: 'صبح',
    rangeLabel: '۱۲:۰۰ – ۰۰:۰۰',
    icon: CupertinoIcons.sunrise_fill,
    accentColor: Color(0xFFF59E0B), // Sunrise Gold
  );

  static const afternoon = SplitDayRange(
    startMinutes: CalendarGeometry.splitBoundaryMinutes,
    endMinutes: 1440,
    titleFa: 'بعدازظهر',
    rangeLabel: '۲۴:۰۰ – ۱۲:۰۰',
    icon: CupertinoIcons.sun_max_fill,
    accentColor: Color(0xFF0284C7), // Afternoon Azure / Sky
  );
}

class TimelineColumnHeader extends StatelessWidget {
  const TimelineColumnHeader({
    super.key,
    required this.title,
    required this.icon,
    required this.rangeLabel,
    required this.isActive,
    this.accentColor,
  });

  final String title;
  final IconData icon;
  final String rangeLabel;
  final bool isActive;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final tone = accentColor ?? (title.contains('صبح')
        ? const Color(0xFFF59E0B)
        : const Color(0xFF0284C7));

    final bgGradient = LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: isActive
          ? [
              tone.withValues(alpha: isDark ? 0.24 : 0.16),
              tone.withValues(alpha: isDark ? 0.08 : 0.04),
            ]
          : [
              (isDark ? colors.card : Colors.white).withValues(alpha: isDark ? 0.60 : 0.85),
              (isDark ? colors.card : Colors.white).withValues(alpha: isDark ? 0.40 : 0.65),
            ],
    );

    return AnimatedContainer(
      duration: RitmoMotion.state,
      constraints: BoxConstraints(
        minHeight: CalendarGeometry.effectiveColumnHeaderHeight(context),
      ),
      margin: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 2.0),
      padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 3.0),
      decoration: BoxDecoration(
        gradient: bgGradient,
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(
          color: isActive
              ? tone.withValues(alpha: isDark ? 0.60 : 0.45)
              : (isDark ? Colors.white.withValues(alpha: 0.06) : colors.border.withValues(alpha: 0.5)),
          width: isActive ? 1.2 : 0.8,
        ),
        boxShadow: [
          if (isActive)
            BoxShadow(
              color: tone.withValues(alpha: isDark ? 0.22 : 0.15),
              offset: const Offset(0, 1.5),
              blurRadius: 5,
              spreadRadius: -1,
            )
          else
            BoxShadow(
              color: isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0xFFD5DCE4).withValues(alpha: 0.35),
              offset: const Offset(0, 1),
              blurRadius: 2,
            ),
        ],
      ),
      child: Row(
        children: [
          // Sunken icon well with semantic domain tone
          RitmoNeuSurface(
            height: 20,
            width: 20,
            radius: 10,
            sunken: true,
            padding: EdgeInsets.zero,
            glowColor: tone.withValues(alpha: isActive ? 0.45 : 0.20),
            child: Center(
              child: Icon(
                icon,
                size: 11,
                color: isActive ? tone : colors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 4.0),
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                fontFamily: 'Vazirmatn',
                color: isActive ? colors.textPrimary : colors.textSecondary,
              ),
            ),
          ),
          if (isActive) ...[
            const SizedBox(width: 3),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tone,
                boxShadow: [
                  BoxShadow(
                    color: tone.withValues(alpha: 0.6),
                    blurRadius: 3,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.0),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: isDark ? 0.08 : 0.04),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              toPersianDigits(rangeLabel),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                fontFamily: 'Vazirmatn',
                color: isActive ? tone : colors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
