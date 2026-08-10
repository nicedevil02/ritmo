import 'package:shamsi_date/shamsi_date.dart';
import 'package:ritmo/core/utils/persian_digits.dart';

/// Pure calculation helpers for Pregnancy UX-01 to UX-15
class PregnancyHelpers {
  /// UX-02 milestone angle calculation (in degrees)
  static double milestoneAngle(int week) {
    final w = week.clamp(1, 40);
    return (w / 40.0) * 360.0;
  }

  /// UX-03 Human-readable countdown text
  static String formatHumanCountdown(int daysLeft) {
    if (daysLeft < 0) {
      return 'از تاریخ تقریبی گذشته است';
    }
    if (daysLeft == 0) {
      return 'امروز روز تخمینی زایمان است 🌸';
    }
    final weeks = daysLeft ~/ 7;
    final days = daysLeft % 7;

    if (weeks == 0) {
      return '${toPersianDigits(days)} روز دیگر';
    }
    if (days == 0) {
      return '${toPersianDigits(weeks)} هفته دیگر';
    }
    return '${toPersianDigits(weeks)} هفته و ${toPersianDigits(days)} روز دیگر';
  }

  /// UX-03 Approx Jalali Month string (e.g., "حدوداً اواخر آبان")
  static String approxJalaliMonth(DateTime edd) {
    final j = Jalali.fromDateTime(edd);
    final day = j.day;
    String prefix;

    if (day <= 10) {
      prefix = 'اوایل';
    } else if (day <= 20) {
      prefix = 'اواسط';
    } else {
      prefix = 'اواخر';
    }

    final monthNames = [
      'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
      'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند'
    ];
    final monthName = monthNames[j.month - 1];

    return 'حدوداً $prefix $monthName';
  }

  /// UX-06 Checkup Window Status String
  static String checkupWindowStatus({
    required int currentWeek,
    required int windowStartWeek,
    required int windowEndWeek,
    required bool isCompleted,
    DateTime? completedDate,
  }) {
    if (isCompleted) {
      if (completedDate != null) {
        final j = Jalali.fromDateTime(completedDate);
        return 'انجام شد در ${toPersianDigits(j.year)}/${toPersianDigits(j.month.toString().padLeft(2, '0'))}/${toPersianDigits(j.day.toString().padLeft(2, '0'))}';
      }
      return 'انجام شد';
    }

    if (currentWeek < windowStartWeek) {
      return 'هنوز باز نشده';
    } else if (currentWeek >= windowStartWeek && currentWeek <= windowEndWeek) {
      final daysRemaining = (windowEndWeek - currentWeek) * 7;
      return 'باز است — ${toPersianDigits(daysRemaining)} روز فرصت دارید';
    } else {
      return 'پنجره بسته شد — در ویزیت بعدی با پزشک مطرح کنید';
    }
  }

  /// UX-08 IOM Pre-pregnancy Weight Gain Band in Kg based on BMI
  static Map<String, double> iomGainBandKg(double bmi) {
    if (bmi < 18.5) {
      return {'min': 12.5, 'max': 18.0};
    } else if (bmi < 25.0) {
      return {'min': 11.5, 'max': 16.0};
    } else if (bmi < 30.0) {
      return {'min': 7.0, 'max': 11.5};
    } else {
      return {'min': 5.0, 'max': 9.0};
    }
  }

  /// UX-09 Red-Flag Symptom Triage Engine
  static List<String> triageRedFlags(List<Map<String, String>> symptomsToday) {
    final flags = <String>[];
    final hasSevereHeadache = symptomsToday.any((s) =>
        (s['code'] == 'headache' || s['code'] == 'HEADACHE') &&
        (s['severity'] == 'SEVERE' || s['severity'] == 'severe'));
    final hasSwelling = symptomsToday.any((s) =>
        s['code'] == 'swelling' || s['code'] == 'SWELLING');
    final hasBlurredVision = symptomsToday.any((s) =>
        s['code'] == 'blurred_vision' || s['code'] == 'BLURRED_VISION');
    final hasBleeding = symptomsToday.any((s) =>
        s['code'] == 'bleeding' || s['code'] == 'BLEEDING');

    if (hasSevereHeadache && hasSwelling) {
      flags.add('سردرد شدید همراه با تورم');
    }
    if (hasSevereHeadache && hasBlurredVision) {
      flags.add('سردرد شدید همراه با تاری دید');
    }
    if (hasBleeding) {
      flags.add('خونریزی بارداری');
    }

    return flags;
  }
}
