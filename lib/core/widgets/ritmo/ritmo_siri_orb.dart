// =============================================================================
//  Ritmo Siri Orb — «حباب تفکر» هوش مصنوعی ریتمو
//
//  تیلهٔ شیشه‌ای با جریان زندهٔ رنگ در درون: توده‌های مرجانی → سرخابی →
//  یاسی می‌چرخند، لبه‌ها بیشتر وقت‌ها نرم و بالشتی‌اند و هر چند لحظه
//  تیز و ابریشمی می‌شوند — دقیقاً همان حسی که در فریم‌های مرجع بود.
//
//  ▸ ۱۱ لایهٔ نقاشی روی یک CustomPainter (بدون شیدر خارجی، بدون پکیج اضافه)
//  ▸ فرم‌ها از نویز value/fbm ساخته می‌شوند؛ پس حرکت هیچ‌وقت دقیقاً تکرار نمی‌شود
//  ▸ Ticker با فاز پیوسته: عوض شدن حالت (idle → thinking → streaming) نرم و بی پرش
//  ▸ API قبلی کامل حفظ شده؛ پارامترهای جدید همه اختیاری‌اند
// =============================================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;

/// حالت‌های عملکرد گوی هوشمند ریتمو
enum RitmoOrbMode {
  /// حالت آماده‌باش، تنفس ملایم و جریان آرام رنگ
  idle,

  /// حالت تفکر، تحلیل ابزارها و برنامه‌ریزی
  thinking,

  /// حالت تولید زندهٔ متن و استریم پاسخ (تپش‌های نوری تندتر)
  streaming,

  /// حالت جمع‌وجور برای نوار وضعیت و تراشه‌ها
  compact,
}

/// سرویس مدیریت وضعیت زندهٔ هوش مصنوعی ریتمو برای هماهنگی با گوی ناوبری
class RitmoAiStateService {
  RitmoAiStateService._();
  static final RitmoAiStateService instance = RitmoAiStateService._();

  final ValueNotifier<RitmoOrbMode> orbMode =
      ValueNotifier<RitmoOrbMode>(RitmoOrbMode.idle);
  final ValueNotifier<int> flareTrigger = ValueNotifier<int>(0);

  void setMode(RitmoOrbMode mode) {
    if (orbMode.value != mode) {
      orbMode.value = mode;
    }
  }

  void triggerSuccessFlare() {
    flareTrigger.value++;
  }
}

/// پالت رنگی درون تیله
@immutable
class RitmoOrbPalette {
  const RitmoOrbPalette({
    required this.hot,
    required this.core,
    required this.mid,
    required this.violet,
    required this.aura,
    required this.milk,
  });

  /// داغ‌ترین نقطهٔ جریان (قلب رنگ)
  final Color hot;

  /// بدنهٔ اصلی جریان
  final Color core;

  /// میانهٔ گرم (هلویی / کهربایی)
  final Color mid;

  /// جریان سرد پشتی (بنفش / یاسی)
  final Color violet;

  /// هالهٔ بیرونی تیله
  final Color aura;

  /// شیشهٔ شیری / بالشت سفید
  final Color milk;

  /// پالت پیش‌فرض: مرجانی – سرخابی – یاس (مطابق فریم‌های مرجع)
  static const RitmoOrbPalette coral = RitmoOrbPalette(
    hot: Color(0xFFFF2D55),
    core: Color(0xFFFF5A6A),
    mid: Color(0xFFFF9E7A),
    violet: Color(0xFFB07CFF),
    aura: Color(0xFFFF7D91),
    milk: Color(0xFFFFF7F7),
  );

  /// پالت سرد: فیروزه‌ای – نیلی – نعنایی
  static const RitmoOrbPalette aurora = RitmoOrbPalette(
    hot: Color(0xFF00D4FF),
    core: Color(0xFF4C8BFF),
    mid: Color(0xFF7BF1C8),
    violet: Color(0xFF8B5CF6),
    aura: Color(0xFF6FD8FF),
    milk: Color(0xFFF4FBFF),
  );

  /// پالت گرم: کهربا – طلایی – مسی
  static const RitmoOrbPalette ember = RitmoOrbPalette(
    hot: Color(0xFFFF6A00),
    core: Color(0xFFFF9500),
    mid: Color(0xFFFFD166),
    violet: Color(0xFFFF4D8D),
    aura: Color(0xFFFFA75C),
    milk: Color(0xFFFFF9F0),
  );

