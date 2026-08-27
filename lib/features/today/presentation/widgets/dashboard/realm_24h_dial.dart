// =============================================================================
//  realm_24h_dial.dart
//  ساعت ۲۴ ساعتهٔ قلمروها — بازنویسی UI با استایل نئومورفیک (Soft-UI)
//
//  • API عمومی ویجت دقیقاً مثل نسخهٔ قبل است (پارامترهای قبلی حذف نشده‌اند)
//  • پارامترهای اختیاری جدید: showHourLabels / usePersianDigits / now
//  • پالت مشترک RealmNeu اینجا تعریف شده و کارت داشبورد هم از آن استفاده می‌کند
// =============================================================================

import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/realm/active_realm_resolver.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_color.dart';

/// -----------------------------------------------------------------------------
/// پالت و ابزارهای مشترک نئومورفیک (لایت / دارک)
/// -----------------------------------------------------------------------------
class RealmNeu {
  const RealmNeu._();

  static const accent = Color(0xFF6366F1);
  static const accentDeep = Color(0xFF4F46E5);
  static const accentBright = Color(0xFF818CF8);

  /// سطح پایهٔ کارت‌ها
  static Color base(bool dark) =>
      dark ? const Color(0xFF1B202B) : const Color(0xFFEFF1F5);

  /// لبهٔ روشن (بالا-چپ) برای گرادیان سطح
  static Color high(bool dark) => dark ? const Color(0xFF262E3C) : Colors.white;

  /// گودی / شیار (پس‌زمینهٔ حلقه)
  static Color low(bool dark) =>
      dark ? const Color(0xFF141921) : const Color(0xFFE2E6EE);

  static Color shadowDark(bool dark) => dark
      ? Colors.black.withValues(alpha: 0.55)
      : const Color(0xFFC5CBD7).withValues(alpha: 0.90);

  static Color shadowLight(bool dark) =>
      dark ? Colors.white.withValues(alpha: 0.05) : Colors.white;

  static Color title(bool dark) => dark ? Colors.white : const Color(0xFF1E293B);

  static Color body(bool dark) =>
      dark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);

  static Color muted(bool dark) =>
      dark ? const Color(0xFF8E9BAE) : const Color(0xFF7C8698);

  static Color accentSoft(bool dark) => dark
      ? const Color(0xFF312E81).withValues(alpha: 0.55)
      : const Color(0xFFEDE9FE);

  static Color accentText(bool dark) =>
      dark ? const Color(0xFFC7CBFF) : accentDeep;

  /// گرادیان ملایم سطح (روشن از بالا-چپ به پایین-راست)
  static LinearGradient surfaceGradient(bool dark) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [high(dark), base(dark)],
      );

  /// سایهٔ دوگانهٔ برجسته
  static List<BoxShadow> raised(
    bool dark, {
    double blur = 12,
    double distance = 4,
  }) =>
      [
        BoxShadow(
          color: shadowDark(dark),
          blurRadius: blur,
          offset: Offset(distance, distance),
        ),
        BoxShadow(
          color: shadowLight(dark),
          blurRadius: blur,
          offset: Offset(-distance, -distance),
        ),
      ];

  /// سایهٔ دوگانهٔ فرورفته
  static List<BoxShadow> sunken(
    bool dark, {
    double blur = 8,
    double distance = 3,
  }) =>
      [
        BoxShadow(
          color: shadowDark(dark),
          blurRadius: blur,
          offset: Offset(-distance, -distance),
        ),
        BoxShadow(
          color: shadowLight(dark),
          blurRadius: blur,
          offset: Offset(distance, distance),
        ),
      ];
}

/// سگمنت زمانی برای ترسیم کمان‌های حلقهٔ ۲۴ ساعته
class RealmDialSegment {
  const RealmDialSegment({
    required this.startMinute,
    required this.endMinute,
    required this.color,
    required this.isActive,
    required this.icon,
    this.name = '',
  });

