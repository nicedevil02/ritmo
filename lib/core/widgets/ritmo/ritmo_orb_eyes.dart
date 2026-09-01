// =============================================================================
//  Ritmo Orb Eyes — چشم‌ها
//
//  در بازطراحیِ قبل، «پلکِ تصادفی» را کشتم چون ادا بود: حرکتی بی‌دلیل که فقط
//  توجه می‌دزدید. چشمِ واقعی داستانِ دیگری است — پلک زدن یک بازتابِ عصبی است
//  و بی‌نظمیِ زمانیِ آن، دقیقاً همان چیزی است که زنده‌اش می‌کند. پس این‌جا
//  تصادف داریم، اما مهارشده و بابت:
//
//   • بستن تند است (~۳۸٪ زمان)، باز شدن کند. برعکسش، عروسکی به نظر می‌رسد.
//   • هر چند پلک، یک دوپلک. آدم‌ها همیشه یک‌دانه پلک نمی‌زنند.
//   • ساکاد: جهش‌های ریزِ نگاه. ارزان‌ترین و قوی‌ترین نشانهٔ زنده بودن.
//   • آدم هنگام جابه‌جا کردنِ نگاه پلک می‌زند؛ این دو به هم قفل‌اند.
//   • در تمرکز (فکر کردن) کمتر و کشیده‌تر پلک می‌زند؛ در شادی تندتر.
//   • آفلاین = چشمِ بسته. خواب، نه خاموشی.
//
//  هزینه: دو تا چهار فرمانِ نقاشی، صفر بلور. درخشِ چشم از کیفِ سفید برداشته
//  می‌شود تا سقفِ سفیدیِ تیله شکسته نشود.
// =============================================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_orb_motion.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_orb_types.dart';

/// چشم‌ها چه وقت باشند.
enum RitmoEyeMode {
  /// هیچ‌وقت.
  off,

  /// بعضی وقت‌ها؛ و همیشه وقتی کاربر با تیله کاری دارد.
  occasional,

  /// همیشه (برای تست و برای لنگرِ کادرِ تایپ).
  always,
}

/// آهنگِ چشم در یک حالِ مشخص.
@immutable
class RitmoEyeTempo {
  const RitmoEyeTempo({
    required this.gapMin,
    required this.gapMax,
    required this.blinkMs,
    required this.alertness,
    required this.gazeDrift,
    required this.squint,
    required this.gazeBias,
    this.asleep = false,
  });

  /// کمینه و بیشینهٔ فاصلهٔ دو پلک (ثانیه).
  final double gapMin;
  final double gapMax;

  /// طولِ یک پلک (میلی‌ثانیه).
  final double blinkMs;

  /// چقدر هوشیار؛ روی تعدادِ ساکادها اثر دارد.
  final double alertness;

  /// دامنهٔ سرگردانیِ نگاه.
  final double gazeDrift;

  /// جمع شدنِ چشم از خنده (۰..۱).
  final double squint;

  /// گرایشِ پایهٔ نگاه؛ مثلاً در فکر، رو به بالا.
  final Offset gazeBias;

  final bool asleep;

  static const RitmoEyeTempo rest = RitmoEyeTempo(
    gapMin: 3.2,
    gapMax: 6.4,
    blinkMs: 168.0,
    alertness: 0.35,
    gazeDrift: 0.55,
    squint: 0.0,
    gazeBias: Offset.zero,
  );

  static const RitmoEyeTempo watch = RitmoEyeTempo(
    gapMin: 2.4,
    gapMax: 4.8,
    blinkMs: 152.0,
    alertness: 0.9,
    gazeDrift: 0.95,
    squint: 0.0,
    gazeBias: Offset(0.0, 0.04),
  );

  static const RitmoEyeTempo think = RitmoEyeTempo(
    gapMin: 4.6,
    gapMax: 9.2,
    blinkMs: 238.0,
    alertness: 0.5,
    gazeDrift: 1.0,
    squint: 0.12,
    // نگاهِ بالا-چپ: نگاهِ کسی که در حالِ فکر کردن است.
    gazeBias: Offset(-0.18, -0.24),
  );