  RitmoOrbPalette copyWith({
    Color? hot,
    Color? core,
    Color? mid,
    Color? violet,
    Color? aura,
    Color? milk,
  }) {
    return RitmoOrbPalette(
      hot: hot ?? this.hot,
      core: core ?? this.core,
      mid: mid ?? this.mid,
      violet: violet ?? this.violet,
      aura: aura ?? this.aura,
      milk: milk ?? this.milk,
    );
  }
}

/// تیلهٔ شیشه‌ای زندهٔ ریتمو
///
/// نمونهٔ ساده:
/// ```dart
/// const RitmoSiriOrb(size: 96, mode: RitmoOrbMode.thinking)
/// ```
class RitmoSiriOrb extends StatefulWidget {
  const RitmoSiriOrb({
    super.key,
    this.size = 42.0,
    this.mode = RitmoOrbMode.idle,
    this.glowEnabled = true,
    this.isAnimated = true,
    this.tiltOffset = Offset.zero,
    this.squeezeFactor = 1.0,
    this.palette = RitmoOrbPalette.coral,
    this.intensity = 1.0,
    this.speed = 1.0,
    this.seed = 11,
  });

  /// قطر کلی گوی (پیش‌فرض: ۴۲ پیکسل)
  final double size;

  /// حالت کاری هوش مصنوعی
  final RitmoOrbMode mode;

  /// آیا هالهٔ نورانی پراکنده فعال باشد؟
  final bool glowEnabled;

  /// آیا انیمیشن فعال باشد؟ (در صورت false بودن، فرم استاتیک نمایش می‌یابد)
  final bool isAnimated;

  /// زاویه شیب پارالاکس لمسی یا ژیروسکوپ (-1.0 تا 1.0)
  final Offset tiltOffset;

  /// ضریب کشسانی مایع هنگام لمس (0.85 تا 1.15)
  final double squeezeFactor;

  /// پالت رنگی درون تیله
  final RitmoOrbPalette palette;

  /// شدت کلی رنگ‌ها (۰ تا ۱؛ مقدارهای کمتر = شیشهٔ رنگ‌پریده‌تر)
  final double intensity;

  /// ضریب سرعت جریان رنگ‌ها
  final double speed;

  /// دانهٔ نویز؛ با تغییرش طرح جریان کاملاً عوض می‌شود
  final int seed;

  @override
  State<RitmoSiriOrb> createState() => _RitmoSiriOrbState();
}

class _RitmoSiriOrbState extends State<RitmoSiriOrb>
    with TickerProviderStateMixin {
  /// فاز پیوستهٔ جریان (واحد: دور)؛ با عوض شدن سرعت هیچ پرشی رخ نمی‌دهد
  final ValueNotifier<double> _phase = ValueNotifier<double>(0.32);

  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  /// انرژی نرم‌شدهٔ حالت‌ها (میان‌یابی میان idle / thinking / streaming)
  late final AnimationController _energy;
  late final AnimationController _flare;

  @override
  void initState() {
    super.initState();

    _energy = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
      value: _energyFor(widget.mode),
    );

    _flare = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );

    _ticker = createTicker(_onTick);
    if (widget.isAnimated) _ticker.start();

    RitmoAiStateService.instance.flareTrigger.addListener(_handleFlareTrigger);
  }

  static double _energyFor(RitmoOrbMode mode) {
    switch (mode) {
      case RitmoOrbMode.idle:
        return 0.26;
      case RitmoOrbMode.thinking:
        return 0.64;
      case RitmoOrbMode.streaming:
        return 1.0;
      case RitmoOrbMode.compact:
        return 0.34;
    }
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1000000.0;
    _lastTick = elapsed;
    if (dt <= 0 || dt > 0.5) return;

    // سرعت بر حسب دور در ثانیه؛ idle حدود ۱۲ ثانیه برای یک دور کامل
    final speed = (0.052 + 0.118 * _energy.value) * widget.speed;
    _phase.value = _phase.value + dt * speed;
  }

  void _handleFlareTrigger() {
    if (mounted && widget.isAnimated) {
      _flare.forward(from: 0.0);
    }
  }

  @override
  void didUpdateWidget(covariant RitmoSiriOrb oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isAnimated != widget.isAnimated) {
      if (widget.isAnimated) {
        _lastTick = Duration.zero;
        if (!_ticker.isActive) _ticker.start();
      } else {
        if (_ticker.isActive) _ticker.stop();
      }
    }

    if (oldWidget.mode != widget.mode) {
      _energy.animateTo(
        _energyFor(widget.mode),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    RitmoAiStateService.instance.flareTrigger
        .removeListener(_handleFlareTrigger);
    _ticker.dispose();
    _energy.dispose();
    _flare.dispose();
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_phase, _energy, _flare]),
        builder: (context, _) {
          return CustomPaint(
            size: Size(widget.size, widget.size),
            isComplex: true,
            willChange: widget.isAnimated,
            painter: _LiquidMarblePainter(
              phase: _phase.value,
              energy: _energy.value,
              flare: _flare.value,
              mode: widget.mode,
              isDark: isDark,
              glowEnabled: widget.glowEnabled,
              tilt: widget.tiltOffset,
              squeeze: widget.squeezeFactor,
              palette: widget.palette,
              intensity: widget.intensity,
              seed: widget.seed,
            ),
          );
        },
      ),
    );
  }
}