  final int startMinute; // ۰ تا ۱۴۴۰
  final int endMinute; // پس از ادغام نیمه‌شب می‌تواند بزرگتر از ۱۴۴۰ باشد
  final Color color;
  final bool isActive;
  final IconData? icon;
  final String name;
}

/// ساعت دایره‌ای ۲۴ ساعتهٔ نئومورفیک
class Realm24hDial extends StatelessWidget {
  const Realm24hDial({
    super.key,
    required this.size,
    required this.activeZoneId,
    required this.activeZoneColor,
    required this.activeZoneIcon,
    required this.activeZoneName,
    required this.schedules,
    required this.realms,
    required this.isDarkMode,
    this.showHourLabels = true,
    this.usePersianDigits = true,
    this.now,
  });

  final double size;
  final String? activeZoneId;
  final Color activeZoneColor;
  final String? activeZoneIcon;
  final String? activeZoneName;
  final List<RealmScheduleData> schedules;
  final List<RealmData> realms;
  final bool isDarkMode;

  /// نمایش برچسب‌های ۰۰:۰۰ / ۰۶:۰۰ / ۱۲:۰۰ / ۱۸:۰۰ دور حلقه
  final bool showHourLabels;

  /// ارقام فارسی برای برچسب‌های ساعت
  final bool usePersianDigits;

  /// اگر والد تیکر زنده دارد، همان زمان را پاس بدهید تا دو ساعت مجزا نداشته باشیم
  final DateTime? now;

  static int _timeStrToMinutes(String timeStr) {
    try {
      final parts = timeStr.trim().split(':');
      if (parts.length >= 2) {
        final h = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        return (h * 60 + m).clamp(0, 1440);
      }
    } catch (_) {}
    return 0;
  }

  /// آیکون پیش‌فرض هر قلمرو بر اساس نام (کارت داشبورد هم از همین استفاده می‌کند)
  static IconData iconForRealm(String name, [String? iconStr]) {
    if (name.contains('خواب') || name.contains('استراحت')) {
      return CupertinoIcons.moon_fill;
    }
    if (name.contains('کار') || name.contains('تمرکز')) {
      return CupertinoIcons.briefcase_fill;
    }
    if (name.contains('ورزش') || name.contains('سلامت')) {
      return CupertinoIcons.heart_fill;
    }
    if (name.contains('مطالعه') || name.contains('درس')) {
      return CupertinoIcons.book_fill;
    }
    if (name.contains('آرامش') || name.contains('مدیتیشن')) {
      return CupertinoIcons.moon_stars_fill;
    }
    if (name.contains('طبیعت') || name.contains('ریکاوری')) {
      return CupertinoIcons.leaf_arrow_circlepath;
    }
    return CupertinoIcons.sparkles;
  }

