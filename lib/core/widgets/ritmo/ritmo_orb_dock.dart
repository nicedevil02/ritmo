// =============================================================================
//  Ritmo Orb Dock — وقتی حباب دورِ کادرِ تایپ پهن می‌شود
//
//  کیبرد که بالا می‌آید، تیله جایی برای بودن ندارد: نصفِ صفحه رفته، و چشمِ
//  کاربر روی متنی است که دارد می‌نویسد. پس حباب جایِ بزرگ بودن را پس
//  می‌دهد، دورِ کادر می‌ریزد و فقط پیشانی و دو چشمش را بیرون نگه می‌دارد.
//
//  سه تصمیمِ مهم:
//
//  ۱) توهمِ «پشتِ کادر بودن» با برش ساخته می‌شود، نه با ترتیبِ لایه‌ها. هر
//     چیزی که زیرِ لبهٔ بالاییِ کادر باشد اصلاً کشیده نمی‌شود، و رینگِ ژله هم با
//     یک برشِ معکوس بیرونِ درونِ کادر نگه داشته می‌شود. نتیجه: لایه هرگز روی
//     متنِ کاربر نمی‌افتد، و لمس را هم نمی‌دزدد (IgnorePointer).
//
//  ۲) هندسهٔ کادر را حدس نمی‌زنیم اگر کسی گفته باشد: کافی است کادرِ تایپ را
//     در RitmoOrbDockAnchor بپیچید. اگر نپیچید، باندِ بالای کیبرد حدس زده
//     می‌شود — درست به نظر می‌رسد، ولی دقیق نیست.
//
//  ۳) ارتفاعِ کیبرد را از MediaQuery تنها نمی‌پرسیم. Scaffold با
//     resizeToAvoidBottomInset: true بدنه‌اش را در MediaQuery.removeViewInsets
//     می‌پیچد؛ یعنی هر ویجتی داخلِ بدنه، کیبردِ باز را صفر می‌بیند. این دقیقاً
//     همان باگی بود که لنگر را در اپ مرده نگه داشته بود و در تست سبز می‌ماند.
// =============================================================================

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_orb_clock.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_orb_eyes.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_orb_motion.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_orb_types.dart';

/// از این مقدار به بالا، کیبرد را باز حساب می‌کنیم. (پیشنهادِ کلمه و مانندِ
/// آن ده-بیست پیکسل inset می‌سازند و کیبرد نیستند.)
const double kRitmoKeyboardOpen = 40.0;

/// ارتفاعِ واقعیِ کیبرد به پیکسلِ منطقی.
///
/// چرا این‌قدر دست‌وپا؟ چون Scaffold با resizeToAvoidBottomInset: true بدنه‌اش را
/// در MediaQuery.removeViewInsets می‌پیچد. پس هر ویجتی که داخلِ بدنه است،
/// viewInsets.bottom را صفر می‌بیند حتی وقتی کیبرد کاملاً بالاست. مقدارِ خام را
/// از خودِ View می‌گیریم و بزرگ‌ترِ دو منبع را برمی‌داریم — این‌طور تست‌هایی که
/// MediaQuery را دستی می‌سازند هم درست می‌مانند.
///
/// [dependent] را false بگذارید اگر در فازِ build نیستید (مانندِ didChangeMetrics)
/// و نمی‌خواهید وابستگیِ تازه‌ای به MediaQuery ساخته شود.
double ritmoKeyboardInset(BuildContext context, {bool dependent = true}) {
  final double fromMedia = dependent
      ? (MediaQuery.maybeViewInsetsOf(context)?.bottom ?? 0.0)
      : (context
              .getInheritedWidgetOfExactType<MediaQuery>()
              ?.data
              .viewInsets
              .bottom ??
          0.0);

  double fromView = 0.0;
  final ui.FlutterView? view = View.maybeOf(context);
  if (view != null) {
    final double ratio = view.devicePixelRatio;
    if (ratio > 0.0) fromView = view.viewInsets.bottom / ratio;
  }

  return math.max(fromMedia, fromView);
}