// =============================================================================
//  ابزارهای ریاضی: نویز و فرم‌های بالشتی
// =============================================================================

double _fract(double v) => v - v.floorToDouble();

double _hash2(double x, double y, int seed) {
  final h = math.sin(x * 127.1 + y * 311.7 + seed * 74.7) * 43758.5453;
  return _fract(h);
}

double _smoothstep(double t) => t * t * (3.0 - 2.0 * t);

/// نویز مقداری دوبعدی (۰ تا ۱) — پایهٔ حرکت آلی رنگ‌ها
double _valueNoise(double x, double y, int seed) {
  final xi = x.floorToDouble();
  final yi = y.floorToDouble();
  final xf = x - xi;
  final yf = y - yi;

  final a = _hash2(xi, yi, seed);
  final b = _hash2(xi + 1.0, yi, seed);
  final c = _hash2(xi, yi + 1.0, seed);
  final d = _hash2(xi + 1.0, yi + 1.0, seed);

  final u = _smoothstep(xf);
  final v = _smoothstep(yf);

  return (a * (1.0 - u) + b * u) * (1.0 - v) + (c * (1.0 - u) + d * u) * v;
}

/// جمع سه اکتاو نویز برای بافت ابریشمی
double _fbm(double x, double y, int seed) {
  var sum = 0.0;
  var amp = 0.55;
  var fx = x;
  var fy = y;
  for (var i = 0; i < 3; i++) {
    sum += _valueNoise(fx, fy, seed + i * 31) * amp;
    amp *= 0.48;
    fx *= 2.07;
    fy *= 1.93;
  }
  return sum;
}

/// منحنی بستهٔ نرم از میان نقاط (تکنیک نقطهٔ میانی + بزیهٔ درجه دو)
Path _smoothClosedPath(List<Offset> pts) {
  final path = Path();
  if (pts.length < 3) return path;

  final last = pts[pts.length - 1];
  final first = pts[0];
  path.moveTo((last.dx + first.dx) / 2.0, (last.dy + first.dy) / 2.0);

  for (var i = 0; i < pts.length; i++) {
    final cur = pts[i];
    final next = pts[(i + 1) % pts.length];
    path.quadraticBezierTo(
      cur.dx,
      cur.dy,
      (cur.dx + next.dx) / 2.0,
      (cur.dy + next.dy) / 2.0,
    );
  }

  path.close();
  return path;
}

/// شکل «بالشتی» بسته: شعاع هر زاویه از موج‌های نرم + نویز آلی +
/// یک جملهٔ نوک‌تیز ساخته می‌شود؛ همین ترکیب است که لبه‌ها را همزمان
/// نرم و تیز نشان می‌دهد.
Path _pillowBlob({
  required Offset center,
  required double radius,
  required double t,
  required int seed,
  double wobble = 0.17,
  double sharp = 0.12,
  double lobes = 3.0,
  double squashX = 1.0,
  double squashY = 1.0,
  double rotate = 0.0,
  int samples = 90,
}) {
  final pts = <Offset>[];

  for (var i = 0; i < samples; i++) {
    final a = (i / samples) * 2.0 * math.pi + rotate;

    // ۱) موج‌های نرم — فرم بالشتی
    var r = 1.0 +
        wobble * math.sin(lobes * a + t) +
        wobble * 0.55 * math.cos((lobes + 2.0) * a - t * 0.7);

    // ۲) نویز روی محیط — بافت مایع غیرتکراری
    r += 0.20 *
        (_fbm(
              math.cos(a) * 1.7 + t * 0.3,
              math.sin(a) * 1.7 - t * 0.2,
              seed,
            ) -
            0.45);

    // ۳) جملهٔ نوک‌تیز — هر بار در بازهٔ کوتاهی از زاویه، لبه کشیده می‌شود
    final spike = math.max(0.0, math.sin(2.0 * a + t * 1.1));
    r += sharp * math.pow(spike, 7).toDouble();

    final rr = radius * r.clamp(0.30, 1.90);
    pts.add(Offset(
      center.dx + math.cos(a) * rr * squashX,
      center.dy + math.sin(a) * rr * squashY,
    ));
  }

  return _smoothClosedPath(pts);
}

