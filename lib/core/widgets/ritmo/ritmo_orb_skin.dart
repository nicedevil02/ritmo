// =============================================================================
//  Ritmo Orb Skin — شیشه، لبه و هایلایت
//  همهٔ نورها از یک [RitmoLightRig] می‌آیند و سفیدها از یک [RitmoWhitePurse]
//  خرج می‌شوند؛ پس دیگر ممکن نیست بالا-چپِ تیله شیری شود.
// =============================================================================

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_orb_types.dart';

const List<Color> _kGlassDark = <Color>[
  Color(0xFFFDFDFF),
  Color(0xFFE4E8F2),
  Color(0xFFAEB6C8),
  Color(0xFF666F86),
];

const List<Color> _kGlassLight = <Color>[
  Color(0xFFFFFFFF),
  Color(0xFFFEFAFA),
  Color(0xFFF2EEF4),
  Color(0xFFDBD6E2),
];

/// بدنهٔ شیشهٔ مرواریدی. یک گرادیان، بدون blur.
void ritmoPaintGlassBody(
  Canvas canvas, {
  required Offset center,
  required double radius,
  required RitmoLightRig rig,
  required bool isDark,
  required RitmoOrbTier tier,
}) {
  final Rect sphere = Rect.fromCircle(center: center, radius: radius);
  final Paint base = Paint()
    ..shader = RadialGradient(
      center: rig.keyAlign,
      radius: 0.98,
      colors: isDark ? _kGlassDark : _kGlassLight,
      stops: const <double>[0.0, 0.42, 0.78, 1.0],
    ).createShader(sphere);
  canvas.drawCircle(center, radius, base);
  ritmoCountPaint();

  if (tier == RitmoOrbTier.s) return;

  // زمینِ تاریکِ کره — مقابلِ نور، همان‌جا که باید باشد.
  final Color shade = isDark ? const Color(0xFF17021F) : const Color(0xFF6B5F74);
  final Paint ground = Paint()
    ..shader = RadialGradient(
      center: rig.groundAlign,
      radius: 1.0,
      colors: <Color>[
        const Color(0x00000000),
        const Color(0x00000000),
        shade.withValues(alpha: rig.ground),
      ],
      stops: const <double>[0.0, 0.62, 1.0],
    ).createShader(sphere);
  canvas.drawCircle(center, radius, ground);
  ritmoCountPaint();
}

/// موجِ درونِ تیله — چینی از رنگ که مثلِ پارچه‌ای در آب تاب می‌خورد.
///
/// دو لبهٔ سینوسی یک نوار می‌سازند: نوار با گرادیانِ عمودی پر می‌شود و یک
/// تاجِ سفیدِ نازک روی لبهٔ بالایی می‌نشیند. همین تاج است که به چشم می‌گوید
/// این یک حجم است، نه یک لکه.
///
/// شکلِ موج از امضای حرکت می‌آید: [amplitude] بلندیِ چین، [folds] تعدادِ
/// چین‌ها، [thickness] قطرِ نوار. پس هر حالِ تیله موجِ خودش را دارد.
void ritmoPaintWave(
  Canvas canvas, {
  required Offset center,
  required double radius,
  required RitmoOrbPalette palette,
  required RitmoLightRig rig,
  required RitmoOrbTier tier,
  required RitmoWhitePurse purse,
  required double phase,
  required double amplitude,
  required double folds,
  required double thickness,
  required double intensity,
  required bool isDark,
}) {
  // در ۱۹ پیکسل، موج فقط یک خطِ لرزان است؛ نمی‌کشیمش.
  if (tier == RitmoOrbTier.s || radius <= 1.0) return;

  final int samples = tier == RitmoOrbTier.l ? 26 : 16;
  final double amp = radius * (0.10 + 0.16 * amplitude.clamp(0.0, 1.4));
  final double band = radius * (0.30 + 0.26 * thickness.clamp(0.0, 1.2));
  final double fold = folds.clamp(0.6, 3.0);
  final double tilt = -0.16 + 0.10 * math.sin(phase * 0.31);
  final double mid = center.dy + radius * 0.05 * math.sin(phase * 0.23);

  final List<Offset> upper = <Offset>[];
  final List<Offset> lower = <Offset>[];
  for (int i = 0; i <= samples; i++) {
    final double t = i / samples;
    final double x = center.dx + (t * 2.0 - 1.0) * radius * 1.18;
    final double y = mid +
        math.sin(t * math.pi * 2.0 * fold + phase) * amp +
        math.sin(t * math.pi * 2.0 * fold * 0.5 - phase * 0.62) * amp * 0.42;
    // نوار در میانه قطورتر است؛ دو سرش نازک می‌شود و در شیشه گم.
    final double taper = 0.34 + 0.66 * math.sin(t * math.pi);
    upper.add(Offset(x, y - band * 0.5 * taper));
    lower.add(Offset(x, y + band * 0.5 * taper));
  }

  final Path crestPath = Path()..addPolygon(upper, false);
  final Path shape = Path()..addPolygon(upper, false);
  for (int i = lower.length - 1; i >= 0; i--) {
    shape.lineTo(lower[i].dx, lower[i].dy);
  }
  shape.close();

  final Rect sphere = Rect.fromCircle(center: center, radius: radius);
  final double a =
      ((isDark ? 0.68 : 0.60) + 0.30 * intensity).clamp(0.0, 1.0);

  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.rotate(tilt);
  canvas.translate(-center.dx, -center.dy);

  if (tier == RitmoOrbTier.l) {
    // هالهٔ نرمِ زیرِ موج: رنگ از پشتِ شیشه در می‌آید، نه روی آن.
    canvas.drawPath(
      shape,
      Paint()
        ..color = palette.hot.withValues(alpha: 0.24 * a)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.16),
    );
    ritmoCountPaint(blurs: 1);
  }

  canvas.drawPath(
    shape,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          palette.milk.withValues(alpha: 0.30 * a),
          palette.hot.withValues(alpha: 0.92 * a),
          palette.hot.withValues(alpha: 0.72 * a),
          palette.violet.withValues(alpha: 0.34 * a),
        ],
        stops: const <double>[0.0, 0.34, 0.68, 1.0],
      ).createShader(sphere),
  );
  ritmoCountPaint();

  final double crest = purse.take(0.14 * (0.5 + 0.5 * rig.key));
  if (crest > 0.02) {
    canvas.drawPath(
      crestPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(0.8, radius * 0.035)
        ..color = const Color(0xFFFFFFFF).withValues(alpha: crest),
    );
    ritmoCountPaint(white: crest);
  }

  canvas.restore();
}

