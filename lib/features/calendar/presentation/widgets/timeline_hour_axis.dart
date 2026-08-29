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
          // Ruler tick marks custom painter
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
                    ? Colors.white.withValues(alpha: 0.18)
                    : Colors.black.withValues(alpha: 0.18),
                halfTickColor: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.08),
              ),
            ),
          ),
          // Minimal hour labels
          for (var h = startHour; h <= endHour; h++)
            Positioned(
              top: ((h * 60) - rangeStartMinutes) * effectivePxPerMinute - 8,
              left: isLeading ? 0 : 7.0,
              right: isLeading ? 7.0 : 0,
              child: Align(
                alignment: isLeading
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 0.5),
                  decoration: (isToday && h == nowHour)
                      ? BoxDecoration(
                          color: colors.primary.withValues(alpha: isDark ? 0.20 : 0.12),
                          borderRadius: BorderRadius.circular(5),
                        )
                      : null,
                  child: Text(
                    toPersianDigits('$h'),
                    style: TextStyle(
                      fontSize: 10.0,
                      fontFamily: 'Vazirmatn',
                      fontWeight: (isToday && h == nowHour) ? FontWeight.w900 : FontWeight.w600,
                      color: isToday
                          ? (h == nowHour
                              ? colors.primary
                              : (h < nowHour ? colors.textTertiary.withValues(alpha: 0.6) : colors.textSecondary))
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

    for (var h = startHour; h <= endHour; h++) {
      final y = ((h * 60) - rangeStartMinutes) * pxPerMinute;
      final isNow = isToday && h == nowHour;

      final fullPaint = Paint()
        ..color = isNow ? primaryColor : tickColor
        ..strokeWidth = isNow ? 1.4 : 0.8;

      if (isLeading) {
        canvas.drawLine(
          Offset(size.width - 5.0, y),
          Offset(size.width, y),
          fullPaint,
        );
      } else {
        canvas.drawLine(
          Offset(0, y),
          Offset(5.0, y),
          fullPaint,
        );
      }

      // Half-hour tick
      if (h < endHour) {
        final halfY = y + (30 * pxPerMinute);
        if (halfY <= size.height) {
          final halfPaint = Paint()
            ..color = halfTickColor
            ..strokeWidth = 0.5;

          if (isLeading) {
            canvas.drawLine(
              Offset(size.width - 2.5, halfY),
              Offset(size.width, halfY),
              halfPaint,
            );
          } else {
            canvas.drawLine(
              Offset(0, halfY),
              Offset(2.5, halfY),
              halfPaint,
            );
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
      oldDelegate.primaryColor != primaryColor;
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
          lineColor: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.06),
          halfHourLineColor: isDark
              ? Colors.white.withValues(alpha: 0.02)
              : Colors.black.withValues(alpha: 0.025),
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
    required this.lineColor,
    required this.halfHourLineColor,
  });

  final double pxPerMinute;
  final int rangeStartMinutes;
  final int rangeEndMinutes;
  final Color lineColor;
  final Color halfHourLineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final mainPaint = Paint()
      ..color = lineColor
      ..strokeWidth = 0.5;

    final halfPaint = Paint()
      ..color = halfHourLineColor
      ..strokeWidth = 0.3;

    final startHour = (rangeStartMinutes / 60.0).ceil();
    final endHour = (rangeEndMinutes / 60.0).floor();

    for (var h = startHour; h <= endHour; h++) {
      final y = ((h * 60) - rangeStartMinutes) * pxPerMinute;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), mainPaint);

      if (h < endHour) {
        final halfY = y + (30 * pxPerMinute);
        if (halfY <= size.height) {
          canvas.drawLine(
            Offset(0, halfY),
            Offset(size.width, halfY),
            halfPaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GridLinesPainter oldDelegate) =>
      oldDelegate.pxPerMinute != pxPerMinute ||
      oldDelegate.rangeStartMinutes != rangeStartMinutes ||
      oldDelegate.rangeEndMinutes != rangeEndMinutes ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.halfHourLineColor != halfHourLineColor;
}