// =============================================================================
//  نقاش تیله
// =============================================================================

class _LiquidMarblePainter extends CustomPainter {
  _LiquidMarblePainter({
    required this.phase,
    required this.energy,
    required this.flare,
    required this.mode,
    required this.isDark,
    required this.glowEnabled,
    required this.tilt,
    required this.squeeze,
    required this.palette,
    required this.intensity,
    required this.seed,
  });

  final double phase;
  final double energy;
  final double flare;
  final RitmoOrbMode mode;
  final bool isDark;
  final bool glowEnabled;
  final Offset tilt;
  final double squeeze;
  final RitmoOrbPalette palette;
  final double intensity;
  final int seed;

  /// شفافیت مقیاس‌شده با intensity
  double _a(double v) => (v * intensity).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final dim = size.shortestSide;
    if (dim <= 0) return;

    final center = Offset(size.width / 2.0, size.height / 2.0);
    final t = phase * 2.0 * math.pi;

    // تنفس: دو موج با فرکانس متفاوت تا ریتم ماشینی نشود
    final breathe =
        math.sin(t * 0.6) * 0.62 + math.sin(t * 1.3 + 1.1) * 0.38;
    final pulse = 1.0 + breathe * (0.012 + 0.030 * energy);
    final radius = (dim / 2.0) * 0.86 * pulse * squeeze.clamp(0.78, 1.22);
    if (radius <= 3.0) return;

    final sphere = Rect.fromCircle(center: center, radius: radius);
    final detailed = dim >= 38.0 && mode != RitmoOrbMode.compact;
    final samples = dim < 56.0 ? 54 : (dim < 130.0 ? 78 : 96);

    // لایه ۱: هالهٔ اتمسفریک پیرامونی و نشیمن نور
    if (glowEnabled) _paintAura(canvas, center, radius, breathe);

    // لایه ۲: بدنهٔ شیشهٔ مرواریدی تیله
    _paintGlassBody(canvas, center, radius, sphere);

    canvas.save();
    canvas.clipPath(Path()..addOval(sphere));

    // لایه ۳: جریان سرد پشتی (بنفش / یاس)
    _paintVioletUndercurrent(canvas, center, radius, t, samples);

    // لایه ۴: تودهٔ اصلی مرجانی (دو پاس: نرم و تیز)
    _paintCoralFlow(canvas, center, radius, t, samples);

    // لایه ۵: تاخوردگی کهربایی-هلویی
    _paintAmberFold(canvas, center, radius, t, samples);

    // لایه ۶: بالشت شیری سفید که روی رنگ می‌افتد
    _paintMilkPillow(canvas, center, radius, t, samples);

    // لایه ۷: رشته‌های ابریشمی
    if (detailed) _paintSilkWisps(canvas, center, radius, t);

    // لایه ۸: غبار نورانی معلق
    if (detailed) _paintStarDust(canvas, center, radius, t);

    // لایه ۹: تیرگی لبهٔ داخلی (حجم کره)
    _paintInnerShade(canvas, center, radius, sphere);

    // لایه ۱۰: بارقهٔ موفقیت
    if (flare > 0.0 && flare < 1.0) {
      _paintFlare(canvas, center, radius, flare);
    }

    canvas.restore();

