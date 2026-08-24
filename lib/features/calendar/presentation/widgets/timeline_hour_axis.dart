import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/calendar/presentation/utils/calendar_geometry.dart';

enum HourAxisSide { leading, trailing }

class TimelineHourAxis extends StatelessWidget {
  const TimelineHourAxis({
    super.key,
    required this.pxPerMinute,
    this.rangeStartMinutes = 0,
    this.rangeEndMinutes = 1440,
    this.width = CalendarGeometry.hourAxisWidth,
    this.side = HourAxisSide.leading,
    this.labelFontSize = 10.5,
    this.isToday = false,
    this.now,
  });

  final double pxPerMinute;
  final int rangeStartMinutes;
  final int rangeEndMinutes;
  final double width;
  final HourAxisSide side;
  final double labelFontSize;
  final bool isToday;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final effectiveNow = now ?? DateTime.now();
    final nowHour = effectiveNow.hour;
    final startHour = (rangeStartMinutes / 60.0).ceil();
    final endHour = (rangeEndMinutes / 60.0).floor();
    final rangeHeight = (rangeEndMinutes - rangeStartMinutes) * pxPerMinute;

    final isLeading = side == HourAxisSide.leading;

    return SizedBox(
      width: width,
      height: rangeHeight,
      child: Stack(
        children: [
          for (var h = startHour; h <= endHour; h++)
            Positioned(
              top: ((h * 60) - rangeStartMinutes) * pxPerMinute - 7,
              left: isLeading ? 1.0 : 0,
              right: isLeading ? 0 : 1.0,
              child: Align(
                alignment: isLeading ? Alignment.centerLeft : Alignment.centerRight,
                child: Text(
                  toPersianDigits('${h.toString().padLeft(2, '0')}:00'),
                  style: TextStyle(
                    fontSize: labelFontSize,
                    fontWeight: (isToday && h == nowHour) ? FontWeight.w700 : FontWeight.w500,
                    color: isToday
                        ? (h == nowHour
                            ? colors.primary
                            : (h < nowHour
                                ? colors.textTertiary
                                : colors.textSecondary))
                        : colors.textTertiary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class TimelineGridLines extends StatelessWidget {
  const TimelineGridLines({
    super.key,
    required this.pxPerMinute,
    this.rangeStartMinutes = 0,
    this.rangeEndMinutes = 1440,
  });

  final double pxPerMinute;
  final int rangeStartMinutes;
  final int rangeEndMinutes;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final rangeHeight = (rangeEndMinutes - rangeStartMinutes) * pxPerMinute;

    return SizedBox(
      height: rangeHeight,
      child: CustomPaint(
        size: Size(double.infinity, rangeHeight),
        painter: _GridLinesPainter(
          pxPerMinute: pxPerMinute,
          rangeStartMinutes: rangeStartMinutes,
          rangeEndMinutes: rangeEndMinutes,
          lineColor: colors.borderSubtle.withValues(alpha: 0.25),
          halfHourLineColor: colors.borderSubtle.withValues(alpha: 0.10),
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
          canvas.drawLine(Offset(0, halfY), Offset(size.width, halfY), halfPaint);
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
