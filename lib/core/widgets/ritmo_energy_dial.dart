// lib/core/widgets/ritmo_energy_dial.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';

/// Modern Thermostat-Style Energy Dial with top sweeping gradient arc,
/// floating thumb pin, and elevated central disk with ambient glow.
class RitmoEnergyDial extends StatelessWidget {
  const RitmoEnergyDial({
    super.key,
    required this.percentage,
    required this.isDarkMode,
    this.size = 66.0,
    this.activeColor,
  });

  final double? percentage;
  final bool isDarkMode;
  final double size;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.ritmoColors;
    final percent = percentage?.clamp(0.0, 100.0);
    final resolvedColor = activeColor ?? _resolveColor(percent);

    // Geometry calculations
    final diskMargin = size * 0.12;
    final diskSize = size - (diskMargin * 2);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Ambient Background Bottom Halo / Glow
          if (percent != null && percent > 0)
            Positioned(
              bottom: size * 0.02,
              child: Container(
                width: diskSize * 0.85,
                height: diskSize * 0.45,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(diskSize),
                  boxShadow: [
                    BoxShadow(
                      color: resolvedColor.withValues(
                        alpha: isDarkMode ? 0.35 : 0.25,
                      ),
                      blurRadius: size * 0.32,
                      spreadRadius: size * 0.04,
                    ),
                  ],
                ),
              ),
            ),

          // 2. Sweeping Top Arc & Floating Thumb Pin (Custom Painted)
          CustomPaint(
            size: Size(size, size),
            painter: _EnergyDialArcPainter(
              percentage: percent ?? 0,
              isDarkMode: isDarkMode,
              hasValue: percent != null,
              activeColor: resolvedColor,
            ),
          ),

          // 3. Central Elevated Floating Disk
          Container(
            width: diskSize,
            height: diskSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDarkMode
                  ? const Color(0xff1E1E2E)
                  : const Color(0xffFFFFFF),
              border: Border.all(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.14)
                    : Colors.black.withValues(alpha: 0.05),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDarkMode
                      ? Colors.black.withValues(alpha: 0.60)
                      : Colors.black.withValues(alpha: 0.10),
                  blurRadius: isDarkMode ? 10 : 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: percent == null
                  ? Text(
                      '—',
                      style: TextStyle(
                        fontSize: size * 0.26,
                        fontWeight: FontWeight.bold,
                        color: colors.textTertiary,
                      ),
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: toPersianDigits('${percent.round()}'),
                                style: TextStyle(
                                  fontSize: size * 0.30,
                                  fontWeight: FontWeight.w900,
                                  color: isDarkMode
                                      ? Colors.white
                                      : const Color(0xff0F172A),
                                  letterSpacing: -0.5,
                                  fontFamily: 'Vazirmatn',
                                ),
                              ),
                              TextSpan(
                                text: '٪',
                                style: TextStyle(
                                  fontSize: size * 0.16,
                                  fontWeight: FontWeight.w800,
                                  color: isDarkMode
                                      ? Colors.white.withValues(alpha: 0.7)
                                      : const Color(0xff64748B),
                                  fontFamily: 'Vazirmatn',
                                ),
                              ),
                            ],
                          ),
                          textDirection: TextDirection.rtl,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Color _resolveColor(double? p) {
    if (p == null) return const Color(0xff94A3B8);
    if (p >= 75) return const Color(0xff10B981); // High green/emerald
    if (p >= 45) return const Color(0xffF59E0B); // Medium amber/gold
    return const Color(0xffF97316); // Low coral/orange
  }
}

class _EnergyDialArcPainter extends CustomPainter {
  _EnergyDialArcPainter({
    required this.percentage,
    required this.isDarkMode,
    required this.hasValue,
    required this.activeColor,
  });

  final double percentage;
  final bool isDarkMode;
  final bool hasValue;
  final Color activeColor;

  static const double _startAngle = math.pi * 0.85; // 153°
  static const double _totalSweep = math.pi * 1.30; // 234°

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 4.5;
    final arcRect = Rect.fromCircle(center: center, radius: radius);

    const strokeWidth = 3.5;

    // 1. Draw Full Background Track
    final trackPaint = Paint()
      ..color = isDarkMode
          ? Colors.white.withValues(alpha: 0.10)
          : Colors.black.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(arcRect, _startAngle, _totalSweep, false, trackPaint);

    if (!hasValue) return;

    // 2. Active Sweeping Gradient Arc
    final currentSweep = _totalSweep * (percentage / 100.0).clamp(0.01, 1.0);

    // Multi-stop rainbow/energy gradient
    const gradient = SweepGradient(
      startAngle: _startAngle,
      endAngle: _startAngle + _totalSweep,
      colors: [
        Color(0xff06B6D4), // Cyan
        Color(0xff10B981), // Mint green
        Color(0xffFBBF24), // Amber yellow
        Color(0xffF97316), // Coral orange
        Color(0xffEF4444), // Rose red
      ],
      stops: [0.0, 0.28, 0.58, 0.84, 1.0],
    );

    // Glow under active arc
    final glowPaint = Paint()
      ..shader = gradient.createShader(arcRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 2.5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);

    canvas.drawArc(arcRect, _startAngle, currentSweep, false, glowPaint);

    // Crisp active arc
    final activePaint = Paint()
      ..shader = gradient.createShader(arcRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(arcRect, _startAngle, currentSweep, false, activePaint);

    // 3. Floating Thumb Pin on the Arc
    final thumbAngle = _startAngle + currentSweep;
    final thumbCenter = Offset(
      center.dx + radius * math.cos(thumbAngle),
      center.dy + radius * math.sin(thumbAngle),
    );

    // Thumb Drop Shadow
    final thumbShadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: isDarkMode ? 0.45 : 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    canvas.drawCircle(thumbCenter + const Offset(0, 1.2), 5.2, thumbShadowPaint);

    // Thumb Outer White/Metallic Body
    final thumbOuterPaint = Paint()
      ..color = isDarkMode ? const Color(0xffF1F5F9) : Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(thumbCenter, 5.0, thumbOuterPaint);

    // Thumb Inner Accent Core
    final thumbCorePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(thumbCenter, 2.0, thumbCorePaint);
  }

  @override
  bool shouldRepaint(covariant _EnergyDialArcPainter oldDelegate) {
    return oldDelegate.percentage != percentage ||
        oldDelegate.isDarkMode != isDarkMode ||
        oldDelegate.hasValue != hasValue ||
        oldDelegate.activeColor != activeColor;
  }
}
