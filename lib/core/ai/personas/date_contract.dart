import 'package:shamsi_date/shamsi_date.dart';
import 'package:ritmo/core/utils/persian_digits.dart';

/// Contract utilities for dual dates: Jalali in UI reply text, ISO-8601 in command payloads.
class DateContract {
  DateContract._();

  static final RegExp _gregorianRegex = RegExp(r'\b(\d{4})-(\d{1,2})-(\d{1,2})\b');
  static final RegExp _jalaliRegex = RegExp(r'\b(\d{4})[/-](\d{1,2})[/-](\d{1,2})\b');

  /// Checks if [text] contains an ISO Gregorian date like '2026-08-10'.
  static bool hasGregorianDate(String text) {
    return _gregorianRegex.hasMatch(text);
  }

  /// Sanitizes [text] by converting all Gregorian dates into Jalali with Persian digits.
  static String sanitizeGregorianToJalali(String text) {
    if (text.isEmpty) return text;

    return text.replaceAllMapped(_gregorianRegex, (match) {
      final year = int.tryParse(match.group(1)!);
      final month = int.tryParse(match.group(2)!);
      final day = int.tryParse(match.group(3)!);

      if (year != null && month != null && day != null) {
        // Sanity check: Gregorian years are typically > 1900
        if (year >= 1900 && year <= 2100 && month >= 1 && month <= 12 && day >= 1 && day <= 31) {
          try {
            final dt = DateTime(year, month, day);
            final j = Jalali.fromDateTime(dt);
            final jYear = j.year.toString();
            final jMonth = j.month.toString().padLeft(2, '0');
            final jDay = j.day.toString().padLeft(2, '0');
            return PersianDigits.toFa('$jYear/$jMonth/$jDay');
          } catch (_) {
            return match.group(0)!;
          }
        }
      }
      return match.group(0)!;
    });
  }

  /// Converts a Jalali date string ('1405/05/19' or '۱۴۰۵/۰۵/۱۹') to ISO-8601 ('2026-08-10').
  static String? jalaliToIso(String jalaliText) {
    final latinText = PersianDigits.toEnglish(jalaliText);
    final match = _jalaliRegex.firstMatch(latinText);
    if (match == null) return null;

    final year = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final day = int.tryParse(match.group(3)!);

    if (year == null || month == null || day == null) return null;

    try {
      final j = Jalali(year, month, day);
      final dt = j.toDateTime();
      final isoYear = dt.year.toString();
      final isoMonth = dt.month.toString().padLeft(2, '0');
      final isoDay = dt.day.toString().padLeft(2, '0');
      return '$isoYear-$isoMonth-$isoDay';
    } catch (_) {
      return null;
    }
  }
}
