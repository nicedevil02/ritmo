/// تک‌منبع تبدیل DateTime ↔ کلید تاریخ (yyyy-MM-dd).
/// همیشه بر مبنای تاریخ *محلی* کار می‌کند؛ ورودی UTC اول به محلی تبدیل می‌شود.
abstract final class DateKey {
  static String of(DateTime dt) {
    final local = dt.isUtc ? dt.toLocal() : dt;
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  /// نیمه‌شب محلی همان روز. برای هر مقایسه/محاسبهٔ بازه از این استفاده کن.
  static DateTime dayOf(DateTime dt) {
    final local = dt.isUtc ? dt.toLocal() : dt;
    return DateTime(local.year, local.month, local.day);
  }

  static String today() => of(DateTime.now());

  /// null برای ورودی نامعتبر — هرگز به تاریخ امروز fallback نکن.
  static DateTime? parse(String key) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(key.trim());
    if (m == null) return null;
    final y = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    final d = int.parse(m.group(3)!);
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
    final dt = DateTime(y, mo, d);
    if (dt.month != mo || dt.day != d) return null;
    return dt;
  }

  /// افزودن روز بدون آسیب DST — روی تاریخ تقویمی کار می‌کند، نه Duration.
  static DateTime addDays(DateTime dt, int days) {
    final d = dayOf(dt);
    return DateTime(d.year, d.month, d.day + days);
  }

  /// بررسی برابری تقویمی دو تاریخ بدون در نظر گرفتن ساعت
  static bool isSameDay(DateTime a, DateTime b) => dayOf(a) == dayOf(b);
}
