// F-05: CycleClock Central Time Provider for Deterministic Testing

/// ساعت مرکزی دامنهٔ چرخهٔ بدن ریتمو جهت امکان تزریق زمان در آزمون‌های خودکار.
abstract final class CycleClock {
  /// تابع تأمین‌کنندهٔ زمان فعلی. در محیط عملیاتی DateTime.now است.
  static DateTime Function() nowProvider = DateTime.now;

  /// زمان فعلی
  static DateTime get now => nowProvider();

  /// میلی‌ثانیهٔ زمان فعلی
  static int get nowMillisecondsSinceEpoch => now.millisecondsSinceEpoch;

  /// بازنشانی تأمین‌کننده به حالت پیش‌فرض
  static void reset() {
    nowProvider = DateTime.now;
  }
}