    // لایه ۱۱: هایلایت و لبهٔ شیشه
    _paintGlassSheen(canvas, center, radius, sphere);
    _paintRim(canvas, center, radius, sphere, t);
  }

  @override
  bool shouldRepaint(covariant _LiquidMarblePainter old) {
    return old.phase != phase ||
        old.energy != energy ||
        old.flare != flare ||
        old.mode != mode ||
        old.isDark != isDark ||
        old.glowEnabled != glowEnabled ||
        old.tilt != tilt ||
        old.squeeze != squeeze ||
        old.intensity != intensity ||
        old.seed != seed ||
        old.palette != palette;
  }

  // ---------------------------------------------------------------------------
  //  لایه‌ها
  // ---------------------------------------------------------------------------

  /// هالهٔ نرم پیرامون تیله + نشیمن نور زیر آن
  void _paintAura(Canvas canvas, Offset c, double r, double breathe) {
    final auraR = r * (1.34 + breathe * 0.08 + energy * 0.12);

    final aura = Paint()
      ..shader = RadialGradient(
        colors: [
          palette.aura.withValues(alpha: _a(isDark ? 0.30 : 0.20)),
          palette.violet.withValues(alpha: _a(isDark ? 0.18 : 0.11)),
          Colors.transparent,
        ],
        stops: const [0.0, 0.52, 1.0],
      ).createShader(Rect.fromCircle(center: c, radius: auraR))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.38);
    canvas.drawCircle(c, auraR, aura);

    final contact = Paint()
      ..color = palette.aura.withValues(alpha: _a(isDark ? 0.16 : 0.10))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.30);
    canvas.drawOval(
      Rect.fromCenter(
        center: c.translate(0.0, r * 0.96),
        width: r * 1.55,
        height: r * 0.42,
      ),
      contact,
    );
  }

  /// بدنهٔ شیشهٔ مرواریدی (پایهٔ سفید مات)
  void _paintGlassBody(Canvas canvas, Offset c, double r, Rect sphere) {
    final base = Paint()
      ..shader = RadialGradient(
        center: Alignment(
          -0.32 + tilt.dx * 0.12,
          -0.38 + tilt.dy * 0.12,
        ),
        radius: 0.98,
        colors: isDark
            ? const [
                Color(0xFFFDFDFF),
                Color(0xFFE4E8F2),
                Color(0xFFAEB6C8),
                Color(0xFF666F86),
              ]
            : const [
                Color(0xFFFFFFFF),
                Color(0xFFFEFAFA),
                Color(0xFFF2EEF4),
                Color(0xFFDBD6E2),
              ],
        stops: const [0.0, 0.42, 0.78, 1.0],
      ).createShader(sphere);

    canvas.drawCircle(c, r, base);
  }

  /// جریان سرد پشتی: تودهٔ بنفش/یاس که از پشت مرجانی رد می‌شود
  void _paintVioletUndercurrent(
    Canvas canvas,
    Offset c,
    double r,
    double t,
    int samples,
  ) {
    final drift = Offset(
      math.cos(t * 0.5) * r * 0.22 + tilt.dx * r * 0.10,
      math.sin(t * 0.7 + 0.9) * r * 0.18 + tilt.dy * r * 0.10,
    );

    final path = _pillowBlob(
      center: c + drift,
      radius: r * (0.80 + 0.06 * math.sin(t * 0.8)),
      t: t * 0.9,
      seed: seed + 3,
      wobble: 0.20,
      sharp: 0.10,
      lobes: 3.0,
      squashX: 1.06,
      squashY: 0.92,
      rotate: t * 0.25,
      samples: samples,
    );

    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment(0.42 + tilt.dx * 0.1, 0.34 + tilt.dy * 0.1),
        radius: 1.0,
        colors: [
          palette.violet.withValues(alpha: _a(0.70)),
          palette.violet.withValues(alpha: _a(0.32)),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: c, radius: r))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.26);

    canvas.drawPath(path, paint);
  }

  /// تودهٔ اصلی مرجانی: پاس اول نرم و پخش، پاس دوم کوچکتر و تیز
  void _paintCoralFlow(
    Canvas canvas,
    Offset c,
    double r,
    double t,
    int samples,
  ) {
    final drift = Offset(
      math.sin(t * 0.6 + 0.4) * r * 0.20 + tilt.dx * r * 0.14,
      math.cos(t * 0.5 + 1.7) * r * 0.16 + tilt.dy * r * 0.14,
    );

    final bloom = 0.74 + 0.08 * math.sin(t * 1.3) + energy * 0.06;

    // پاس ۱: هستهٔ محو و مخملی
    final soft = _pillowBlob(
      center: c + drift,
      radius: r * bloom,
      t: t,
      seed: seed,
      wobble: 0.19,
      sharp: 0.16,
      lobes: 3.0,
      squashX: 1.0,
      squashY: 0.94,
      rotate: -t * 0.35,
      samples: samples,
    );

    final softPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment(
          0.18 + math.sin(t) * 0.16 + tilt.dx * 0.10,
          -0.24 + math.cos(t * 0.8) * 0.14 + tilt.dy * 0.10,
        ),
        radius: 1.05,
        colors: [
          palette.hot.withValues(alpha: _a(0.95)),
          palette.core.withValues(alpha: _a(0.88)),
          palette.mid.withValues(alpha: _a(0.60)),
          Colors.transparent,
        ],
        stops: const [0.0, 0.42, 0.78, 1.0],
      ).createShader(Rect.fromCircle(center: c, radius: r))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.20);

    canvas.drawPath(soft, softPaint);

    // پاس ۲: لبهٔ تیز ابریشمی روی همان جریان
    final crisp = _pillowBlob(
      center: c + drift * 1.06,
      radius: r * (bloom - 0.17),
      t: t + 0.6,
      seed: seed + 9,
      wobble: 0.22,
      sharp: 0.28,
      lobes: 2.0,
      squashX: 0.96,
      squashY: 0.90,
      rotate: -t * 0.35 + 0.5,
      samples: samples,
    );

    final crispPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [
          Colors.white.withValues(alpha: _a(0.55)),
          palette.hot.withValues(alpha: _a(0.92)),
          palette.core.withValues(alpha: _a(0.78)),
          Colors.transparent,
        ],
        stops: const [0.0, 0.32, 0.68, 1.0],
        transform: GradientRotation(t * 0.4),
      ).createShader(Rect.fromCircle(center: c, radius: r))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.055);

    canvas.drawPath(crisp, crispPaint);
  }

  /// تاخوردگی گرم کهربایی-هلویی که روی مرجانی می‌لغزد
  void _paintAmberFold(
    Canvas canvas,
    Offset c,
    double r,
    double t,
    int samples,
  ) {
    final drift = Offset(
      math.cos(t * 0.9 + 2.2) * r * 0.26 + tilt.dx * r * 0.16,
      math.sin(t * 0.8 + 0.3) * r * 0.20 + tilt.dy * r * 0.16,
    );

    final path = _pillowBlob(
      center: c + drift,
      radius: r * (0.52 + 0.06 * math.sin(t * 1.7 + 0.8)),
      t: t * 1.2 + 2.0,
      seed: seed + 21,
      wobble: 0.26,
      sharp: 0.22,
      lobes: 2.0,
      squashX: 1.12,
      squashY: 0.86,
      rotate: t * 0.5,
      samples: samples,
    );

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: _a(0.62)),
          palette.mid.withValues(alpha: _a(0.80)),
          palette.core.withValues(alpha: _a(0.42)),
          Colors.transparent,
        ],
        stops: const [0.0, 0.34, 0.72, 1.0],
        transform: GradientRotation(-t * 0.3),
      ).createShader(Rect.fromCircle(center: c, radius: r))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.11);

    canvas.drawPath(path, paint);
  }

  /// بالشت شیری سفید: همان تودهٔ مات سمت پایین-چپ فریم‌های مرجع
  void _paintMilkPillow(
    Canvas canvas,
    Offset c,
    double r,
    double t,
    int samples,
  ) {
    final drift = Offset(
      -r * 0.28 + math.cos(t * 0.4) * r * 0.12 + tilt.dx * r * 0.08,
      r * 0.32 + math.sin(t * 0.6 + 1.3) * r * 0.10 + tilt.dy * r * 0.08,
    );

    final path = _pillowBlob(
      center: c + drift,
      radius: r * (0.66 + 0.05 * math.sin(t * 0.9 + 0.5)),
      t: t * 0.8 + 1.4,
      seed: seed + 41,
      wobble: 0.22,
      sharp: 0.10,
      lobes: 2.0,
      squashX: 1.08,
      squashY: 0.94,
      rotate: -t * 0.2,
      samples: samples,
    );

    final paint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.2, 0.15),
        radius: 1.0,
        colors: [
          Colors.white.withValues(alpha: 0.92),
          palette.milk.withValues(alpha: 0.62),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.48, 1.0],
      ).createShader(Rect.fromCircle(center: c, radius: r))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.18);

    canvas.drawPath(path, paint);
  }

  /// رشته‌های ابریشمی: قوس‌های نازک محو، مثل جای قلم‌مو روی مایع
  void _paintSilkWisps(Canvas canvas, Offset c, double r, double t) {
    const count = 5;

    for (var i = 0; i < count; i++) {
      final ph = t * (0.8 + i * 0.1) + i * 1.7;
      final rr = r * (0.30 + i * 0.12);
      final sweep = math.pi * (0.50 + 0.28 * math.sin(ph * 0.7));

      final rect = Rect.fromCircle(
        center: c +
            Offset(
              math.cos(ph * 0.5) * r * 0.10 + tilt.dx * r * 0.06,
              math.sin(ph * 0.4) * r * 0.08 + tilt.dy * r * 0.06,
            ),
        radius: rr,
      );

      final color = i.isEven ? Colors.white : palette.mid;
      final width = (r * (0.055 + 0.030 * math.sin(ph))).clamp(0.5, r * 0.22);

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = width
        ..color = color.withValues(
          alpha: _a((0.28 + 0.16 * math.sin(ph * 1.3)).clamp(0.05, 0.60)),
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.05);

      canvas.drawArc(rect, ph, sweep, false, paint);
    }
  }

  /// غبار نورانی معلق درون مایع تیله
  void _paintStarDust(Canvas canvas, Offset c, double r, double t) {
    final angles = <double>[
      t * 1.2,
      -t * 0.9 + 1.5,
      t * 1.5 + 3.0,
      -t * 1.1 + 4.2,
      t * 0.8 + 2.1,
    ];
    const radii = <double>[0.45, 0.35, 0.55, 0.25, 0.60];
    const sizes = <double>[1.6, 1.4, 1.8, 1.3, 1.5];
    final colors = <Color>[
      palette.mid,
      palette.hot,
      Colors.white,
      palette.violet,
      palette.core,
    ];

    final scale = (r / 21.0).clamp(0.55, 2.40);

    for (var i = 0; i < angles.length; i++) {
      final a = angles[i];
      final rr = r * radii[i];
      final px = c.dx + math.cos(a) * rr + tilt.dx * r * 0.12;
      final py = c.dy + math.sin(a) * rr * 0.60 + tilt.dy * r * 0.12;
      final twinkle = 0.5 + 0.5 * math.sin(a * 3.0);
      final d = sizes[i] * scale * (0.8 + 0.4 * twinkle);

      final paint = Paint()
        ..color = colors[i]
            .withValues(alpha: _a((0.70 * twinkle).clamp(0.15, 0.95)))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, d * 0.5);

      canvas.drawCircle(Offset(px, py), d, paint);
    }
  }

  /// تیرگی نرم لبهٔ داخلی — حس حجم کره را می‌سازد
  void _paintInnerShade(Canvas canvas, Offset c, double r, Rect sphere) {
    final shade = isDark ? Colors.black : const Color(0xFF6B5573);

    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment(
          -0.18 + tilt.dx * 0.10,
          -0.24 + tilt.dy * 0.10,
        ),
        radius: 1.0,
        colors: [
          Colors.transparent,
          Colors.transparent,
          shade.withValues(alpha: isDark ? 0.34 : 0.17),
        ],
        stops: const [0.0, 0.66, 1.0],
      ).createShader(sphere);

    canvas.drawCircle(c, r, paint);
  }

  /// بارقهٔ نوری لحطهٔ موفقیت
  void _paintFlare(Canvas canvas, Offset c, double r, double p) {
    final fr = r * (0.20 + p * 1.25);
    final a = (1.0 - p) * (1.0 - p);

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.95 * a),
          palette.hot.withValues(alpha: 0.66 * a),
          palette.violet.withValues(alpha: 0.36 * a),
          Colors.transparent,
        ],
        stops: const [0.0, 0.35, 0.70, 1.0],
      ).createShader(Rect.fromCircle(center: c, radius: fr))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.15);

    canvas.drawCircle(c, fr, paint);
  }

  /// هایلایت‌های شیشه: هالهٔ بالا-چپ، نقطهٔ درخشان تیز و هلال کاستیک
  void _paintGlassSheen(Canvas canvas, Offset c, double r, Rect sphere) {
    final spec = Paint()
      ..shader = RadialGradient(
        center: Alignment(
          -0.44 + tilt.dx * 0.16,
          -0.50 + tilt.dy * 0.16,
        ),
        radius: 0.62,
        colors: [
          Colors.white.withValues(alpha: 0.92),
          Colors.white.withValues(alpha: 0.26),
          Colors.transparent,
        ],
        stops: const [0.0, 0.40, 1.0],
      ).createShader(sphere);
    canvas.drawCircle(c, r, spec);

    // بازتاب نقطه‌ای منبع نور (لبهٔ تیز، خیلی کم محو)
    canvas.save();
    canvas.translate(
      c.dx - r * 0.40 + tilt.dx * r * 0.14,
      c.dy - r * 0.46 + tilt.dy * r * 0.14,
    );
    canvas.rotate(-0.6);
    final hotSpot = Paint()
      ..color = Colors.white.withValues(alpha: 0.95)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.045);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: r * 0.44,
        height: r * 0.26,
      ),
      hotSpot,
    );
    canvas.restore();

    // نوری که از کف تیله بازمی‌تابد
    final caustic = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.40, 0.56),
        radius: 0.56,
        colors: [
          Colors.white.withValues(alpha: 0.55),
          Colors.white.withValues(alpha: 0.08),
          Colors.transparent,
        ],
        stops: const [0.0, 0.34, 1.0],
      ).createShader(sphere);
    canvas.drawCircle(c, r, caustic);
  }

  /// لبهٔ تیله: حلقهٔ فراست نرم + رینگ‌لایت چرخان محیط
  void _paintRim(Canvas canvas, Offset c, double r, Rect sphere, double t) {
    final frost = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, r * 0.085)
      ..color = Colors.white.withValues(alpha: isDark ? 0.22 : 0.38)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.07);
    canvas.drawCircle(c, r * 0.985, frost);

    final w = math.max(0.7, r * 0.030);
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..shader = SweepGradient(
        colors: [
          Colors.white.withValues(alpha: 0.88),
          Colors.white.withValues(alpha: 0.16),
          palette.aura.withValues(alpha: _a(0.34)),
          Colors.white.withValues(alpha: 0.70),
          Colors.white.withValues(alpha: 0.88),
        ],
        stops: const [0.0, 0.28, 0.52, 0.84, 1.0],
        transform: GradientRotation(-math.pi * 0.75 + t * 0.12),
      ).createShader(sphere);
    canvas.drawCircle(c, r - w / 2.0, rim);
  }
}