  List<RealmDialSegment> _buildSegments(DateTime current) {
    final segments = <RealmDialSegment>[];
    final todayWeekday = current.weekday;
    final realmMap = {for (final r in realms) r.id: r};

    // اگر زمان‌بندی‌های واقعی وجود داشته باشند از آنها استفاده می‌کنیم
    if (schedules.isNotEmpty) {
      for (final sched in schedules) {
        if (sched.daysOfWeek.isNotEmpty &&
            !sched.daysOfWeek.contains(todayWeekday)) {
          continue;
        }

        final realm = realmMap[sched.zoneId];
        final color =
            RitmoColor.fromHex(realm?.colorHex, fallback: activeZoneColor);
        final isActive = sched.zoneId == activeZoneId;
        final startMin = _timeStrToMinutes(sched.startTime);
        final endMin = _timeStrToMinutes(sched.endTime);
        final icon = iconForRealm(realm?.name ?? '', realm?.icon);

        if (endMin <= startMin) {
          segments.add(
            RealmDialSegment(
              startMinute: startMin,
              endMinute: 1440,
              color: color,
              isActive: isActive,
              icon: icon,
              name: realm?.name ?? '',
            ),
          );
          if (endMin > 0) {
            segments.add(
              RealmDialSegment(
                startMinute: 0,
                endMinute: endMin,
                color: color,
                isActive: isActive,
                icon: icon,
                name: realm?.name ?? '',
              ),
            );
          }
        } else {
          segments.add(
            RealmDialSegment(
              startMinute: startMin,
              endMinute: endMin,
              color: color,
              isActive: isActive,
              icon: icon,
              name: realm?.name ?? '',
            ),
          );
        }
      }
    }

    // فالبک: ۵ سگمنت پیش‌فرض مطابق طرح مرجع
    if (segments.isEmpty) {
      segments.addAll(const [
        // ۱. خواب و ریکاوری (فعال) ۲۳:۰۰ تا ۰۶:۳۰
        RealmDialSegment(
          startMinute: 1380,
          endMinute: 1440,
          color: Color(0xFF6366F1),
          isActive: true,
          icon: CupertinoIcons.moon_fill,
          name: 'خواب',
        ),
        RealmDialSegment(
          startMinute: 0,
          endMinute: 390,
          color: Color(0xFF6366F1),
          isActive: true,
          icon: CupertinoIcons.moon_fill,
          name: 'خواب',
        ),
        // ۲. کار و تمرکز ۰۶:۳۰ تا ۱۲:۰۰
        RealmDialSegment(
          startMinute: 390,
          endMinute: 720,
          color: Color(0xFF3B82F6),
          isActive: false,
          icon: CupertinoIcons.briefcase_fill,
          name: 'کار',
        ),
        // ۳. انرژی و بهره‌وری ۱۲:۰۰ تا ۱۵:۳۰
        RealmDialSegment(
          startMinute: 720,
          endMinute: 930,
          color: Color(0xFFF59E0B),
          isActive: false,
          icon: CupertinoIcons.sparkles,
          name: 'تمرکز',
        ),
        // ۴. طبیعت و ریکاوری ۱۵:۳۰ تا ۱۹:۳۰
        RealmDialSegment(
          startMinute: 930,
          endMinute: 1170,
          color: Color(0xFF10B981),
          isActive: false,
          icon: CupertinoIcons.leaf_arrow_circlepath,
          name: 'طبیعت',
        ),
        // ۵. آرامش شبانه ۱۹:۳۰ تا ۲۳:۰۰
        RealmDialSegment(
          startMinute: 1170,
          endMinute: 1380,
          color: Color(0xFF8B5CF6),
          isActive: false,
          icon: CupertinoIcons.moon_stars_fill,
          name: 'آرامش',
        ),
      ]);
    }

    return segments;
  }

  /// دو سگمنتی که از نیمه‌شب رد می‌شوند را یکی می‌کند تا کمان فعال تکه‌تکه نشود
  static List<RealmDialSegment> _mergeMidnight(List<RealmDialSegment> input) {
    final segments = List<RealmDialSegment>.from(input);

    for (var i = 0; i < segments.length; i++) {
      final head = segments[i];
      if (head.endMinute < 1440 || head.startMinute >= 1440) continue;

      final tailIndex = segments.indexWhere(
        (s) =>
            s.startMinute == 0 &&
            s.endMinute > 0 &&
            s.endMinute < 1440 &&
            s.isActive == head.isActive &&
            s.name == head.name &&
            s.color == head.color,
      );
      if (tailIndex < 0 || tailIndex == i) continue;

      final tail = segments[tailIndex];
      segments[i] = RealmDialSegment(
        startMinute: head.startMinute,
        endMinute: 1440 + tail.endMinute,
        color: head.color,
        isActive: head.isActive,
        icon: head.icon,
        name: head.name,
      );
      segments.removeAt(tailIndex);
      if (tailIndex < i) i--;
    }

    return segments;
  }

