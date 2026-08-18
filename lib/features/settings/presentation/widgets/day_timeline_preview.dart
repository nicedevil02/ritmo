import 'package:flutter/cupertino.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';

class DayTimelinePreview extends StatelessWidget {
  const DayTimelinePreview({super.key});

  int _timeToMinutes(String timeStr, int defaultMinutes) {
    if (timeStr.isEmpty) return defaultMinutes;
    final parts = timeStr.split(':');
    final h = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return (h * 60 + m).clamp(0, 1440);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AnimatedBuilder(
      animation: SettingsService.instance.revision,
      builder: (context, _) {
        final quietEnabled = SettingsService.instance.get<bool>('notif_quiet_enabled');
        final quietStartStr = SettingsService.instance.get<String>('notif_quiet_start');
        final quietEndStr = SettingsService.instance.get<String>('notif_quiet_end');
        final planningTimeStr = SettingsService.instance.get<String>('daily_planning_nudge_time');

        final quietStartMin = _timeToMinutes(quietStartStr, 1380); // 23:00
        final quietEndMin = _timeToMinutes(quietEndStr, 420); // 07:00
        final planningMin = _timeToMinutes(planningTimeStr, 510); // 08:30

        return Container(
          key: const ValueKey('day_timeline_preview'),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(CupertinoIcons.clock, size: 16, color: colors.primary),
                      const SizedBox(width: 6),
                      Text(
                        'نمای توزیع ۲۴ ساعته زمان‌بندی‌ها',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  if (quietEnabled)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'سکوت: ${toPersianDigits(quietStartStr)} تا ${toPersianDigits(quietEndStr)}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: colors.primary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // Timeline Canvas Bar
              SizedBox(
                height: 28,
                child: CustomPaint(
                  size: const Size(double.infinity, 28),
                  painter: _TimelineBarPainter(
                    quietEnabled: quietEnabled,
                    quietStartMin: quietStartMin,
                    quietEndMin: quietEndMin,
                    planningMin: planningMin,
                    colors: colors,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Hour labels
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('۰۰:۰۰', style: TextStyle(fontSize: 10, color: colors.textTertiary)),
                  Text('۰۶:۰۰', style: TextStyle(fontSize: 10, color: colors.textTertiary)),
                  Text('۱۲:۰۰', style: TextStyle(fontSize: 10, color: colors.textTertiary)),
                  Text('۱۸:۰۰', style: TextStyle(fontSize: 10, color: colors.textTertiary)),
                  Text('۲۴:۰۰', style: TextStyle(fontSize: 10, color: colors.textTertiary)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TimelineBarPainter extends CustomPainter {
  _TimelineBarPainter({
    required this.quietEnabled,
    required this.quietStartMin,
    required this.quietEndMin,
    required this.planningMin,
    required this.colors,
  });

  final bool quietEnabled;
  final int quietStartMin;
  final int quietEndMin;
  final int planningMin;
  final dynamic colors;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(8),
    );

    // Base background (daytime gradient)
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF1E293B),
          Color(0xFF3B82F6),
          Color(0xFFF59E0B),
          Color(0xFF3B82F6),
          Color(0xFF1E293B),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.clipRRect(rrect);
    canvas.drawRRect(rrect, bgPaint);

    // Quiet hours overlay
    if (quietEnabled) {
      final quietPaint = Paint()..color = const Color(0xFF0F172A).withValues(alpha: 0.75);

      if (quietStartMin > quietEndMin) {
        // Overnight quiet (e.g. 23:00 to 07:00)
        final xStart = (quietStartMin / 1440.0) * size.width;
        final xEnd = (quietEndMin / 1440.0) * size.width;
        canvas.drawRect(Rect.fromLTWH(xStart, 0, size.width - xStart, size.height), quietPaint);
        canvas.drawRect(Rect.fromLTWH(0, 0, xEnd, size.height), quietPaint);
      } else {
        final xStart = (quietStartMin / 1440.0) * size.width;
        final xEnd = (quietEndMin / 1440.0) * size.width;
        canvas.drawRect(Rect.fromLTWH(xStart, 0, xEnd - xStart, size.height), quietPaint);
      }
    }

    // Planning nudge marker (vertical gold line)
    final markerPaint = Paint()
      ..color = const Color(0xFFFFD700)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final xPlan = (planningMin / 1440.0) * size.width;
    canvas.drawLine(Offset(xPlan, 0), Offset(xPlan, size.height), markerPaint);
  }

  @override
  bool shouldRepaint(covariant _TimelineBarPainter oldDelegate) {
    return oldDelegate.quietEnabled != quietEnabled ||
        oldDelegate.quietStartMin != quietStartMin ||
        oldDelegate.quietEndMin != quietEndMin ||
        oldDelegate.planningMin != planningMin;
  }
}