/// کیبرد باز است؟
bool ritmoKeyboardOpen(BuildContext context, {bool dependent = true}) =>
    ritmoKeyboardInset(context, dependent: dependent) > kRitmoKeyboardOpen;

/// جایِ کادرِ تایپ در مختصاتِ صفحه.
@immutable
class RitmoOrbDockAnchorInfo {
  const RitmoOrbDockAnchorInfo({required this.rect, this.radius = 22.0});

  final Rect rect;
  final double radius;

  @override
  bool operator ==(Object other) =>
      other is RitmoOrbDockAnchorInfo &&
      other.rect == rect &&
      other.radius == radius;

  @override
  int get hashCode => Object.hash(rect, radius);
}

/// کانالِ یک‌طرفه: کادرِ تایپ جایش را گزارش می‌دهد، لنگر می‌خواند.
class RitmoOrbDockSignal extends ValueNotifier<RitmoOrbDockAnchorInfo?> {
  RitmoOrbDockSignal._() : super(null);

  static final RitmoOrbDockSignal instance = RitmoOrbDockSignal._();

  void report(Rect rect, {double radius = 22.0}) {
    if (rect.isEmpty) return;
    final RitmoOrbDockAnchorInfo next =
        RitmoOrbDockAnchorInfo(rect: rect, radius: radius);
    if (value == next) return;
    value = next;
  }

  void clear() {
    if (value != null) value = null;
  }
}

/// کادرِ تایپ را در این بپیچید تا لنگر دقیقاً بداند کجا باید پهن شود.
///
/// ```dart
/// RitmoOrbDockAnchor(radius: 24, child: myComposer)
/// ```
class RitmoOrbDockAnchor extends StatefulWidget {
  const RitmoOrbDockAnchor({
    super.key,
    required this.child,
    this.radius = 22.0,
  });

  final Widget child;
  final double radius;

  @override
  State<RitmoOrbDockAnchor> createState() => _RitmoOrbDockAnchorState();
}

class _RitmoOrbDockAnchorState extends State<RitmoOrbDockAnchor> {
  final GlobalKey _anchor = GlobalKey();

  void _measureAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final RenderObject? object = _anchor.currentContext?.findRenderObject();
      if (object is! RenderBox || !object.hasSize) return;
      final Offset topLeft = object.localToGlobal(Offset.zero);
      RitmoOrbDockSignal.instance.report(
        topLeft & object.size,
        radius: widget.radius,
      );
    });
  }

  @override
  void dispose() {
    RitmoOrbDockSignal.instance.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // هر بازساخت دوباره اندازه می‌گیریم؛ کیبرد که باز شود، کادر بالا می‌رود.
    _measureAfterFrame();
    return KeyedSubtree(key: _anchor, child: widget.child);
  }
}

/// لایهٔ ژله: دورِ کادر پهن می‌شود، پیشانی و چشم‌ها را بیرون می‌گذارد.
class RitmoOrbDockLayer extends StatefulWidget {
  const RitmoOrbDockLayer({
    super.key,
    this.palette,
    this.signature,
    this.truth,
    this.tokenPulse,
    this.eyes = true,
    this.seed = 11,
    this.stats,
    this.debugAnchor,
  });

  final RitmoOrbPalette? palette;
  final RitmoOrbSignature? signature;
  final RitmoOrbTruth? truth;

  /// هر بار بالا رفتن = یک تکه متنِ تازه؛ سر کمی بیشتر بیرون می‌آید.
  final ValueListenable<int>? tokenPulse;
  final bool eyes;
  final int seed;
  final RitmoOrbPaintStats? stats;

  /// فقط برای تست: لنگرِ دستی.
  final RitmoOrbDockAnchorInfo? debugAnchor;

  /// ارتفاعِ عادیِ سر وقتی فقط پیشانی بیرون است.
  static const double restPeek = 0.18;