  @override
  Widget build(BuildContext context) {
    final current = now ?? DateTime.now();
    final segments = _mergeMidnight(_buildSegments(current));

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size.square(size),
        isComplex: true,
        painter: _NeuDialPainter(
          segments: segments,
          now: current,
          activeColor: activeZoneColor,
          activeZoneIcon: activeZoneIcon,
          activeZoneName: activeZoneName ?? 'خواب',
          isDarkMode: isDarkMode,
          showHourLabels: showHourLabels && size >= 110,
          usePersianDigits: usePersianDigits,
        ),
      ),
    );
  }
}

/// هندسهٔ نهایی یک کمان پس از اعمال فاصله و کلاهک گرد
class _ArcGeom {
  const _ArcGeom(this.start, this.sweep);
  final double start;
  final double sweep;
}

class _NeuDialPainter extends CustomPainter {
  _NeuDialPainter({
    required this.segments,
    required this.now,
    required this.activeColor,
    required this.activeZoneIcon,
    required this.activeZoneName,
    required this.isDarkMode,
    required this.showHourLabels,
    required this.usePersianDigits,
  });

  final List<RealmDialSegment> segments;
  final DateTime now;
  final Color activeColor;
  final String? activeZoneIcon;
  final String activeZoneName;
  final bool isDarkMode;
  final bool showHourLabels;
  final bool usePersianDigits;

  /// دقیقهٔ ۰ (۰۰:۰۰) دقیقاً بالای دایره است
  static double _minuteToAngle(double minute) =>
      (minute / 1440.0) * (2 * math.pi) - (math.pi / 2);

  _ArcGeom? _geom(RealmDialSegment seg, double capAngle, double gapAngle) {
    final rawStart = _minuteToAngle(seg.startMinute.toDouble());
    var full = ((seg.endMinute - seg.startMinute) / 1440.0) * (2 * math.pi);
    if (full <= 0) full += 2 * math.pi;
    if (full > 2 * math.pi) full = 2 * math.pi;

    // کلاهک گرد به اندازهٔ نیمی از ضخامت بیرون می‌زند؛ باید جبران شود
    final inset = math.min(capAngle + gapAngle / 2, full * 0.34);
    final sweep = full - inset * 2;
    if (sweep <= 0.012) return null;

    return _ArcGeom(rawStart + inset, sweep);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final dim = size.shortestSide;
    if (dim <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final k = (dim / 300.0).clamp(0.42, 1.6);

    final labelGap =
        showHourLabels ? (dim * 0.115).clamp(12.0, 30.0) : 0.0;
    final stroke = ((dim - labelGap * 2) * 0.19).clamp(10.0, 40.0);
    final radius = (dim - labelGap * 2 - stroke) / 2;
    if (radius <= 6) return;

    final ring = Rect.fromCircle(center: center, radius: radius);
    final capAngle = (stroke / 2) / radius;
    final gapAngle = (stroke * 0.34) / radius;

    _paintTrack(canvas, center, radius, stroke, k);

    // ۱) سگمنت‌های غیرفعال: پیل‌های برجستهٔ نئومورفیک
    for (final seg in segments) {
      if (seg.isActive) continue;
      final g = _geom(seg, capAngle, gapAngle);
      if (g == null) continue;
      _paintIdleSegment(canvas, ring, g, seg, center, radius, stroke, k);
    }

    // ۲) سگمنت‌های فعال: کمان رنگی با هالهٔ نئونی
    for (final seg in segments) {
      if (!seg.isActive) continue;
      final g = _geom(seg, capAngle, gapAngle);
      if (g == null) continue;
      _paintActiveSegment(canvas, ring, g, seg, stroke, k, capAngle);
    }

    _paintNowDot(canvas, center, radius, stroke, k);
    _paintHub(canvas, center, radius, stroke, k);

    if (showHourLabels) {
      _paintHourLabels(canvas, center, radius, stroke, k, dim);
    }
  }

  /// شیار فرورفتهٔ زیر کمان‌ها
  void _paintTrack(
    Canvas canvas,
    Offset center,
    double radius,
    double stroke,
    double k,
  ) {
    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke + 2 * k
      ..color = RealmNeu.low(isDarkMode);
    canvas.drawCircle(center, radius, groove);

    final grooveShade = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 0.55
      ..color = RealmNeu.shadowDark(isDarkMode)
          .withValues(alpha: isDarkMode ? 0.35 : 0.25)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 * k);
    canvas.drawCircle(
      center.translate(0, 1.2 * k),
      radius + stroke * 0.26,
      grooveShade,
    );
  }

