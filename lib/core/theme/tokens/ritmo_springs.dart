import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// توکن‌های فنر حرکتی — RFC «Ritmo Aurora» §۵.۶
///
/// قانون مصرف: انیمیشن‌های implicit مثل `AnimatedContainer` و
/// `AnimatedOpacity` ورودی [SpringDescription] نمی‌گیرند. فنر را فقط از این
/// مسیرها مصرف کن:
///
/// ```dart
/// controller.animateWith(
///   SpringSimulation(RitmoSprings.spatial, begin, end, velocity),
/// );
/// // یا با هلپر زیر:
/// controller.animateToSpring(1, RitmoSprings.spatialFast);
/// ```
///
/// مسیرهای مبتنی بر Duration همچنان از `RitmoMotion` تغذیه می‌شوند؛ این دو
/// سیستم را با هم قاطی نکن.
abstract final class RitmoSprings {
  /// جابه‌جایی فضایی سریع با overshoot محسوس (مثلاً مورف دکمه‌ی مرکزی ناوبری).
  static final SpringDescription spatialFast =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 800, ratio: 0.6);

  /// جابه‌جایی فضایی استاندارد — پیش‌فرض بیشتر حرکت‌های مکانی.
  static final SpringDescription spatial = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 380,
    ratio: 0.8,
  );

  /// جابه‌جایی فضایی آهسته برای سطوح بزرگ (شیت‌ها و گذارهای صفحه).
  static final SpringDescription spatialSlow =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 200, ratio: 0.8);

  /// تغییر افکت‌ها (رنگ، آلفا، بلور) — نرم و بدون overshoot.
  static final SpringDescription effects = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 1600,
    ratio: 1.0,
  );
}

/// هلپر مصرف فنر روی [AnimationController].
extension RitmoSpringAnimation on AnimationController {
  /// اجرای فنر از مقدار فعلی به [target].
  ///
  /// با [reduceMotion] (از `RitmoMotion.reduceMotion`) سازگار است: وقتی کاربر
  /// کاهش حرکت را فعال کرده باشد، به‌جای انیمیشن مستقیم به مقصد می‌پرد.
  TickerFuture animateToSpring(
    double target,
    SpringDescription spring, {
    bool reduceMotion = false,
  }) {
    if (reduceMotion) {
      value = target;
      return TickerFuture.complete();
    }
    return animateWith(SpringSimulation(spring, value, target, velocity));
  }
}
