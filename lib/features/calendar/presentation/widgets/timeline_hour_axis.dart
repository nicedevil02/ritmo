import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/calendar/presentation/utils/calendar_geometry.dart';

enum HourAxisSide { leading, trailing }

class TimelineHourAxis extends StatelessWidget {
  const TimelineHourAxis({
    super.key,
    this.pxPerMinute,
    this.rangeStartMinutes = 0,
    this.rangeEndMinutes = 1440,
    this.width,
    this.side = HourAxisSide.leading,
    this.labelStyle,
    this.isToday = false,
    this.now,
  });

  final double? pxPerMinute;
  final int rangeStartMinutes;
  final int rangeEndMinutes;
  final double? width;
  final HourAxisSide side;
  final TextStyle? labelStyle;
  final bool isToday;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectivePxPerMinute = pxPerMinute ?? CalendarGeometry.effectivePxPerMinute(context);
    final effectiveWidth = width ?? CalendarGeometry.effectiveHourAxisWidth(context);
    final effectiveNow = now ?? DateTime.now();
    final nowHour = effectiveNow.hour;
    final startHour = (rangeStartMinutes / 60.0).ceil();
    final endHour = (rangeEndMinutes / 60.0).floor();
    final rangeHeight = (rangeEndMinutes - rangeStartMinutes) * effectivePxPerMinute;

    final isLeading = side == HourAxisSide.leading;

