import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/calendar/presentation/utils/calendar_geometry.dart';

class SplitDayRange {
  const SplitDayRange({
    required this.startMinutes,
    required this.endMinutes,
    required this.titleFa,
    required this.rangeLabel,
    required this.icon,
  });

  final int startMinutes;
  final int endMinutes;
  final String titleFa;
  final String rangeLabel;
  final IconData icon;

  static const morning = SplitDayRange(
    startMinutes: 0,
    endMinutes: CalendarGeometry.splitBoundaryMinutes,
    titleFa: 'صبح',
    rangeLabel: '۱۲:۰۰ – ۰۰:۰۰',
    icon: Icons.wb_twilight_rounded,
  );

  static const afternoon = SplitDayRange(
    startMinutes: CalendarGeometry.splitBoundaryMinutes,
    endMinutes: 1440,
    titleFa: 'بعدازظهر',
    rangeLabel: '۲۴:۰۰ – ۱۲:۰۰',
    icon: Icons.wb_sunny_rounded,
  );
}

class TimelineColumnHeader extends StatelessWidget {
  const TimelineColumnHeader({
    super.key,
    required this.title,
    required this.icon,
    required this.rangeLabel,
    required this.isActive,
  });

  final String title;
  final IconData icon;
  final String rangeLabel;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final activeGradient = LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: [
        colors.primary.withValues(alpha: 0.18),
        colors.primary.withValues(alpha: 0.06),
      ],
    );

    final inactiveGradient = LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: [
        colors.surfaceSubtle.withValues(alpha: 0.35),
        colors.surfaceSubtle.withValues(alpha: 0.15),
      ],
    );

    return AnimatedContainer(
      duration: RitmoMotion.state,
      constraints: BoxConstraints(
        minHeight: CalendarGeometry.effectiveColumnHeaderHeight(context),
      ),
      margin: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 2.0),
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.5),
      decoration: BoxDecoration(
        gradient: isActive ? activeGradient : inactiveGradient,
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(
          color: isActive
              ? colors.primary.withValues(alpha: 0.50)
              : colors.borderSubtle,
          width: isActive ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3.0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? colors.primary.withValues(alpha: 0.20)
                  : colors.surfaceSubtle,
            ),
            child: Icon(
              icon,
              size: 13,
              color: isActive ? colors.primary : colors.textSecondary,
            ),
          ),
          const SizedBox(width: 5.0),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: RitmoTextStyles.badge(
              isActive ? colors.textPrimary : colors.textSecondary,
            ).copyWith(fontWeight: FontWeight.bold),
          ),
          if (isActive) ...[
            const SizedBox(width: 4),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.primary,
              ),
            ),
          ],
          const Spacer(),
          Text(
            toPersianDigits(rangeLabel),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: RitmoTextStyles.badge(
              isActive ? colors.primary : colors.textTertiary,
            ).copyWith(
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
