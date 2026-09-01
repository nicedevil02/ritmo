// =============================================================================
//  Ritmo Orb Shell — هندسهٔ پوسته
//  قبلاً هر فریم ۴۶ تا ۹۶ نمونه با ۴ sin و یک exp ساخته می‌شد (حدود ۵۰۰ فراخوانیِ
//  مثلثاتی در هر فریم). حالا جدولِ هارمونیک‌ها یک‌بار ساخته می‌شود و هر فریم فقط
//  ۴ فراخوانیِ مثلثاتی دارد؛ افتِ برجستگی هم چندجمله‌ای است، نه exp.
// =============================================================================

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

/// یک برجستگیِ موضعی روی محیطِ پوسته.
@immutable
class RitmoShellBulge {
  const RitmoShellBulge({
    required this.angle,
    required this.width,
    required this.amount,
  });

  final double angle;
  final double width;
  final double amount;

  @override
  bool operator ==(Object other) =>
      other is RitmoShellBulge &&
      other.angle == angle &&
      other.width == width &&
      other.amount == amount;

  @override
  int get hashCode => Object.hash(angle, width, amount);
}

class _Harmonics {
  _Harmonics(this.n)
      : cosA = Float64List(n),
        sinA = Float64List(n),
        cos2A = Float64List(n),
        sin2A = Float64List(n),
        cos3A = Float64List(n),
        sin3A = Float64List(n) {
    for (int i = 0; i < n; i++) {
      final double a = (i / n) * 2.0 * math.pi;
      cosA[i] = math.cos(a);
      sinA[i] = math.sin(a);
      cos2A[i] = math.cos(2.0 * a);
      sin2A[i] = math.sin(2.0 * a);
      cos3A[i] = math.cos(3.0 * a);
      sin3A[i] = math.sin(3.0 * a);
    }
  }

  final int n;
  final Float64List cosA;
  final Float64List sinA;
  final Float64List cos2A;
  final Float64List sin2A;
  final Float64List cos3A;
  final Float64List sin3A;
}

class RitmoOrbShell {
  RitmoOrbShell._();

  static final Map<int, _Harmonics> _tables = <int, _Harmonics>{};

  static _Harmonics _table(int n) =>
      _tables.putIfAbsent(n, () => _Harmonics(n));

  static double _wrap(double d) {
    const double twoPi = 2.0 * math.pi;
    double x = d % twoPi;
    if (x > math.pi) x -= twoPi;
    if (x < -math.pi) x += twoPi;
    return x;
  }

  /// افتِ نرمِ برجستگی بدون exp: (1 - x²)²
  static double falloff(double angle, RitmoShellBulge bulge) {
    if (bulge.width <= 0.0) return 0.0;
    final double x = (_wrap(angle - bulge.angle) / bulge.width).abs();
    if (x >= 1.0) return 0.0;
    final double f = 1.0 - x * x;
    return f * f;
  }

  /// شعاعِ نسبیِ پوسته در یک زاویه (۱ = دایرهٔ کامل).
  static double radiusAt({
    required double angle,
    required double phase,
    required double wobble,
    List<RitmoShellBulge> bulges = const <RitmoShellBulge>[],
  }) {
    double r = 1.0 +
        wobble * math.sin(2.0 * angle + phase) +
        wobble * 0.55 * math.cos(3.0 * angle - phase * 0.7);
    for (final RitmoShellBulge bulge in bulges) {
      r += bulge.amount * falloff(angle, bulge);
    }
    return r;
  }

  /// نقطهٔ نوکِ یک برجستگی؛ برای نشاندنِ تاجِ رنگ روی همان نقطه.
  static Offset crestOf(
    RitmoShellBulge bulge, {
    required Offset center,
    required double radius,
    required double phase,
    required double wobble,
  }) {
    final double r = radius *
        radiusAt(
          angle: bulge.angle,
          phase: phase,
          wobble: wobble,
          bulges: <RitmoShellBulge>[bulge],
        );
    return Offset(
      center.dx + math.cos(bulge.angle) * r,
      center.dy + math.sin(bulge.angle) * r,
    );
  }

  static Path buildPath({
    required Offset center,
    required double radius,
    required int samples,
    required double phase,
    required double wobble,
    double squashX = 1.0,
    double squashY = 1.0,
    List<RitmoShellBulge> bulges = const <RitmoShellBulge>[],
  }) {
    final Path path = Path();
    buildPathInto(
      path,
      center: center,
      radius: radius,
      samples: samples,
      phase: phase,
      wobble: wobble,
      squashX: squashX,
      squashY: squashY,
      bulges: bulges,
    );
    return path;
  }

