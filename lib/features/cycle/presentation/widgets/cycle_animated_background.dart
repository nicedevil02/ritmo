// C-43, C-44: CycleAnimatedBackground, RitmoSheetGlassCard, CycleProgressRingPainter
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

class CycleAnimatedBackground extends StatefulWidget {
  const CycleAnimatedBackground({
    super.key,
    required this.phase,
    required this.isDark,
    this.isPregnancy = false,
  });

  final CyclePhase phase;
  final bool isDark;
  final bool isPregnancy;

  @override
  State<CycleAnimatedBackground> createState() =>
      _CycleAnimatedBackgroundState();
}

class _CycleAnimatedBackgroundState extends State<CycleAnimatedBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Color primaryColor;
    Color secondaryColor;
    Color tertiaryColor;
    Color baseBgColor;

    if (widget.isPregnancy) {
      primaryColor = colors.primary.withValues(alpha: 0.85);
      secondaryColor = colors.accent.withValues(alpha: 0.80);
      tertiaryColor = colors.warning.withValues(alpha: 0.75);
    } else {
      switch (widget.phase) {
        case CyclePhase.menstrual:
          primaryColor = colors.error.withValues(alpha: 0.85);
          secondaryColor = colors.primary.withValues(alpha: 0.80);
          tertiaryColor = colors.primary.withValues(alpha: 0.65);
        case CyclePhase.ovulation:
          primaryColor = colors.accent.withValues(alpha: 0.85);
          secondaryColor = colors.accent.withValues(alpha: 0.60);
          tertiaryColor = colors.primary.withValues(alpha: 0.75);
        case CyclePhase.luteal:
          primaryColor = colors.primary.withValues(alpha: 0.85);
          secondaryColor = colors.warning.withValues(alpha: 0.80);
          tertiaryColor = colors.accent.withValues(alpha: 0.75);
        case CyclePhase.follicular:
        default:
          primaryColor = colors.accent.withValues(alpha: 0.85);
          secondaryColor = colors.primary.withValues(alpha: 0.80);
          tertiaryColor = colors.accent.withValues(alpha: 0.65);
      }
    }

    baseBgColor = colors.surface;

    return Stack(
      children: [
        // 1. Solid base background
        Positioned.fill(child: Container(color: baseBgColor)),

        // 2. Glowing Colored Floating Blobs underneath glass
        // Blob 1 (Top-Left)
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final angle = _controller.value * 2 * math.pi;
            final dx = math.sin(angle) * 70;
            final dy = math.cos(angle) * 90;
            return Positioned(top: 80 + dy, left: -40 + dx, child: child!);
          },
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              color: primaryColor,
              shape: BoxShape.circle,
            ),
          ),
        ),

        // Blob 2 (Bottom-Right)
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final angle = _controller.value * 2 * math.pi + math.pi;
            final dx = math.sin(angle) * 80;
            final dy = math.cos(angle) * 70;
            return Positioned(bottom: 120 + dy, right: -50 + dx, child: child!);
          },
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              color: secondaryColor,
              shape: BoxShape.circle,
            ),
          ),
        ),

        // Blob 3 (Top-Right)
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final angle = _controller.value * 2 * math.pi;
            final dx = math.cos(angle * 1.2) * 60;
            final dy = math.sin(angle * 1.2) * 50;
            return Positioned(top: 220 + dy, right: -40 + dx, child: child!);
          },
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              color: tertiaryColor,
              shape: BoxShape.circle,
            ),
          ),
        ),

        // Blob 4 (Bottom-Left)
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final angle = _controller.value * 2 * math.pi + math.pi / 2;
            final dx = math.cos(angle * 0.8) * 50;
            final dy = math.sin(angle * 0.8) * 80;
            return Positioned(bottom: 220 + dy, left: -50 + dx, child: child!);
          },
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.65),
              shape: BoxShape.circle,
            ),
          ),
        ),

        // 3. Full-screen Blur & Glass Pane Overlay
        Positioned.fill(
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
              child: Container(
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? colors.surface.withValues(alpha: 0.50)
                      : Colors.white.withValues(alpha: 0.35),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class RitmoSheetGlassCard extends StatelessWidget {
  const RitmoSheetGlassCard({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = context.colors;

    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.08 : 0.03),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: colors.surfaceElevated.withValues(
                alpha: isDark ? 0.85 : 0.92,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              border: Border(
                top: BorderSide(color: colors.border, width: 1.5),
                left: BorderSide(color: colors.border, width: 1.5),
                right: BorderSide(color: colors.border, width: 1.5),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class CycleProgressRingPainter extends CustomPainter {
  CycleProgressRingPainter({
    required this.percentage,
    required this.activeColor,
    required this.isDark,
  });

  final double percentage;
  final Color activeColor;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 7;
    const strokeWidth = 8.5;

    // Background track with subtle depth
    final paintBg = Paint()
      ..color = activeColor.withValues(alpha: isDark ? 0.18 : 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, paintBg);

    if (percentage <= 0) return;

    // Active sweep arc
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paintActive = Paint()
      ..shader = SweepGradient(
        colors: [
          activeColor.withValues(alpha: 0.30),
          activeColor.withValues(alpha: 0.85),
          activeColor,
        ],
        stops: const [0.0, 0.6, 1.0],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    final sweepAngle = 2 * math.pi * percentage;
    canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, paintActive);

    // Multi-layer Apple Glow indicator at the thumb
    final thumbAngle = -math.pi / 2 + sweepAngle;
    final thumbX = center.dx + radius * math.cos(thumbAngle);
    final thumbY = center.dy + radius * math.sin(thumbAngle);
    final thumbCenter = Offset(thumbX, thumbY);

    // 1. Outer diffuse glow
    final outerGlowPaint = Paint()
      ..color = activeColor.withValues(alpha: isDark ? 0.70 : 0.50)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(thumbCenter, 10, outerGlowPaint);

    // 2. Mid vibrant rim
    final midRimPaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(thumbCenter, 5.5, midRimPaint);

    // 3. Crisp white center core
    final corePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(thumbCenter, 3.8, corePaint);
  }

  @override
  bool shouldRepaint(covariant CycleProgressRingPainter oldDelegate) {
    return oldDelegate.percentage != percentage ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.isDark != isDark;
  }
}