  static const RitmoEyeTempo work = RitmoEyeTempo(
    gapMin: 3.6,
    gapMax: 7.0,
    blinkMs: 176.0,
    alertness: 0.68,
    gazeDrift: 0.4,
    squint: 0.06,
    gazeBias: Offset(0.0, 0.10),
  );

  static const RitmoEyeTempo joy = RitmoEyeTempo(
    gapMin: 2.0,
    gapMax: 3.6,
    blinkMs: 132.0,
    alertness: 1.0,
    gazeDrift: 0.8,
    squint: 0.52,
    gazeBias: Offset(0.0, -0.06),
  );

  static const RitmoEyeTempo sleep = RitmoEyeTempo(
    gapMin: 9.0,
    gapMax: 14.0,
    blinkMs: 320.0,
    alertness: 0.0,
    gazeDrift: 0.1,
    squint: 0.0,
    gazeBias: Offset(0.0, 0.12),
    asleep: true,
  );

  /// آهنگ را از امضای حرکت می‌گیریم، نه از enum حالت‌ها؛ این‌طور اگر روزی
  /// حالتِ تازه‌ای اضافه شد، چشم‌ها خودشان را با جریانِ آن تنظیم می‌کنند.
  static RitmoEyeTempo fromSignature(
    RitmoOrbSignature signature,
    RitmoOrbTruth truth,
  ) {
    if (truth == RitmoOrbTruth.offline) return sleep;
    final double flow = signature.flow;
    // لرزشِ امضا نشانهٔ تمرکز است (فکر کردن/نوشتن)، نه هیجان.
    final bool focused = signature.tremor > 0.12;
    if (focused && flow < 0.92) return think;
    if (flow >= 1.08) return joy;
    if (flow >= 0.9) return work;
    if (flow >= 0.6) return think;
    if (flow >= 0.4) return watch;
    return rest;
  }
}

/// یک قابِ چشم؛ همین را نقاش می‌گیرد.
@immutable
class RitmoEyeFrame {
  const RitmoEyeFrame({
    required this.open,
    required this.gaze,
    required this.presence,
    required this.squint,
  });

  /// بازیِ پلک، ۰ (بسته) تا ۱ (کاملاً باز).
  final double open;

  /// جهتِ نگاه، هر محور ۱- تا ۱.
  final Offset gaze;

  /// چقدر چشم‌ها ظاهر شده‌اند، ۰ تا ۱.
  final double presence;

  /// جمع شدنِ چشم از خنده.
  final double squint;

  static const RitmoEyeFrame absent = RitmoEyeFrame(
    open: 1.0,
    gaze: Offset.zero,
    presence: 0.0,
    squint: 0.0,
  );

  static const RitmoEyeFrame calm = RitmoEyeFrame(
    open: 1.0,
    gaze: Offset.zero,
    presence: 1.0,
    squint: 0.0,
  );

  @override
  bool operator ==(Object other) =>
      other is RitmoEyeFrame &&
      other.open == open &&
      other.gaze == gaze &&
      other.presence == presence &&
      other.squint == squint;

  @override
  int get hashCode => Object.hash(open, gaze, presence, squint);
}

/// زندگیِ چشم‌ها: پلک، نگاه، آمدن و رفتن. با همان ساعتِ مشترک قدم می‌زند.
class RitmoEyeLife {
  RitmoEyeLife({
    int seed = 11,
    this.appearGapMin = 11.0,
    this.appearGapMax = 21.0,
    this.appearHoldMin = 3.0,
    this.appearHoldMax = 5.4,
  }) : _rnd = math.Random(seed) {
    _blinkIn = 1.6 + _rnd.nextDouble() * 2.4;
    _wait = appearGapMin * 0.4 + _rnd.nextDouble() * 2.0;
    _saccadeIn = 0.6 + _rnd.nextDouble();
  }

  final math.Random _rnd;

  /// فاصله و مدتِ ظاهر شدنِ خودجوشِ چشم‌ها (ثانیه).
  final double appearGapMin;
  final double appearGapMax;
  final double appearHoldMin;
  final double appearHoldMax;

