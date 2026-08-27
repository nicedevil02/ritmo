// C-43, C-44: CycleAnimatedBackground, RitmoSheetGlassCard, CycleProgressRingPainter
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

class CycleAnimatedBackground extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final colors = context.colors;
    Color targetPrimary;
    Color targetSecondary;
    Color targetTertiary;
    final Color baseBgColor = isDark ? colors.bg : colors.surface;

    if (isPregnancy || phase == CyclePhase.pregnancy) {
      targetPrimary = colors.primary;
      targetSecondary = colors.accent;
      targetTertiary = colors.warning;
    } else {
      switch (phase) {
        case CyclePhase.menstrual:
          targetPrimary = colors.error;
          targetSecondary = colors.primary;
          targetTertiary = colors.accent;
        case CyclePhase.follicular:
          targetPrimary = colors.accent;
          targetSecondary = colors.primary;
          targetTertiary = colors.accent.withValues(alpha: 0.7);
        case CyclePhase.ovulation:
          targetPrimary = colors.accent;
          targetSecondary = colors.warning;
          targetTertiary = colors.primary;
        case CyclePhase.luteal:
          targetPrimary = colors.primary;
          targetSecondary = colors.accent;
          targetTertiary = colors.primary;
        case CyclePhase.pregnancy:
        case CyclePhase.dataStale:
        case CyclePhase.noData:
          targetPrimary = colors.accent;
          targetSecondary = colors.primary;
          targetTertiary = colors.accent;
      }
    }

    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOutCubic,
        key: ValueKey('${phase}_${isPregnancy}_$isDark'),
        builder: (context, colorProgress, _) {
          return CustomPaint(
            size: Size.infinite,
            painter: _AuroraMeshPainter(
              progress: 0.0,
              primaryColor: targetPrimary,
              secondaryColor: targetSecondary,
              tertiaryColor: targetTertiary,
              baseBgColor: baseBgColor,
              isDark: isDark,
            ),
          );
        },
      ),
    );
  }
}

/// شفق قطبی بومی سخت‌افزاری (Native GPU Mesh Aurora)
/// رندر مستقیم با شیدرهای گرادیان شعاعی و حالت درخشش Screen روی GPU
class _AuroraMeshPainter extends CustomPainter {
  const _AuroraMeshPainter({
    required this.progress,
    required this.primaryColor,
    required this.secondaryColor,
    required this.tertiaryColor,
    required this.baseBgColor,
    required this.isDark,
  });

  final double progress;
  final Color primaryColor;
  final Color secondaryColor;
  final Color tertiaryColor;
  final Color baseBgColor;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final maxDim = math.max(size.width, size.height);

    // ۱. رنگ زمینه یکدست بومی
    canvas.drawRect(rect, Paint()..color = baseBgColor);

    final angle = progress * 2 * math.pi;

    // ۲. کانون اصلی نور (هاله بالای صفحه / هدر وضعیت)
    final pCenter = Offset(
      size.width * (0.65 + 0.22 * math.sin(angle)),
      size.height * (0.16 + 0.12 * math.cos(angle)),
    );
    final pRadius = maxDim * (0.58 + 0.08 * math.sin(angle * 1.4));
    final pShader = RadialGradient(
      center: Alignment(
        (pCenter.dx / size.width) * 2 - 1,
        (pCenter.dy / size.height) * 2 - 1,
      ),
      radius: pRadius / size.width,
      colors: [
        primaryColor.withValues(alpha: isDark ? 0.50 : 0.32),
        primaryColor.withValues(alpha: isDark ? 0.24 : 0.15),
        primaryColor.withValues(alpha: 0.0),
      ],
      stops: const [0.0, 0.45, 1.0],
    ).createShader(rect);
    final pPaint = Paint()
      ..shader = pShader
      ..blendMode = isDark ? BlendMode.screen : BlendMode.srcOver;
    canvas.drawRect(rect, pPaint);

    // ۳. کانون دوم نور (هاله میانی/پایین سمت چپ)
    final sCenter = Offset(
      size.width * (0.30 + 0.20 * math.cos(angle + 0.6)),
      size.height * (0.68 + 0.14 * math.sin(angle + 0.6)),
    );
    final sRadius = maxDim * (0.62 + 0.09 * math.cos(angle * 1.2));
    final sShader = RadialGradient(
      center: Alignment(
        (sCenter.dx / size.width) * 2 - 1,
        (sCenter.dy / size.height) * 2 - 1,
      ),
      radius: sRadius / size.width,
      colors: [
        secondaryColor.withValues(alpha: isDark ? 0.45 : 0.28),
        secondaryColor.withValues(alpha: isDark ? 0.21 : 0.12),
        secondaryColor.withValues(alpha: 0.0),
      ],
      stops: const [0.0, 0.48, 1.0],
    ).createShader(rect);
    final sPaint = Paint()
      ..shader = sShader
      ..blendMode = isDark ? BlendMode.screen : BlendMode.srcOver;
    canvas.drawRect(rect, sPaint);

    // ۴. کانون سوم اتمسفری (عمق و پیوند رنگی میانی)
    final tCenter = Offset(
      size.width * (0.75 + 0.18 * math.cos(angle * 0.9 + 2.2)),
      size.height * (0.44 + 0.14 * math.sin(angle * 0.9 + 2.2)),
    );
    final tRadius = maxDim * (0.48 + 0.07 * math.sin(angle * 0.8));
    final tShader = RadialGradient(
      center: Alignment(
        (tCenter.dx / size.width) * 2 - 1,
        (tCenter.dy / size.height) * 2 - 1,
      ),
      radius: tRadius / size.width,
      colors: [
        tertiaryColor.withValues(alpha: isDark ? 0.38 : 0.24),
        tertiaryColor.withValues(alpha: isDark ? 0.15 : 0.08),
        tertiaryColor.withValues(alpha: 0.0),
      ],
      stops: const [0.0, 0.45, 1.0],
    ).createShader(rect);
    final tPaint = Paint()
      ..shader = tShader
      ..blendMode = isDark ? BlendMode.screen : BlendMode.srcOver;
    canvas.drawRect(rect, tPaint);
  }

  @override
  bool shouldRepaint(covariant _AuroraMeshPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor ||
        oldDelegate.tertiaryColor != tertiaryColor ||
        oldDelegate.baseBgColor != baseBgColor ||
        oldDelegate.isDark != isDark;
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
