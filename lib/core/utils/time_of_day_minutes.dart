import 'package:ritmo/core/utils/persian_digits.dart';

/// تک‌منبع تبدیل 'HH:mm' ↔ دقیقهٔ روز (۰..۱۴۳۹).
abstract final class TimeOfDayMinutes {
  /// null برای ورودی نامعتبر. هرگز به ۰ سقوط نکن.
  static int? tryParse(String? raw) {
    if (raw == null) return null;
    // ارقام فارسی/عربی را هم بپذیر: کاربر و مدل هوش مصنوعی هر دو می‌فرستند.
    final value = toEnglishDigits(raw.trim());
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value);
    if (m == null) return null;
    final h = int.parse(m.group(1)!);
    final min = int.parse(m.group(2)!);
    if (h < 0 || h > 23 || min < 0 || min > 59) return null;
    return h * 60 + min;
  }

  static String format(int minutesOfDay) {
    final c = minutesOfDay.clamp(0, 1439);
    return '${(c ~/ 60).toString().padLeft(2, '0')}:'
        '${(c % 60).toString().padLeft(2, '0')}';
  }

  static bool isValid(String? raw) => tryParse(raw) != null;
}
