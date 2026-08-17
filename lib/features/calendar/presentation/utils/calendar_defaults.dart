class CalendarDefaults {
  const CalendarDefaults._();
  static const int fallbackDurationMinutes = 30;
  static const String fallbackTimeOfDay = '08:00';
  static const int snapIntervalMinutes = 15;
  static const int minDurationMinutes = 15;
  /// سقف مدت، تک‌منبع در DurationBounds است. اینجا تکرارش نکن.
}

abstract final class CalendarMessagesFa {
  static const load = 'بارگذاری برنامه‌ها ناموفق بود. اتصال یا داده‌ها را بررسی کنید.';
  static const complete = 'ثبت انجام‌شدن این مورد ناموفق بود.';
  static const postpone = 'به‌تعویق‌انداختن این مورد ناموفق بود.';
  static const skip = 'رد کردن این مورد ناموفق بود.';
  static const move = 'جابه‌جایی این مورد ناموفق بود.';
  static const resize = 'تغییر مدت این مورد ناموفق بود.';
  static const schedule = 'زمان‌بندی این مورد ناموفق بود.';
  static const unschedule = 'لغو زمان‌بندی این مورد ناموفق بود.';
  static const notSupported = 'این عملیات برای این نوع مورد پشتیبانی نمی‌شود.';
  static const overlap = 'این بازه با یک مورد دیگر تداخل دارد.';
  static const invalidTime = 'زمان انتخاب‌شده معتبر نیست.';
}