  /// همان مسیر، اما داخلِ یک [Path] که از قبل ساخته شده. هر فریم شیء تازه‌ای
  /// ساخته نمی‌شود.
  static void buildPathInto(
    Path out, {
    required Offset center,
    required double radius,
    required int samples,
    required double phase,
    required double wobble,
    double squashX = 1.0,
    double squashY = 1.0,
    List<RitmoShellBulge> bulges = const <RitmoShellBulge>[],
  }) {
    out.reset();
    if (radius <= 0.0) return;
    if (samples < 8) {
      out.addOval(Rect.fromCenter(
        center: center,
        width: radius * 2.0 * squashX,
        height: radius * 2.0 * squashY,
      ));
      return;
    }

    final int n = samples;
    final _Harmonics h = _table(n);
    // چهار فراخوانیِ مثلثاتی برای کلِ فریم؛ بقیه از جدول می‌آید.
    final double cosP = math.cos(phase);
    final double sinP = math.sin(phase);
    final double q = -phase * 0.7;
    final double cosQ = math.cos(q);
    final double sinQ = math.sin(q);
    final double step = 2.0 * math.pi / n;

    Offset pointAt(int i) {
      final int k = i % n;
      // sin(2a + phase) و cos(3a + q) از جمعِ زوایا
      final double s2 = h.sin2A[k] * cosP + h.cos2A[k] * sinP;
      final double c3 = h.cos3A[k] * cosQ - h.sin3A[k] * sinQ;
      double r = 1.0 + wobble * s2 + wobble * 0.55 * c3;
      if (bulges.isNotEmpty) {
        final double a = k * step;
        for (final RitmoShellBulge bulge in bulges) {
          r += bulge.amount * falloff(a, bulge);
        }
      }
      final double rr = radius * (r < 0.3 ? 0.3 : (r > 1.9 ? 1.9 : r));
      return Offset(
        center.dx + h.cosA[k] * rr * squashX,
        center.dy + h.sinA[k] * rr * squashY,
      );
    }

    Offset current = pointAt(0);
    final Offset last = pointAt(n - 1);
    out.moveTo(
      (last.dx + current.dx) / 2.0,
      (last.dy + current.dy) / 2.0,
    );
    for (int i = 0; i < n; i++) {
      final Offset next = pointAt(i + 1);
      out.quadraticBezierTo(
        current.dx,
        current.dy,
        (current.dx + next.dx) / 2.0,
        (current.dy + next.dy) / 2.0,
      );
      current = next;
    }
    out.close();
  }

  @visibleForTesting
  static void debugClearTables() => _tables.clear();
}

/// مسیرِ پوسته را نگه می‌دارد و فقط وقتی چیزی واقعاً عوض شده بازش می‌سازد.
class RitmoShellCache {
  final Path _path = Path();

  Offset _center = Offset.zero;
  double _radius = -1.0;
  double _phase = double.nan;
  double _wobble = -1.0;
  double _squashX = -1.0;
  double _squashY = -1.0;
  int _samples = -1;
  int _bulgeHash = 0;
  int _rebuilds = 0;

  @visibleForTesting
  int get rebuilds => _rebuilds;

  Path resolve({
    required Offset center,
    required double radius,
    required int samples,
    required double phase,
    required double wobble,
    double squashX = 1.0,
    double squashY = 1.0,
    List<RitmoShellBulge> bulges = const <RitmoShellBulge>[],
  }) {
    // فاز را ریز-گِرد می‌کنیم تا نویزِ اعشار باعثِ بازسازیِ بی‌دلیل نشود.
    final double p = (phase * 512.0).roundToDouble() / 512.0;
    final int bulgeHash = Object.hashAll(bulges);
    final bool same = _samples == samples &&
        _radius == radius &&
        _center == center &&
        _phase == p &&
        _wobble == wobble &&
        _squashX == squashX &&
        _squashY == squashY &&
        _bulgeHash == bulgeHash;
    if (same) return _path;

    _samples = samples;
    _radius = radius;
    _center = center;
    _phase = p;
    _wobble = wobble;
    _squashX = squashX;
    _squashY = squashY;
    _bulgeHash = bulgeHash;
    _rebuilds++;
    RitmoOrbShell.buildPathInto(
      _path,
      center: center,
      radius: radius,
      samples: samples,
      phase: p,
      wobble: wobble,
      squashX: squashX,
      squashY: squashY,
      bulges: bulges,
    );
    return _path;
  }
}