  /// اگر کسی جایِ کادر را گزارش نکرده باشد، باندِ بالای کیبرد.
  static RitmoOrbDockAnchorInfo fallbackAnchor({
    required Size screen,
    required double keyboard,
    required EdgeInsets padding,
  }) {
    const double margin = 14.0;
    const double height = 58.0;
    final double gap = keyboard > 0.0 ? 8.0 : padding.bottom + 10.0;
    final double bottom = screen.height - keyboard - gap;
    return RitmoOrbDockAnchorInfo(
      rect: Rect.fromLTRB(
        margin,
        math.max(0.0, bottom - height),
        math.max(margin + 1.0, screen.width - margin),
        math.max(1.0, bottom),
      ),
    );
  }

  @override
  State<RitmoOrbDockLayer> createState() => _RitmoOrbDockLayerState();
}

class _RitmoOrbDockLayerState extends State<RitmoOrbDockLayer>
    with WidgetsBindingObserver {
  final ValueNotifier<double> _frame = ValueNotifier<double>(0.0);
  late final RitmoEyeLife _eyeLife = RitmoEyeLife(
    seed: widget.seed,
    appearGapMin: 6.0,
    appearGapMax: 12.0,
    appearHoldMin: 4.0,
    appearHoldMax: 7.0,
  );
  late final math.Random _rnd = math.Random(widget.seed + 7);

  double _phase = 0.0;
  double _clockLast = 0.0;
  double _travel = 0.68;
  double _travelDir = -1.0;
  double _peek = RitmoOrbDockLayer.restPeek;
  double _peekTarget = RitmoOrbDockLayer.restPeek;
  double _peekHold = 0.0;
  double _peekWait = 2.0;
  double _token = 0.0;
  bool _subscribed = false;
  bool _reduceMotion = false;
  bool _tickerOn = true;
  bool _typing = false;

  RitmoOrbSignature get _signature =>
      widget.signature ?? RitmoOrbSignature.of(RitmoOrbLife.breathing);

  RitmoOrbTruth get _truth =>
      widget.truth ?? RitmoAiStateService.instance.truth.value;

  RitmoOrbPalette get _palette => widget.palette ?? RitmoOrbPalette.coral;

  @override
  void initState() {
    super.initState();
    // اولین سرک باید زود بیاید؛ وگرنه کاربر فکر می‌کند چیزی خراب است.
    _peekWait = 1.2 + _rnd.nextDouble() * 1.4;
    WidgetsBinding.instance.addObserver(this);
    RitmoAiStateService.instance.truth.addListener(_onExternal);
    RitmoOrbAttentionSignal.instance.acknowledge.addListener(_onNod);
    widget.tokenPulse?.addListener(_onToken);
  }

  @override
  void didUpdateWidget(RitmoOrbDockLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tokenPulse != widget.tokenPulse) {
      oldWidget.tokenPulse?.removeListener(_onToken);
      widget.tokenPulse?.addListener(_onToken);
    }
    if (!_subscribed) _frame.value = _frame.value + 1.0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _typing = ritmoKeyboardOpen(context);
    _tickerOn = TickerMode.valuesOf(context).enabled;
    _syncClock();
  }

  /// درونِ بدنهٔ Scaffold، MediaQuery خبرِ کیبرد را نمی‌دهد. پس مستقیم از
  /// خودِ پلتفرم می‌شنویم.
  @override
  void didChangeMetrics() {
    if (!mounted) return;
    final bool typing = ritmoKeyboardOpen(context, dependent: false);
    if (typing == _typing) return;
    _typing = typing;
    _syncClock();
    setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    RitmoOrbClock.instance.unsubscribe(_onTick);
    RitmoAiStateService.instance.truth.removeListener(_onExternal);
    RitmoOrbAttentionSignal.instance.acknowledge.removeListener(_onNod);
    widget.tokenPulse?.removeListener(_onToken);
    _frame.dispose();
    super.dispose();
  }

  void _syncClock() {
    final bool want = _typing && !_reduceMotion && _tickerOn;
    if (want == _subscribed) return;
    if (want) {
      _clockLast = RitmoOrbClock.instance.time;
      RitmoOrbClock.instance.subscribe(
        _onTick,
        interval: RitmoOrbBudget.of(RitmoOrbTier.m).frameInterval,
      );
    } else {
      RitmoOrbClock.instance.unsubscribe(_onTick);
      _frame.value = _frame.value + 1.0;
    }
    _subscribed = want;
  }

  void _onExternal() {
    if (!mounted) return;
    _frame.value = _frame.value + 1.0;
  }

  void _onNod() {
    // کاربر صدایش زد: سر را بیاور بالا، نگاه کن و لبخند بزن.
    _peekTarget = 0.92;
    _peekHold = math.max(_peekHold, 2.4);
    _eyeLife.wake(hold: 3.4);
    _eyeLife.blinkNow(twice: true);
    _eyeLife.smile();
    _onExternal();
  }

  void _onToken() {
    _token = 1.0;
    if (_peekTarget < 0.46) _peekTarget = 0.46;
    if (_peekHold < 1.1) _peekHold = 1.1;
    _onExternal();
  }

  double _range(double a, double b) => a + _rnd.nextDouble() * (b - a);

  void _onTick() {
    final double now = RitmoOrbClock.instance.time;
    double dt = now - _clockLast;
    _clockLast = now;
    if (dt <= 0.0 || dt > 0.25) dt = 1.0 / 60.0;

    final RitmoOrbSignature sig = _signature.withTruth(_truth);
    _phase += dt * (0.6 + 1.2 * sig.flow);
    if (_phase > 6283.0) _phase -= 6283.0;
    if (_token > 0.0) _token = (_token - dt / 0.4).clamp(0.0, 1.0);

    // ── قدم زدن دورِ کادر ──────────────────────────────────
    _travel += _travelDir * dt / 14.0;
    if (_travel <= 0.0) {
      _travel = 0.0;
      _travelDir = 1.0;
    } else if (_travel >= 1.0) {
      _travel = 1.0;
      _travelDir = -1.0;
    }

    // ── سرک کشیدن ────────────────────────────────────────
    if (_peekHold > 0.0) {
      _peekHold -= dt;
      if (_peekHold <= 0.0) {
        _peekTarget = RitmoOrbDockLayer.restPeek;
        _peekWait = _range(4.5, 9.0);
      }
    } else {
      _peekWait -= dt;
      if (_peekWait <= 0.0) {
        _peekTarget = _range(0.62, 0.95);
        _peekHold = _range(1.8, 3.2);
        _eyeLife.wake(hold: _peekHold + 0.8);
        if (_rnd.nextDouble() < 0.7) _eyeLife.blinkNow();
        if (_rnd.nextDouble() < 0.35) _eyeLife.smile(amount: 0.55);
      }
    }
    final double climb = _peekTarget > _peek ? dt * 2.6 : dt * 1.8;
    _peek += (_peekTarget - _peek) * math.min(1.0, climb);
    _peek = _peek.clamp(0.0, 1.0);

    // ── چشم‌ها ────────────────────────────────────────────
    if (widget.eyes) {
      _eyeLife.step(
        dt,
        tempo: RitmoEyeTempo.fromSignature(sig, _truth),
        wantVisible: true,
        // تا وقتی سر بیرون است، چشم‌ها هم هستند و رو به کاربرند؛ پیشانیِ
        // بی‌چشم معنا ندارد، و سری که پشتِ کادر بچرخد هم.
        always: true,
        focus: RitmoOrbAttentionSignal.instance.value.focus,
        attention: RitmoOrbAttentionSignal.instance.value.strength,
      );
    }

    _frame.value = now;
  }

  @visibleForTesting
  void debugSnap({double? open, double? presence}) {
    _eyeLife.debugSnap(open: open, presence: presence);
    _frame.value++;
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final double keyboard = ritmoKeyboardInset(context);
    if (keyboard <= kRitmoKeyboardOpen && widget.debugAnchor == null) {
      // کیبرد بسته است؛ لنگری لازم نیست.
      return const SizedBox.shrink();
    }
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<RitmoOrbDockAnchorInfo?>(
      valueListenable: RitmoOrbDockSignal.instance,
      builder: (context, reported, child) {
        final RitmoOrbDockAnchorInfo anchor = widget.debugAnchor ??
            reported ??
            RitmoOrbDockLayer.fallbackAnchor(
              screen: media.size,
              keyboard: keyboard,
              padding: media.padding,
            );

        return Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: RepaintBoundary(
                child: ValueListenableBuilder<double>(
                  valueListenable: _frame,
                  builder: (context, _, inner) {
                    final RitmoOrbSignature sig =
                        _signature.withTruth(_truth);
                    RitmoOrbPalette palette = _palette;
                    if (_truth == RitmoOrbTruth.unsure) {
                      palette = palette.drained(0.42);
                    } else if (_truth == RitmoOrbTruth.offline) {
                      palette = palette.drained(0.84);
                    }
                    return CustomPaint(
                      size: media.size,
                      painter: _DockPainter(
                        anchor: anchor,
                        palette: palette,
                        signature: sig,
                        eyeFrame: widget.eyes
                            ? _eyeLife.frame
                            : RitmoEyeFrame.absent,
                        peek: _reduceMotion
                            ? RitmoOrbDockLayer.restPeek
                            : _peek,
                        travel: _reduceMotion ? 0.5 : _travel,
                        phase: _reduceMotion ? 0.0 : _phase,
                        token: _token,
                        isDark: isDark,
                        stats: widget.stats,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DockPainter extends CustomPainter {
  _DockPainter({
    required this.anchor,
    required this.palette,
    required this.signature,
    required this.eyeFrame,
    required this.peek,
    required this.travel,
    required this.phase,
    required this.token,
    required this.isDark,
    required this.stats,
  });

  final RitmoOrbDockAnchorInfo anchor;
  final RitmoOrbPalette palette;
  final RitmoOrbSignature signature;
  final RitmoEyeFrame eyeFrame;
  final double peek;
  final double travel;
  final double phase;
  final double token;
  final bool isDark;
  final RitmoOrbPaintStats? stats;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect box = anchor.rect;
    if (box.isEmpty || box.width < 24.0) return;
    RitmoOrbPaintStats.active = stats;
    try {
      _paint(canvas, size, box);
    } finally {
      RitmoOrbPaintStats.active = null;
    }
  }

  void _paint(Canvas canvas, Size size, Rect box) {
    final RitmoWhitePurse purse =
        RitmoWhitePurse(RitmoOrbBudget.of(RitmoOrbTier.m).whiteBudget);
    // نورِ لبه اول سهمش را می‌گیرد: همین خط، نشانهٔ «سر پشتِ کادر است».
    final double edgeAlpha = purse.take(isDark ? 0.22 : 0.16);

    final double breath = 0.5 + 0.5 * math.sin(phase * 1.6);
    final double swell = 0.86 + 0.28 * breath + 0.2 * token;

    // ── ۱) ژله‌ای که دورِ کادر پهن شده ───────────────────────────────
    // بیرونِ درونِ کادر می‌ماند: متنِ کاربر مقدس است.
    final RRect shell = RRect.fromRectAndRadius(
      box.inflate(2.0),
      Radius.circular(anchor.radius + 2.0),
    );
    canvas.save();
    canvas.clipRect(box.deflate(2.0), clipOp: ui.ClipOp.difference);
    canvas.drawRRect(
      shell,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7.0 * swell
        ..color = palette.hot.withValues(alpha: isDark ? 0.24 : 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7.0),
    );
    ritmoCountPaint(ops: 1, blurs: 1);

    canvas.drawRRect(
      shell,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6 + 0.7 * breath
        ..shader = LinearGradient(
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
          colors: <Color>[
            palette.violet.withValues(alpha: 0.55),
            palette.hot.withValues(alpha: 0.50),
            palette.mid.withValues(alpha: 0.42),
          ],
        ).createShader(box),
    );
    ritmoCountPaint(ops: 1);
    canvas.restore();

    // ── ۲) سر: فقط هرچه بالای لبهٔ کادر است ──────────────────────────
    final double inset = box.width * 0.18;
    final double headX = box.left +
        inset +
        (box.width - inset * 2.0) * travel.clamp(0.0, 1.0);
    // یک بالا-پایینِ کوچک وقتی سر بیرون است؛ همان که «زنده» می‌کندش.
    final double bob = 1.0 + 0.06 * math.sin(phase * 3.1) * peek;
    final double capW =
        (box.width * 0.22).clamp(60.0, 132.0) * (1.0 + 0.03 * breath);
    final double capH = (6.0 + 30.0 * peek) * bob;
    // به سمتی که می‌رود کمی کج می‌شود، مثلِ کسی که راه می‌رود.
    final double lean = 0.055 * (travel.clamp(0.0, 1.0) * 2.0 - 1.0);
    final Rect head = Rect.fromCenter(
      center: Offset(headX, box.top + capH * 0.58),
      width: capW,
      height: capH * 2.3,
    );

    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0.0, 0.0, size.width, box.top + 0.6));
    canvas.save();
    canvas.translate(headX, box.top);
    canvas.rotate(lean);
    canvas.translate(-headX, -box.top);

    // تودهٔ نرمِ زیرِ سر — بالای لبه فقط هاله‌اش دیده می‌شود.
    final double blobR = math.max(30.0, box.height * 1.4);
    final Rect blob = Rect.fromCircle(
      center: Offset(headX, box.top + box.height * 0.30),
      radius: blobR,
    );
    canvas.drawCircle(
      blob.center,
      blobR,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            palette.hot.withValues(alpha: 0.24 * (0.45 + 0.55 * peek)),
            palette.hot.withValues(alpha: 0.0),
          ],
          stops: const <double>[0.0, 1.0],
        ).createShader(blob)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10.0),
    );
    ritmoCountPaint(ops: 1, blurs: 1);

    canvas.drawOval(
      head,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            palette.mid.withValues(alpha: 0.92),
            palette.hot.withValues(alpha: 0.96),
          ],
        ).createShader(head),
    );
    ritmoCountPaint(ops: 1);

    // خطِ نورِ بالای پیشانی — همین می‌گوید جنسش شیشه است، نه کاغذ.
    final double sheen = purse.take(0.24 * (0.4 + 0.6 * peek));
    if (sheen > 0.02) {
      canvas.drawArc(
        head.deflate(1.4),
        math.pi * 1.12,
        math.pi * 0.76,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 1.4
          ..color = const Color(0xFFFFFFFF).withValues(alpha: sheen),
      );
      ritmoCountPaint(ops: 1, white: sheen);
    }

    // ── ۳) چشم‌ها روی پیشانی ──────────────────────────────────────
    ritmoPaintEyes(
      canvas,
      center: Offset(headX, box.top - capH * 0.26),
      span: capW * 0.32,
      radius: (capW * 0.062).clamp(2.0, 5.6),
      frame: eyeFrame,
      palette: palette,
      isDark: isDark,
      purse: purse,
      // پیشانی که پایین است، چشم‌ها پخ‌اند؛ که بالا می‌آید، گرد می‌شوند.
      flatten: (0.30 + 1.05 * peek).clamp(0.30, 1.0),
      catchlight: peek > 0.34,
    );

    canvas.restore();
    canvas.restore();

    // ── ۴) لبهٔ کادر: مرزی که سر پشتِ آن پنهان می‌شود ─────────────────
    if (edgeAlpha > 0.02) {
      final double half = capW * 0.72;
      canvas.drawLine(
        Offset(math.max(box.left, headX - half), box.top),
        Offset(math.min(box.right, headX + half), box.top),
        Paint()
          ..strokeWidth = 1.0
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFFFFFFFF).withValues(alpha: edgeAlpha),
      );
      ritmoCountPaint(ops: 1, white: edgeAlpha);
    }
  }

  @override
  bool shouldRepaint(_DockPainter old) =>
      old.anchor != anchor ||
      old.palette != palette ||
      old.eyeFrame != eyeFrame ||
      old.peek != peek ||
      old.travel != travel ||
      old.phase != phase ||
      old.token != token ||
      old.isDark != isDark ||
      old.signature.flow != signature.flow;
}