/// هایلایتِ اصلیِ شیشه + نقطهٔ نور. هر دو از کیفِ سفید خرج می‌کنند.
void ritmoPaintSheen(
  Canvas canvas, {
  required Offset center,
  required double radius,
  required RitmoLightRig rig,
  required RitmoWhitePurse purse,
  required RitmoOrbTier tier,
  required bool allowSpecular,
}) {
  final Rect sphere = Rect.fromCircle(center: center, radius: radius);
  final double sheen = purse.take(0.30 * rig.key);
  if (sheen > 0.01) {
    final Paint paint = Paint()
      ..shader = RadialGradient(
        center: Alignment(rig.dir.dx * 1.28, rig.dir.dy * 1.28),
        radius: 0.58,
        colors: <Color>[
          const Color(0xFFFFFFFF).withValues(alpha: sheen),
          const Color(0xFFFFFFFF).withValues(alpha: sheen * 0.28),
          const Color(0x00FFFFFF),
        ],
        stops: const <double>[0.0, 0.42, 1.0],
      ).createShader(sphere);
    canvas.drawCircle(center, radius, paint);
    ritmoCountPaint(white: sheen);
  }

  if (!allowSpecular || tier != RitmoOrbTier.l) return;

  // بازتابِ نقطه‌ایِ منبعِ نور: کوچک، تیز، و فقط وقتی تیله مطمئن است.
  final double dot = purse.take(0.26);
  if (dot <= 0.01) return;
  canvas.save();
  canvas.translate(
    center.dx + rig.dir.dx * radius * 1.06,
    center.dy + rig.dir.dy * radius * 1.06,
  );
  canvas.rotate(rig.angle + math.pi / 2.0);
  final Paint hotSpot = Paint()
    ..color = const Color(0xFFFFFFFF).withValues(alpha: dot)
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.05);
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset.zero,
      width: radius * 0.30,
      height: radius * 0.17,
    ),
    hotSpot,
  );
  canvas.restore();
  ritmoCountPaint(blurs: 1, white: dot);
}

/// لبهٔ تیله. روشناییِ لبه بخشی از امضای حالت است، پس در سیاه‌وسفید هم خوانده
/// می‌شود.
void ritmoPaintRim(
  Canvas canvas, {
  required Offset center,
  required double radius,
  required RitmoOrbPalette palette,
  required RitmoLightRig rig,
  required RitmoWhitePurse purse,
  required RitmoOrbTier tier,
  required bool isDark,
  required double brightness,
}) {
  final Rect sphere = Rect.fromCircle(center: center, radius: radius);
  final double lit = (rig.rim * brightness).clamp(0.0, 1.0);

  if (tier == RitmoOrbTier.l) {
    final double frost = purse.take(0.16 * lit);
    if (frost > 0.01) {
      final Paint paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, radius * 0.075)
        ..color = const Color(0xFFFFFFFF).withValues(alpha: frost)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.07);
      canvas.drawCircle(center, radius * 0.985, paint);
      ritmoCountPaint(blurs: 1, white: frost);
    }
  }

  final double w = math.max(0.7, radius * 0.030);
  final Paint rim = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..shader = SweepGradient(
      colors: <Color>[
        const Color(0xFFFFFFFF).withValues(alpha: 0.82 * lit),
        const Color(0xFFFFFFFF).withValues(alpha: 0.14 * lit),
        palette.aura.withValues(alpha: 0.30 * lit),
        const Color(0xFFFFFFFF).withValues(alpha: 0.62 * lit),
        const Color(0xFFFFFFFF).withValues(alpha: 0.82 * lit),
      ],
      stops: const <double>[0.0, 0.28, 0.52, 0.84, 1.0],
      // قوسِ روشن دقیقاً سمتِ نور می‌نشیند.
      transform: GradientRotation(rig.angle - math.pi * 0.12),
    ).createShader(sphere);
  canvas.drawCircle(center, radius - w / 2.0, rim);
  ritmoCountPaint();
}
