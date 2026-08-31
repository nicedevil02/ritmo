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

import 'package:flutter/material.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_marble_core.dart';

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
class RitmoSiriOrb extends StatelessWidget {
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

  /// آیا انیمیشن فعال باشد؟
  final bool isAnimated;

  /// زاویه شیب پارالاکس لمسی یا ژیروسکوپ (-1.0 تا 1.0)
  final Offset tiltOffset;

  /// ضریب کشسانی مایع هنگام لمس
  final double squeezeFactor;

  /// پالت رنگی درون تیله
  final RitmoOrbPalette palette;

  /// شدت کلی رنگ‌ها
  final double intensity;

  /// ضریب سرعت جریان رنگ‌ها
  final double speed;

  /// دانهٔ نویز
  final int seed;

  @override
  Widget build(BuildContext context) {
    return RitmoMarbleCore(
      size: size,
      mode: mode,
      glowEnabled: glowEnabled,
      isAnimated: isAnimated,
      tiltOffset: tiltOffset,
      squeezeFactor: squeezeFactor,
      palette: palette,
      intensity: intensity,
      speed: speed,
      seed: seed,
    );
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