// =============================================================================
//  حباب تفکر تعاملی
// =============================================================================

/// نسخهٔ آمادهٔ استفاده برای «حباب تفکر» هوش مصنوعی.
///
/// - اگر [mode] را ندهید، خودش به `RitmoAiStateService.instance.orbMode` گوش می‌دهد.
/// - با لمس، تیله کمی فشرده می‌شود و با رها کردن، ژله‌ای برمی‌گردد.
/// - با کشیدن انگشت، نور و جریان درون تیله پارالاکس می‌گیرند.
///
/// ```dart
/// RitmoThinkingBubble(size: 120, onTap: () => askRitmo());
/// RitmoAiStateService.instance.setMode(RitmoOrbMode.thinking);
/// RitmoAiStateService.instance.triggerSuccessFlare();
/// ```
class RitmoThinkingBubble extends StatefulWidget {
  const RitmoThinkingBubble({
    super.key,
    this.size = 96.0,
    this.mode,
    this.onTap,
    this.palette = RitmoOrbPalette.coral,
    this.enableParallax = true,
    this.glowEnabled = true,
    this.isAnimated = true,
  });

  /// قطر حباب
  final double size;

  /// اگر null باشد، حالت از سرویس وضعیت خوانده می‌شود
  final RitmoOrbMode? mode;