    return SizedBox(
      width: effectiveWidth,
      height: rangeHeight,
      child: Stack(
        children: [
          // Ruler tick marks custom painter (only at :15, :30, :45)
          Positioned.fill(
            child: CustomPaint(
              painter: _RulerTicksPainter(
                pxPerMinute: effectivePxPerMinute,
                rangeStartMinutes: rangeStartMinutes,
                rangeEndMinutes: rangeEndMinutes,
                isLeading: isLeading,
                isToday: isToday,
                nowHour: nowHour,
                primaryColor: colors.primary,
                tickColor: isDark
                    ? Colors.white.withValues(alpha: 0.38)
                    : Colors.black.withValues(alpha: 0.32),
                halfTickColor: isDark
                    ? Colors.white.withValues(alpha: 0.60)
                    : Colors.black.withValues(alpha: 0.52),
              ),
            ),
          ),
          // Minimal hour labels (clean, no line behind)
          for (var h = startHour; h <= endHour; h++)
            Positioned(
              top: ((h * 60) - rangeStartMinutes) * effectivePxPerMinute - 8,
              left: isLeading ? 0 : 5.0,
              right: isLeading ? 5.0 : 0,
              child: Align(
                alignment: isLeading
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 0.5),
                  decoration: (isToday && h == nowHour)
                      ? BoxDecoration(
                          color: colors.primary.withValues(alpha: isDark ? 0.22 : 0.14),
                          borderRadius: BorderRadius.circular(4),
                        )
                      : null,
                  child: Text(
                    toPersianDigits('$h'),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontFamily: 'Vazirmatn',
                      fontWeight: (isToday && h == nowHour) ? FontWeight.w900 : FontWeight.w700,
                      color: isToday
                          ? (h == nowHour
                              ? colors.primary
                              : (h < nowHour ? colors.textTertiary.withValues(alpha: 0.55) : colors.textSecondary))
                          : colors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RulerTicksPainter extends CustomPainter {
  _RulerTicksPainter({
    required this.pxPerMinute,
    required this.rangeStartMinutes,
    required this.rangeEndMinutes,
    required this.isLeading,
    required this.isToday,
    required this.nowHour,
    required this.primaryColor,
    required this.tickColor,
    required this.halfTickColor,
  });

  final double pxPerMinute;
  final int rangeStartMinutes;
  final int rangeEndMinutes;
  final bool isLeading;
  final bool isToday;
  final int nowHour;
  final Color primaryColor;
  final Color tickColor;
  final Color halfTickColor;

  @override
  void paint(Canvas canvas, Size size) {
    final startHour = (rangeStartMinutes / 60.0).ceil();
    final endHour = (rangeEndMinutes / 60.0).floor();

    final quarterPaint = Paint()
      ..color = tickColor
      ..strokeWidth = 0.9;

    final halfPaint = Paint()
      ..color = halfTickColor
      ..strokeWidth = 1.2;

    for (var h = startHour; h <= endHour; h++) {
      final y = ((h * 60) - rangeStartMinutes) * pxPerMinute;

      // Note: No tick at :00 behind the hour number to keep it completely clean!

      if (h < endHour) {
        // Quarter past (:15) tick
        final q1Y = y + (15 * pxPerMinute);
        if (q1Y <= size.height) {
          if (isLeading) {
            canvas.drawLine(Offset(size.width - 3.5, q1Y), Offset(size.width, q1Y), quarterPaint);
          } else {
            canvas.drawLine(Offset(0, q1Y), Offset(3.5, q1Y), quarterPaint);
          }
        }

        // Half past (:30) tick
        final halfY = y + (30 * pxPerMinute);
        if (halfY <= size.height) {
          if (isLeading) {
            canvas.drawLine(Offset(size.width - 6.5, halfY), Offset(size.width, halfY), halfPaint);
          } else {
            canvas.drawLine(Offset(0, halfY), Offset(6.5, halfY), halfPaint);
          }
        }

        // Quarter to (:45) tick
        final q3Y = y + (45 * pxPerMinute);
        if (q3Y <= size.height) {
          if (isLeading) {
            canvas.drawLine(Offset(size.width - 3.5, q3Y), Offset(size.width, q3Y), quarterPaint);
          } else {
            canvas.drawLine(Offset(0, q3Y), Offset(3.5, q3Y), quarterPaint);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RulerTicksPainter oldDelegate) =>
      oldDelegate.pxPerMinute != pxPerMinute ||
      oldDelegate.rangeStartMinutes != rangeStartMinutes ||
      oldDelegate.rangeEndMinutes != rangeEndMinutes ||
      oldDelegate.isLeading != isLeading ||
      oldDelegate.isToday != isToday ||
      oldDelegate.nowHour != nowHour ||
      oldDelegate.tickColor != tickColor ||
      oldDelegate.halfTickColor != halfTickColor;
}

class TimelineGridLines extends StatelessWidget {
  const TimelineGridLines({
    super.key,
    this.pxPerMinute,
    this.rangeStartMinutes = 0,
    this.rangeEndMinutes = 1440,
  });

  final double? pxPerMinute;
  final int rangeStartMinutes;
  final int rangeEndMinutes;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectivePxPerMinute = pxPerMinute ?? CalendarGeometry.effectivePxPerMinute(context);
    final rangeHeight = (rangeEndMinutes - rangeStartMinutes) * effectivePxPerMinute;

    return SizedBox(
      height: rangeHeight,
      child: CustomPaint(
        size: Size(double.infinity, rangeHeight),
        painter: _GridLinesPainter(
          pxPerMinute: effectivePxPerMinute,
          rangeStartMinutes: rangeStartMinutes,
          rangeEndMinutes: rangeEndMinutes,
          halfHourLineColor: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.10),
          quarterLineColor: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.035),
        ),
      ),
    );
  }
}

class _GridLinesPainter extends CustomPainter {
  _GridLinesPainter({
    required this.pxPerMinute,
    required this.rangeStartMinutes,
    required this.rangeEndMinutes,
    required this.halfHourLineColor,
    required this.quarterLineColor,
  });

  final double pxPerMinute;
  final int rangeStartMinutes;
  final int rangeEndMinutes;
  final Color halfHourLineColor;
  final Color quarterLineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final halfPaint = Paint()
      ..color = halfHourLineColor
      ..strokeWidth = 0.8;

    final quarterPaint = Paint()
      ..color = quarterLineColor
      ..strokeWidth = 0.5;

    final startHour = (rangeStartMinutes / 60.0).ceil();
    final endHour = (rangeEndMinutes / 60.0).floor();

    for (var h = startHour; h <= endHour; h++) {
      final y = ((h * 60) - rangeStartMinutes) * pxPerMinute;

      // No full hour line across the grid behind the hour digits

      if (h < endHour) {
        // Quarter line (:15)
        final q1Y = y + (15 * pxPerMinute);
        if (q1Y <= size.height) {
          canvas.drawLine(Offset(0, q1Y), Offset(size.width, q1Y), quarterPaint);
        }

        // Half hour line (:30) - clearly visible
        final halfY = y + (30 * pxPerMinute);
        if (halfY <= size.height) {
          canvas.drawLine(Offset(0, halfY), Offset(size.width, halfY), halfPaint);
        }

        // Quarter line (:45)
        final q3Y = y + (45 * pxPerMinute);
        if (q3Y <= size.height) {
          canvas.drawLine(Offset(0, q3Y), Offset(size.width, q3Y), quarterPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GridLinesPainter oldDelegate) =>
      oldDelegate.pxPerMinute != pxPerMinute ||
      oldDelegate.rangeStartMinutes != rangeStartMinutes ||
      oldDelegate.rangeEndMinutes != rangeEndMinutes ||
      oldDelegate.halfHourLineColor != halfHourLineColor ||
      oldDelegate.quarterLineColor != quarterLineColor;
}
