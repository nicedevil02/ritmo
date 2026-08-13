/// محاسبات «دقیقه از روز» — تنها پیاده‌سازی مجازِ اختلاف ساعت با عبور از نیمه‌شب.
///
/// این الگو قبلاً در چهار نقطه کپی شده بود (SleepEngine._calculateConsistency،
/// SleepLog.deviationMinutes و دو متد در SleepLastNightSection). طبق سند
/// «مسیر خواب» (اصل ۷)، پیاده‌سازی دوبارهٔ این منطق در جای دیگر ممنوع است.
abstract final class RitmoTime {
  /// اختلاف علامت‌دار (دقیقه) بین دو «دقیقه از روز» در کوتاه‌ترین مسیر روی ساعت ۲۴ساعته.
  ///
  /// خروجی در بازهٔ `(-720, 720]` است؛ مقدار مثبت یعنی [actualMinOfDay] دیرتر از
  /// [targetMinOfDay] است. مثال: actual=00:30 (سی)، target=23:30 ⇒ ‎+۶۰ (نه ‎-۱۳۸۰).
  static int signedMinuteDiff(int actualMinOfDay, int targetMinOfDay) {
    var diff = actualMinOfDay - targetMinOfDay;
    if (diff > 720) diff -= 1440;
    if (diff < -720) diff += 1440;
    return diff;
  }

  /// فاصلهٔ مطلق (دقیقه) روی ساعت ۲۴ساعته — همیشه در بازهٔ `[0, 720]`.
  static int absMinuteDiff(int actualMinOfDay, int targetMinOfDay) =>
      signedMinuteDiff(actualMinOfDay, targetMinOfDay).abs();
}