  final VoidCallback? onTap;
  final RitmoOrbPalette palette;
  final bool enableParallax;
  final bool glowEnabled;
  final bool isAnimated;

  @override
  State<RitmoThinkingBubble> createState() => _RitmoThinkingBubbleState();
}

class _RitmoThinkingBubbleState extends State<RitmoThinkingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 170),
    reverseDuration: const Duration(milliseconds: 620),
  );

  late final Animation<double> _squeeze = CurvedAnimation(
    parent: _press,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.elasticOut,
  );

  Offset _tilt = Offset.zero;

  void _setTilt(Offset local) {
    if (!widget.enableParallax) return;
    final half = widget.size / 2.0;
    final next = Offset(
      ((local.dx - half) / half).clamp(-1.0, 1.0),
      ((local.dy - half) / half).clamp(-1.0, 1.0),
    );
    if (next != _tilt) setState(() => _tilt = next);
  }

  void _resetTilt() {
    if (_tilt != Offset.zero) setState(() => _tilt = Offset.zero);
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) {
        _press.forward();
        _setTilt(d.localPosition);
      },
      onTapUp: (_) {
        _press.reverse();
        _resetTilt();
        widget.onTap?.call();
      },
      onTapCancel: () {
        _press.reverse();
        _resetTilt();
      },
      onPanUpdate: (d) => _setTilt(d.localPosition),
      onPanEnd: (_) {
        _press.reverse();
        _resetTilt();
      },
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: TweenAnimationBuilder<Offset>(
          tween: Tween<Offset>(begin: Offset.zero, end: _tilt),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          builder: (context, tilt, _) {
            return AnimatedBuilder(
              animation: _press,
              builder: (context, _) {
                final factor =
                    (1.0 - 0.11 * _squeeze.value).clamp(0.86, 1.08);
                return _buildOrb(tilt, factor);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildOrb(Offset tilt, double squeeze) {
    final fixed = widget.mode;
    if (fixed != null) return _orbFor(fixed, tilt, squeeze);

    return ValueListenableBuilder<RitmoOrbMode>(
      valueListenable: RitmoAiStateService.instance.orbMode,
      builder: (context, mode, _) => _orbFor(mode, tilt, squeeze),
    );
  }

  Widget _orbFor(RitmoOrbMode mode, Offset tilt, double squeeze) {
    return RitmoSiriOrb(
      size: widget.size,
      mode: mode,
      palette: widget.palette,
      glowEnabled: widget.glowEnabled,
      isAnimated: widget.isAnimated,
      tiltOffset: tilt,
      squeezeFactor: squeeze,
    );
  }
}
