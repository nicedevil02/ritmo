import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/ux/ritmo_pressable.dart';

/// یک سنجهٔ کوتاه در کارت «نبض امروز».
@immutable
class HomePulseMetric {
  const HomePulseMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
}

/// کارت «نبض امروز»: حلقهٔ پیشرفت مسیر روز در کنار سنجه‌های کلیدی،
/// تا کاربر بدون رفتن به صفحهٔ دیگر بداند امروز کجاست.
///
/// طراحی نئومورفیک (Neumorphic) در حالت روشن؛ شیشه‌ای/تیره در حالت دارک.
class HomePulseStrip extends StatelessWidget {
  const HomePulseStrip({
    super.key,
    required this.progress,
    required this.doneCount,
    required this.totalCount,
    required this.metrics,
    this.title = 'نبض امروز',
    this.caption,
    this.onMenuTap,
  });

  /// نسبت پیشرفت (۰ تا ۱).
  final double progress;
  final int doneCount;
  final int totalCount;
  final List<HomePulseMetric> metrics;
  final String title;
  final String? caption;
  final VoidCallback? onMenuTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final clamped = progress.clamp(0.0, 1.0).toDouble();

    // ─── رنگ‌های نئومورفیک ───
    final neumorphBg = isDark
        ? colors.card.withValues(alpha: 0.50)
        : const Color(0xFFE3E6EC);
    final shadowLight = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : const Color(0xFFFBFBFD);
    final shadowDark = isDark
        ? Colors.black.withValues(alpha: 0.40)
        : const Color(0xFFBCC3CF);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: RitmoSpacing.lg,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: neumorphBg,
        border: isDark
            ? Border.all(color: colors.border.withValues(alpha: 0.7))
            : null,
        boxShadow: isDark
            ? RitmoElevation.none
            : [
                BoxShadow(
                  color: shadowLight,
                  offset: const Offset(-6, -6),
                  blurRadius: 16,
                ),
                BoxShadow(
                  color: shadowDark,
                  offset: const Offset(6, 6),
                  blurRadius: 16,
                ),
              ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── ستون راست (RTL): عنوان + متریک‌ها ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // هدر: عنوان + منو (۳ نقطه پشت نبض امروز)
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Vazirmatn',
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _menuDots(colors, isDark),
                  ],
                ),
                const SizedBox(height: 6),
                // متریک‌ها
                for (int i = 0; i < metrics.length; i++) ...[
                  if (i > 0) const SizedBox(height: 4.5),
                  _neumorphicMetricRow(context, colors, isDark, metrics[i]),
                ],
              ],
            ),
          ),
          const SizedBox(width: RitmoSpacing.md),

          // ── ستون چپ (RTL): حلقه ──
          _neumorphicRing(context, colors, isDark, clamped),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // دکمه سه‌نقطه منو
  // ─────────────────────────────────────────────────────────────

  Widget _menuDots(RitmoColors colors, bool isDark) {
    final dotColor = colors.textTertiary;
    final bg = isDark
        ? colors.surfaceSunken.withValues(alpha: 0.4)
        : const Color(0xFFD8DCE3);

    Widget dots = Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
        border: isDark
            ? null
            : Border.all(
                color: Colors.white.withValues(alpha: 0.8),
                width: 0.6,
              ),
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0xFFFBFBFD),
                  offset: Offset(-1.5, -1.5),
                  blurRadius: 3,
                ),
                BoxShadow(
                  color: Color(0xFFB8C0CD),
                  offset: Offset(1.5, 1.5),
                  blurRadius: 3,
                ),
              ],
      ),
      child: Center(
        child: Icon(
          CupertinoIcons.ellipsis,
          size: 13,
          color: dotColor,
        ),
      ),
    );

    if (onMenuTap != null) {
      dots = GestureDetector(onTap: onMenuTap, child: dots);
    }

    return dots;
  }

  // ─────────────────────────────────────────────────────────────
  // حلقه پیشرفت نئومورفیک
  // ─────────────────────────────────────────────────────────────

  Widget _neumorphicRing(
    BuildContext context,
    RitmoColors colors,
    bool isDark,
    double value,
  ) {
    const ringSize = 108.0;
    const innerSize = 68.0;

    // رنگ‌های حلقه بنفش/لاوندر
    const ringColors = <Color>[
      Color(0xFFCDBBF0), // لاوندر روشن — شروع
      Color(0xFF8B6FD6), // بنفش تیره — پایان
    ];

    return SizedBox(
      height: ringSize,
      width: ringSize,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: value),
        duration: RitmoMotion.reduceMotion(context)
            ? Duration.zero
            : const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, animated, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // ── حلقه ترک (نئومورفیک inset) ──
              Container(
                width: ringSize,
                height: ringSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? colors.surfaceSunken.withValues(alpha: 0.5)
                      : const Color(0xFFDDE0E6),
                  boxShadow: isDark
                      ? null
                      : [
                          // سایه داخلی (شبیه‌سازی inset با inner shadow)
                          const BoxShadow(
                            color: Color(0xFFA8ADB7),
                            offset: Offset(4, 4),
                            blurRadius: 8,
                          ),
                          const BoxShadow(
                            color: Color(0xFFF5F7FA),
                            offset: Offset(-4, -4),
                            blurRadius: 8,
                          ),
                        ],
                ),
              ),
              // ── آرک پیشرفت + نقطه درخشان ──
              CustomPaint(
                size: const Size(ringSize, ringSize),
                painter: _NeumorphicPulseRingPainter(
                  progress: animated,
                  trackColor: isDark
                      ? colors.surfaceSunken.withValues(alpha: 0.9)
                      : const Color(0xFFD5D8DE),
                  ringColors: ringColors,
                  isDark: isDark,
                ),
              ),
              // ── دایره مرکزی برجسته ──
              Container(
                width: innerSize,
                height: innerSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? colors.surface.withValues(alpha: 0.6)
                      : const Color(0xFFE4E7ED),
                  boxShadow: isDark
                      ? null
                      : [
                          const BoxShadow(
                            color: Color(0xFFF9FBFF),
                            offset: Offset(-3, -3),
                            blurRadius: 6,
                          ),
                          const BoxShadow(
                            color: Color(0xFFBCC1CA),
                            offset: Offset(3, 3),
                            blurRadius: 6,
                          ),
                        ],
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        toPersianDigits('${(animated * 100).round()}٪'),
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Vazirmatn',
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        toPersianDigits('از ۱۰۰'),
                        style: TextStyle(
                          fontSize: 10,
                          fontFamily: 'Vazirmatn',
                          color: colors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // ردیف متریک نئومورفیک
  // ─────────────────────────────────────────────────────────────

  Widget _neumorphicMetricRow(
    BuildContext context,
    RitmoColors colors,
    bool isDark,
    HomePulseMetric metric,
  ) {
    final row = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        color: isDark ? colors.surfaceSunken.withValues(alpha: 0.3) : null,
        gradient: isDark
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF3F6FA),
                  Color(0xFFE5E9F0),
                ],
              ),
        border: Border.all(
          color: isDark
              ? colors.border.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.85),
          width: 0.7,
        ),
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(
                  color: Color(0xFFFFFFFF),
                  offset: Offset(-2, -2),
                  blurRadius: 4,
                ),
                BoxShadow(
                  color: Color(0xFFB8C0CD),
                  offset: Offset(2, 2.5),
                  blurRadius: 5,
                ),
              ],
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Row(
          children: [
            // آیکن نئومورفیک ۳ بعدی (اسکویرکل پیلو)
            Container(
              height: 24,
              width: 24,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7.5),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    metric.color.withValues(alpha: 0.28),
                    metric.color.withValues(alpha: 0.14),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.75),
                  width: 0.6,
                ),
                boxShadow: isDark
                    ? null
                    : [
                        const BoxShadow(
                          color: Colors.white,
                          offset: Offset(-1, -1),
                          blurRadius: 2,
                        ),
                        BoxShadow(
                          color: metric.color.withValues(alpha: 0.35),
                          offset: const Offset(1, 1.5),
                          blurRadius: 3,
                        ),
                      ],
              ),
              child: Center(
                child: Icon(metric.icon, size: 12, color: metric.color),
              ),
            ),
            const SizedBox(width: 7),
            // لیبل
            Text(
              metric.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFamily: 'Vazirmatn',
                color: colors.textSecondary,
              ),
            ),
            const Spacer(),
            // مقدار
            Text(
              toPersianDigits(metric.value),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                fontFamily: 'Vazirmatn',
                color: colors.textPrimary,
              ),
            ),
            if (metric.onTap != null) ...[
              const SizedBox(width: 2),
              Icon(
                CupertinoIcons.chevron_left,
                size: 9.5,
                color: colors.textTertiary,
              ),
            ],
          ],
        ),
      ),
    );

    if (metric.onTap == null) return row;

    return RitmoPressable(
      onTap: metric.onTap,
      semanticLabel: '${metric.label}: ${metric.value}',
      scaleDown: 0.98,
      child: row,
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// CustomPainter — آرک پیشرفت نئومورفیک با نقطه درخشان
// ═══════════════════════════════════════════════════════════════

class _NeumorphicPulseRingPainter extends CustomPainter {
  const _NeumorphicPulseRingPainter({
    required this.progress,
    required this.trackColor,
    required this.ringColors,
    required this.isDark,
  });

  final double progress;
  final Color trackColor;
  final List<Color> ringColors;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 10.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - stroke) / 2;

    // ── ترک (track) ──
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    canvas.drawCircle(center, radius, track);

    if (progress <= 0) return;

    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
    final rect = Rect.fromCircle(center: center, radius: radius);

    // ── آرک گرادیان بنفش ──
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: ringColors,
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect);

    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweepAngle,
      false,
      arc,
    );

    // ── نقطه درخشان در سر آرک ──
    final tipAngle = -math.pi / 2 + sweepAngle;
    final tipX = center.dx + radius * math.cos(tipAngle);
    final tipY = center.dy + radius * math.sin(tipAngle);

    // هاله بیرونی (glow)
    final glow = Paint()
      ..color = ringColors.last.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(Offset(tipX, tipY), 7, glow);

    // نقطه سفید مرکزی
    final dot = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(tipX, tipY), 4.5, dot);
  }

  @override
  bool shouldRepaint(covariant _NeumorphicPulseRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.isDark != isDark;
  }
}
