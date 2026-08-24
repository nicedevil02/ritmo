import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:ritmo/core/analytics/energy_analytics_engine.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/util/ritmo_number.dart';

/// کارت نمایش ریتم شبانه‌روزی ۲۴ ساعته با منحنی پیوسته انرژی، پنجرهٔ طلایی و پنجرهٔ افت
class DailyRhythmCard extends StatelessWidget {
  const DailyRhythmCard({super.key, required this.output});

  final EnergyAnalyticsOutput? output;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final out = output;
    final golden = out?.peakPerformanceWindow;
    final fatigued = out?.mostFatiguedWindow;
    final weekday = out?.mostProductiveWeekday;

    final hasData =
        (golden != null && golden.isNotEmpty) ||
        (fatigued != null && fatigued.isNotEmpty);

    final goldenRange = _parseWindowRange(golden);
    final fatiguedRange = _parseWindowRange(fatigued);

    return Container(
      padding: const EdgeInsets.all(RitmoSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header: Title & Productive Weekday Tag ───
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      CupertinoIcons.waveform_path,
                      color: colors.primary,
                      size: 17,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ریتم شبانه‌روزی انرژی',
                    style: RitmoTextStyles.cardTitle(colors.textPrimary),
                  ),
                ],
              ),
              if (weekday != null && weekday.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    'پربارترین: ${_weekdayName(weekday)}',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: colors.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: RitmoSpacing.md),

          // ─── 24-Hour Continuous Circadian Wave Chart ───
          Container(
            height: 110,
            width: double.infinity,
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            decoration: BoxDecoration(
              color: colors.surfaceSunken,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border.withValues(alpha: 0.5)),
            ),
            child: CustomPaint(
              painter: _CircadianWavePainter(
                goldenRange: goldenRange,
                fatiguedRange: fatiguedRange,
                colors: colors,
              ),
            ),
          ),
          const SizedBox(height: 6),

          // ─── 24h Timeline Ticks ───
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                RitmoNumber.fa('۰۰:۰۰'),
                style: RitmoTextStyles.caption(
                  colors.textSecondary,
                ).copyWith(fontSize: 9.5),
              ),
              Text(
                RitmoNumber.fa('۰۶:۰۰'),
                style: RitmoTextStyles.caption(
                  colors.textSecondary,
                ).copyWith(fontSize: 9.5),
              ),
              Text(
                RitmoNumber.fa('۱۲:۰۰'),
                style: RitmoTextStyles.caption(
                  colors.textSecondary,
                ).copyWith(fontSize: 9.5),
              ),
              Text(
                RitmoNumber.fa('۱۸:۰۰'),
                style: RitmoTextStyles.caption(
                  colors.textSecondary,
                ).copyWith(fontSize: 9.5),
              ),
              Text(
                RitmoNumber.fa('۲۴:۰۰'),
                style: RitmoTextStyles.caption(
                  colors.textSecondary,
                ).copyWith(fontSize: 9.5),
              ),
            ],
          ),
          const SizedBox(height: RitmoSpacing.md),

          // ─── Status Blocks or Guidance ───
          if (!hasData) ...[
            Container(
              padding: const EdgeInsets.all(RitmoSpacing.md),
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.border.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.sparkles,
                    size: 16,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'با چند بار ثبت انرژی در ساعات مختلف روز، پنجره‌های اوج تمرکز و زمان‌های افت انرژی شما به صورت خودکار شناسایی و هایلایت می‌شوند.',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Row(
              children: [
                if (golden != null && golden.isNotEmpty) ...[
                  Expanded(
                    child: _buildWindowBlock(
                      context,
                      title: 'پنجرهٔ طلایی (اوج تمرکز)',
                      window: golden,
                      color: const Color(0xff10B981), // Emerald
                      icon: CupertinoIcons.sun_max_fill,
                    ),
                  ),
                ],
                if (golden != null &&
                    golden.isNotEmpty &&
                    fatigued != null &&
                    fatigued.isNotEmpty)
                  const SizedBox(width: RitmoSpacing.md),
                if (fatigued != null && fatigued.isNotEmpty) ...[
                  Expanded(
                    child: _buildWindowBlock(
                      context,
                      title: 'پنجرهٔ افت (زمان استراحت)',
                      window: fatigued,
                      color: const Color(0xff8B5CF6), // Violet/Purple
                      icon: CupertinoIcons.battery_25_percent,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWindowBlock(
    BuildContext context, {
    required String title,
    required String window,
    required Color color,
    required IconData icon,
  }) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(RitmoSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            RitmoNumber.fa(window),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  (double, double)? _parseWindowRange(String? window) {
    if (window == null || !window.contains('-')) return null;
    final parts = window.split('-');
    if (parts.length != 2) return null;
    final start = _parseHour(parts[0].trim());
    final end = _parseHour(parts[1].trim());
    if (start == null || end == null) return null;
    return (start, end);
  }

  double? _parseHour(String timeStr) {
    if (timeStr.contains(':')) {
      final sub = timeStr.split(':');
      final h = double.tryParse(sub[0]);
      final m = double.tryParse(sub[1]) ?? 0;
      if (h == null) return null;
      return h + (m / 60.0);
    }
    return double.tryParse(timeStr);
  }

  String _weekdayName(String weekday) {
    switch (weekday.toLowerCase()) {
      case 'saturday':
        return 'شنبه';
      case 'sunday':
        return 'یک‌شنبه';
      case 'monday':
        return 'دوشنبه';
      case 'tuesday':
        return 'سه‌شنبه';
      case 'wednesday':
        return 'چهارشنبه';
      case 'thursday':
        return 'پنج‌شنبه';
      case 'friday':
        return 'جمعه';
      default:
        return weekday;
    }
  }
}

class _CircadianWavePainter extends CustomPainter {
  _CircadianWavePainter({
    this.goldenRange,
    this.fatiguedRange,
    required this.colors,
  });

  final (double, double)? goldenRange;
  final (double, double)? fatiguedRange;
  final RitmoColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // 1. Draw Golden Window Shading
    if (goldenRange != null) {
      final x1 = (goldenRange!.$1 / 24.0).clamp(0.0, 1.0) * width;
      final x2 = (goldenRange!.$2 / 24.0).clamp(0.0, 1.0) * width;
      final rect = Rect.fromLTRB(x1, 0, x2, height);
      final goldenPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xff10B981).withValues(alpha: 0.22),
            const Color(0xff10B981).withValues(alpha: 0.04),
          ],
        ).createShader(rect);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        goldenPaint,
      );
    }

    // 2. Draw Fatigued Window Shading
    if (fatiguedRange != null) {
      final x1 = (fatiguedRange!.$1 / 24.0).clamp(0.0, 1.0) * width;
      final x2 = (fatiguedRange!.$2 / 24.0).clamp(0.0, 1.0) * width;
      final rect = Rect.fromLTRB(x1, 0, x2, height);
      final fatiguePaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xff8B5CF6).withValues(alpha: 0.20),
            const Color(0xff8B5CF6).withValues(alpha: 0.03),
          ],
        ).createShader(rect);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        fatiguePaint,
      );
    }

    // 3. Draw Base Circadian Rhythm Sine Wave Curve
    final path = Path();
    final fillPath = Path();

    final baselineY = height * 0.55;
    final amplitude = height * 0.32;

    for (var i = 0; i <= 60; i++) {
      final pct = i / 60.0;
      final x = pct * width;
      // Double peak circadian wave: morning peak (~10am), afternoon dip (~3pm), evening mini-peak (~7pm), night dip (~3am)
      final hour = pct * 24.0;
      final wave1 = math.sin((hour - 4.0) * (2 * math.pi / 24.0));
      final wave2 = 0.35 * math.sin((hour - 8.0) * (4 * math.pi / 24.0));
      final normWave = (wave1 + wave2) / 1.35; // Range -1 to +1

      final y = baselineY - (normWave * amplitude);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(width, height);
    fillPath.lineTo(0, height);
    fillPath.close();

    // Fill Gradient
    final fillGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        colors.primary.withValues(alpha: 0.14),
        colors.primary.withValues(alpha: 0.01),
      ],
    ).createShader(Rect.fromLTWH(0, 0, width, height));
    canvas.drawPath(fillPath, Paint()..shader = fillGradient);

    // Line Stroke
    final linePaint = Paint()
      ..color = colors.primary.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);

    // Current Time Marker (e.g. current hour)
    final now = DateTime.now();
    final currentHour = now.hour + (now.minute / 60.0);
    final currentX = (currentHour / 24.0) * width;
    final nowWave1 = math.sin((currentHour - 4.0) * (2 * math.pi / 24.0));
    final nowWave2 =
        0.35 * math.sin((currentHour - 8.0) * (4 * math.pi / 24.0));
    final currentY = baselineY - (((nowWave1 + nowWave2) / 1.35) * amplitude);

    // Current Time Pulsing Dot
    canvas.drawCircle(
      Offset(currentX, currentY),
      6.5,
      Paint()..color = colors.surface,
    );
    canvas.drawCircle(
      Offset(currentX, currentY),
      4.5,
      Paint()..color = colors.energyAccent,
    );
    canvas.drawCircle(
      Offset(currentX, currentY),
      8.0,
      Paint()
        ..color = colors.energyAccent.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _CircadianWavePainter oldDelegate) {
    return oldDelegate.goldenRange != goldenRange ||
        oldDelegate.fatiguedRange != fatiguedRange ||
        oldDelegate.colors != colors;
  }
}