  double _open = 1.0;
  double _presence = 0.0;
  double _target = 0.0;
  double _hold = 0.0;
  double _wait = 0.0;
  double _blinkIn = 0.0;
  double _blinkT = -1.0;
  double _blinkMs = 168.0;
  bool _twice = false;
  double _saccadeIn = 0.0;
  Offset _saccade = Offset.zero;
  Offset _gaze = Offset.zero;
  double _squint = 0.0;

  double get open => _open;
  double get presence => _presence;
  Offset get gaze => _gaze;
  bool get isBlinking => _blinkT >= 0.0;

  RitmoEyeFrame get frame => RitmoEyeFrame(
        open: _open,
        gaze: _gaze,
        presence: _presence,
        squint: _squint,
      );

  /// «نگاه کن!» — لمس، اشاره، یا هر چیزی که کاربر واقعاً انجام داده.
  void wake({double hold = 3.4}) {
    _target = 1.0;
    if (_hold < hold) _hold = hold;
  }

  void hide() {
    _target = 0.0;
    _hold = 0.0;
  }

  void blinkNow({bool twice = false, double? ms}) {
    if (_blinkT >= 0.0) return;
    _blinkT = 0.0;
    _blinkMs = ms ?? _blinkMs;
    _twice = twice;
  }

  double _range(double a, double b) => a + _rnd.nextDouble() * (b - a);

  void step(
    double dt, {
    required RitmoEyeTempo tempo,
    required bool wantVisible,
    bool always = false,
    Offset focus = Offset.zero,
    double attention = 0.0,
  }) {
    if (dt <= 0.0) return;

    // ── آمدن و رفتن ──────────────────────────────────────────────────────
    if (!wantVisible) {
      _target = 0.0;
      _hold = 0.0;
    } else if (always) {
      _target = 1.0;
    } else {
      if (attention > 0.12) wake(hold: 2.4);
      if (_hold > 0.0) {
        _hold -= dt;
        if (_hold <= 0.0) {
          _target = 0.0;
          _wait = _range(appearGapMin, appearGapMax);
        }
      } else {
        _wait -= dt;
        if (_wait <= 0.0) {
          _target = 1.0;
          _hold = _range(appearHoldMin, appearHoldMax);
          // تازه که چشم باز می‌کند، یک پلکِ آرام می‌زند.
          blinkNow(ms: tempo.blinkMs * 1.1);
        }
      }
    }
    final double ease = _target > _presence ? dt * 3.4 : dt * 2.2;
    _presence += (_target - _presence) * math.min(1.0, ease);
    _presence = _presence.clamp(0.0, 1.0);

    // ── پلک ──────────────────────────────────────────────────────────────
    if (tempo.asleep) {
      _open += (0.05 - _open) * math.min(1.0, dt * 2.6);
      _blinkT = -1.0;
    } else if (_blinkT >= 0.0) {
      _blinkT += dt * 1000.0;
      final double closeMs = _blinkMs * 0.38;
      final double openMs = _blinkMs - closeMs;
      if (_blinkT <= closeMs) {
        _open = 1.0 -
            Curves.easeIn.transform((_blinkT / closeMs).clamp(0.0, 1.0));
      } else if (_blinkT < _blinkMs) {
        // باز شدن کندتر از بستن؛ همین یک جزئیات، پلک را طبیعی می‌کند.
        _open = Curves.easeOutCubic
            .transform(((_blinkT - closeMs) / openMs).clamp(0.0, 1.0));
      } else {
        _open = 1.0;
        _blinkT = -1.0;
        if (_twice) {
          _twice = false;
          _blinkIn = 0.11;
        } else {
          _blinkIn = _range(tempo.gapMin, tempo.gapMax);
        }
      }
    } else {
      _blinkIn -= dt;
      if (_blinkIn <= 0.0) {
        _blinkT = 0.0;
        _blinkMs = tempo.blinkMs;
        _twice = _rnd.nextDouble() < 0.18;
      }
    }

    // ── نگاه ─────────────────────────────────────────────────────────────
    _saccadeIn -= dt;
    if (_saccadeIn <= 0.0) {
      _saccadeIn = _range(0.7, 1.9) / (0.6 + tempo.alertness);
      final double amp = 0.11 * tempo.gazeDrift;
      _saccade = Offset(
        (_rnd.nextDouble() * 2.0 - 1.0) * amp,
        (_rnd.nextDouble() * 2.0 - 1.0) * amp * 0.7,
      );
      // آدم‌ها هنگام جابه‌جا کردنِ نگاه پلک می‌زنند.
      if (_rnd.nextDouble() < 0.22) blinkNow(ms: tempo.blinkMs * 0.85);
    }
    final Offset target = Offset(
      (focus.dx * (0.5 + 0.5 * attention) +
              _saccade.dx +
              tempo.gazeBias.dx)
          .clamp(-1.0, 1.0),
      (focus.dy * (0.5 + 0.5 * attention) +
              _saccade.dy +
              tempo.gazeBias.dy)
          .clamp(-1.0, 1.0),
    );
    final double follow = math.min(1.0, dt * 9.0);
    _gaze = Offset(
      _gaze.dx + (target.dx - _gaze.dx) * follow,
      _gaze.dy + (target.dy - _gaze.dy) * follow,
    );

    _squint += (tempo.squint - _squint) * math.min(1.0, dt * 3.0);
  }

