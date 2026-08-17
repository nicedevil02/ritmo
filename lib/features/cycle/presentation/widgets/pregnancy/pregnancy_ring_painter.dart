import 'dart:math' as math;
import 'package:flutter/material.dart';

class PregnancyRingPainter extends CustomPainter {
  PregnancyRingPainter({required this.percentage, required this.colors});

  final double percentage;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const strokeWidth = 10.0;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final paintBg = Paint()
      ..color = colors.first.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, paintBg);

    final gradient = SweepGradient(
      colors: colors,
      startAngle: -math.pi / 2,
      endAngle: 3 * math.pi / 2,
    );

    final paintFg = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * percentage;
    canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, paintFg);
  }

  @override
  bool shouldRepaint(covariant PregnancyRingPainter oldDelegate) {
    return oldDelegate.percentage != percentage || oldDelegate.colors != colors;
  }
}