  /// کمان غیرفعال (روشن، برجسته، با آیکون محو)
  void _paintIdleSegment(
    Canvas canvas,
    Rect ring,
    _ArcGeom g,
    RealmDialSegment seg,
    Offset center,
    double radius,
    double stroke,
    double k,
  ) {
    final shadow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke
      ..color = RealmNeu.shadowDark(isDarkMode)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 * k);
    canvas.drawArc(
      ring.shift(Offset(2.4 * k, 3.4 * k)),
      g.start,
      g.sweep,
      false,
      shadow,
    );

    final light = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke
      ..color = RealmNeu.shadowLight(isDarkMode)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 * k);
    canvas.drawArc(
      ring.shift(Offset(-2.2 * k, -2.8 * k)),
      g.start,
      g.sweep,
      false,
      light,
    );

    final body = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDarkMode
            ? const [Color(0xFF2B3342), Color(0xFF1E2430)]
            : const [Colors.white, Color(0xFFE6E9F0)],
      ).createShader(ring);
    canvas.drawArc(ring, g.start, g.sweep, false, body);

    // های‌لایت باریک بالای کمان
    final shineSweep = g.sweep * 0.86;
    if (shineSweep > 0.02) {
      final shine = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke * 0.34
        ..color = isDarkMode
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.75);
      canvas.drawArc(
        ring.shift(Offset(-0.6 * k, -1.0 * k)),
        g.start + g.sweep * 0.07,
        shineSweep,
        false,
        shine,
      );
    }

    // آیکون وسط کمان — فقط وقتی جا دارد
    final icon = seg.icon;
    if (icon != null && g.sweep * radius > stroke * 1.05) {
      final mid = g.start + g.sweep / 2;
      final pos = center + Offset(math.cos(mid), math.sin(mid)) * radius;
      _drawIcon(
        canvas,
        icon,
        pos,
        (stroke * 0.58).clamp(9.0, 24.0),
        RealmNeu.muted(isDarkMode).withValues(alpha: isDarkMode ? 0.85 : 0.72),
      );
    }
  }

  /// کمان فعال (گرادیان چرخشی رنگ قلمرو + هاله)
  void _paintActiveSegment(
    Canvas canvas,
    Rect ring,
    _ArcGeom g,
    RealmDialSegment seg,
    double stroke,
    double k,
    double capAngle,
  ) {
    final startColor = Color.lerp(seg.color, Colors.white, isDarkMode ? 0.25 : 0.15)!;
    final endColor = seg.color;

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt
      ..strokeWidth = stroke * 1.05
      ..color = seg.color.withValues(alpha: isDarkMode ? 0.45 : 0.32)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 * k);
    canvas.drawArc(
      ring.shift(Offset(0.8 * k, 2.4 * k)),
      g.start,
      g.sweep,
      false,
      glow,
    );

    final body = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt
      ..strokeWidth = stroke
      ..shader = SweepGradient(
        startAngle: 0.0,
        endAngle: g.sweep,
        tileMode: TileMode.clamp,
        colors: [
          startColor,
          seg.color,
          endColor,
        ],
        transform: GradientRotation(g.start),
      ).createShader(ring);
    canvas.drawArc(ring, g.start, g.sweep, false, body);

    // Rounded caps with matching start/end colors (eliminating dark seam artifact)
    final radius = ring.width / 2;
    final startCapCenter = ring.center + Offset(math.cos(g.start), math.sin(g.start)) * radius;
    final startCapPaint = Paint()
      ..color = startColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(startCapCenter, stroke / 2, startCapPaint);

    final endCapCenter = ring.center + Offset(math.cos(g.start + g.sweep), math.sin(g.start + g.sweep)) * radius;
    final endCapPaint = Paint()
      ..color = endColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(endCapCenter, stroke / 2, endCapPaint);

    final innerShineSweep = g.sweep - capAngle * 0.8;
    if (innerShineSweep > 0.02) {
      final innerShine = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke * 0.28
        ..color = Colors.white.withValues(alpha: 0.30);
      canvas.drawArc(
        ring.shift(Offset(-0.4 * k, -0.9 * k)),
        g.start + capAngle * 0.4,
        innerShineSweep,
        false,
        innerShine,
      );
    }

    final icon = seg.icon;
    if (icon != null && g.sweep * ring.width / 2 > stroke * 1.2) {
      final mid = g.start + g.sweep / 2;
      final pos =
          ring.center + Offset(math.cos(mid), math.sin(mid)) * (ring.width / 2);
      _drawIcon(
        canvas,
        icon,
        pos,
        (stroke * 0.56).clamp(9.0, 24.0),
        Colors.white.withValues(alpha: 0.95),
      );
    }
  }

  /// نقطهٔ زندهٔ «الان» روی حلقه
  void _paintNowDot(
    Canvas canvas,
    Offset center,
    double radius,
    double stroke,
    double k,
  ) {
    final minutes = now.hour * 60 + now.minute + now.second / 60.0;
    final angle = _minuteToAngle(minutes);
    final pos = center + Offset(math.cos(angle), math.sin(angle)) * radius;

    final halo = Paint()
      ..color = Colors.white.withValues(alpha: isDarkMode ? 0.35 : 0.55)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 * k);
    canvas.drawCircle(pos, (stroke * 0.30).clamp(4.0, 12.0), halo);

    final dot = Paint()..color = Colors.white;
    canvas.drawCircle(pos, (stroke * 0.17).clamp(2.5, 7.0), dot);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 * k
      ..color = activeColor.withValues(alpha: 0.55);
    canvas.drawCircle(pos, (stroke * 0.17).clamp(2.5, 7.0), ringPaint);
  }

  /// هاب مرکزی برجسته با ایموجی و نام قلمرو
  void _paintHub(
    Canvas canvas,
    Offset center,
    double radius,
    double stroke,
    double k,
  ) {
    final hubRadius = radius - stroke / 2 - 3.5 * k;
    if (hubRadius <= 8) return;

    final darkShadow = Paint()
      ..color = RealmNeu.shadowDark(isDarkMode)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * k);
    canvas.drawCircle(center + Offset(3 * k, 4.5 * k), hubRadius, darkShadow);

    final lightShadow = Paint()
      ..color = RealmNeu.shadowLight(isDarkMode)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * k);
    canvas.drawCircle(center - Offset(2.5 * k, 3.5 * k), hubRadius, lightShadow);

    final hubRect = Rect.fromCircle(center: center, radius: hubRadius);
    final hubBody = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDarkMode
            ? const [Color(0xFF262E3C), Color(0xFF171C25)]
            : const [Colors.white, Color(0xFFE9ECF3)],
      ).createShader(hubRect);
    canvas.drawCircle(center, hubRadius, hubBody);

    final String emoji;
    if (activeZoneIcon != null && activeZoneIcon!.trim().isNotEmpty) {
      emoji = activeZoneIcon!.trim();
    } else if (activeZoneName.contains('آزاد')) {
      emoji = '✨';
    } else if (activeZoneName.contains('خواب') || activeZoneName.contains('استراحت')) {
      emoji = '😴';
    } else if (activeZoneName.contains('کار') || activeZoneName.contains('تمرکز')) {
      emoji = '💼';
    } else if (activeZoneName.contains('ورزش') || activeZoneName.contains('سلامت')) {
      emoji = '🏃';
    } else if (activeZoneName.contains('مطالعه') || activeZoneName.contains('درس')) {
      emoji = '📚';
    } else if (activeZoneName.contains('طبیعت') || activeZoneName.contains('ریکاوری')) {
      emoji = '🌿';
    } else if (activeZoneName.contains('آرامش') || activeZoneName.contains('مدیتیشن')) {
      emoji = '🧘';
    } else {
      emoji = '✨';
    }

    final compact = hubRadius < 46;
    final nameColor = isDarkMode
        ? Color.lerp(activeColor, Colors.white, 0.35)!
        : activeColor;

    if (compact) {
      _drawText(
        canvas,
        emoji,
        center,
        TextStyle(fontSize: (hubRadius * 0.86).clamp(14.0, 34.0)),
      );
      return;
    }

    _drawText(
      canvas,
      emoji,
      center.translate(0, -hubRadius * 0.34),
      TextStyle(fontSize: (hubRadius * 0.46).clamp(16.0, 44.0)),
    );
    _drawText(
      canvas,
      'الان در قلمرو',
      center.translate(0, hubRadius * 0.14),
      TextStyle(
        fontSize: (hubRadius * 0.155).clamp(9.0, 15.0),
        fontWeight: FontWeight.w600,
        color: RealmNeu.muted(isDarkMode),
      ),
    );
    _drawText(
      canvas,
      activeZoneName,
      center.translate(0, hubRadius * 0.44),
      TextStyle(
        fontSize: (hubRadius * 0.22).clamp(11.0, 22.0),
        fontWeight: FontWeight.w900,
        color: nameColor,
      ),
      maxWidth: hubRadius * 1.7,
    );
  }

  /// برچسب‌های ۰۰:۰۰ / ۰۶:۰۰ / ۱۲:۰۰ / ۱۸:۰۰ دور حلقه
  void _paintHourLabels(
    Canvas canvas,
    Offset center,
    double radius,
    double stroke,
    double k,
    double dim,
  ) {
    const hours = <int>[0, 6, 12, 18];
    final labelStyle = TextStyle(
      fontSize: (dim * 0.042).clamp(8.0, 14.0),
      fontWeight: FontWeight.w700,
      color: RealmNeu.muted(isDarkMode),
      letterSpacing: 0.2,
    );

    for (final h in hours) {
      final angle = _minuteToAngle(h * 60.0);
      final dir = Offset(math.cos(angle), math.sin(angle));

      final dotPaint = Paint()
        ..color = RealmNeu.muted(isDarkMode).withValues(alpha: 0.55);
      canvas.drawCircle(
        center + dir * (radius + stroke / 2 + 3.5 * k),
        (2.0 * k).clamp(1.2, 3.0),
        dotPaint,
      );

      final raw = '${h.toString().padLeft(2, '0')}:00';
      _drawText(
        canvas,
        usePersianDigits ? toPersianDigits(raw) : raw,
        center + dir * (radius + stroke / 2 + 12 * k),
        labelStyle,
      );
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset center,
    TextStyle style, {
    double? maxWidth,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.center,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth ?? double.infinity);

    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _drawIcon(
    Canvas canvas,
    IconData icon,
    Offset center,
    double size,
    Color color,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _NeuDialPainter old) {
    return old.now.minute != now.minute ||
        old.now.second != now.second ||
        old.segments.length != segments.length ||
        old.activeColor != activeColor ||
        old.activeZoneName != activeZoneName ||
        old.activeZoneIcon != activeZoneIcon ||
        old.isDarkMode != isDarkMode ||
        old.showHourLabels != showHourLabels ||
        old.usePersianDigits != usePersianDigits;
  }
}