  @visibleForTesting
  void debugSnap({double? open, double? presence}) {
    if (open != null) _open = open;
    if (presence != null) {
      _presence = presence;
      _target = presence;
    }
  }
}

/// چشم‌ها را می‌کشد.
///
/// [flatten] برای وقتی است که سر پشتِ چیزی مانده و فقط لبه‌اش بیرون است:
/// چشم‌ها پخ می‌شوند، اما پلک هنوز خوانا است.
void ritmoPaintEyes(
  Canvas canvas, {
  required Offset center,
  required double span,
  required double radius,
  required RitmoEyeFrame frame,
  required RitmoOrbPalette palette,
  required bool isDark,
  RitmoWhitePurse? purse,
  double flatten = 1.0,
  bool catchlight = true,
}) {
  final double presence = frame.presence.clamp(0.0, 1.0);
  if (presence <= 0.02 || radius <= 0.4) return;

  final double open = (frame.open.clamp(0.0, 1.0) * flatten).clamp(0.0, 1.0);
  final Color ink = Color.lerp(
    const Color(0xFF190E21),
    palette.violet,
    isDark ? 0.32 : 0.16,
  )!
      .withValues(alpha: 0.86 * presence);

  final Paint fill = Paint()
    ..color = ink
    ..style = PaintingStyle.fill;

  // پلک از بالا می‌آید، پس چشمِ نیم‌بسته کمی پایین‌تر می‌نشیند.
  final double lidDrop = radius * 0.20 * (1.0 - open);
  final double ry = radius * (1.22 - 0.48 * frame.squint) * open;

  for (int i = 0; i < 2; i++) {
    final double side = i == 0 ? -1.0 : 1.0;
    final Offset eye = Offset(
      center.dx + side * span * 0.5 + frame.gaze.dx * radius * 0.44,
      center.dy + frame.gaze.dy * radius * 0.34 + lidDrop,
    );

    if (ry < radius * 0.11) {
      // پلکِ بسته: یک خطِ کوتاه. آدم بیشتر از این نمی‌بیند.
      final Paint lid = Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(0.9, radius * 0.34);
      canvas.drawLine(
        Offset(eye.dx - radius * 0.82, eye.dy),
        Offset(eye.dx + radius * 0.82, eye.dy),
        lid,
      );
      ritmoCountPaint(ops: 1);
      continue;
    }

    canvas.drawOval(
      Rect.fromCenter(
        center: eye,
        width: radius * 2.0,
        height: ry * 2.0,
      ),
      fill,
    );
    ritmoCountPaint(ops: 1);

    if (catchlight && open > 0.5) {
      final double want = 0.5 * presence * open;
      final double granted = purse?.take(want) ?? want;
      if (granted > 0.02) {
        canvas.drawCircle(
          Offset(eye.dx - radius * 0.30, eye.dy - ry * 0.36),
          math.max(0.6, radius * 0.26),
          Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: granted),
        );
        ritmoCountPaint(ops: 1, white: granted);
      }
    }
  }
}
