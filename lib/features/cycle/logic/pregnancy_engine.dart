import 'dart:math' as math;
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/models/pregnancy_models.dart';

class PregnancyDateEngine {
  const PregnancyDateEngine._();

  /// Calculates Expected Date of Delivery (EDD) from Last Menstrual Period (LMP).
  /// Standard 40 weeks (280 days).
  static DateTime calculateEddFromLmp(DateTime lmp) {
    final clean = CycleDateContract.cleanDate(lmp);
    return clean.add(const Duration(days: PregnancyProfile.gestationTotalDays));
  }

  /// Calculates LMP from given EDD.
  static DateTime calculateLmpFromEdd(DateTime edd) {
    final clean = CycleDateContract.cleanDate(edd);
    return clean.subtract(const Duration(days: PregnancyProfile.gestationTotalDays));
  }

  /// Calculates EDD from known conception date (266 days = 38 weeks).
  static DateTime calculateEddFromConception(DateTime conception) {
    final clean = CycleDateContract.cleanDate(conception);
    return clean.add(const Duration(days: 266));
  }

  /// Calculates EDD from ultrasound Crown-Rump Length (CRL) in millimeters.
  /// CRL must be between 10mm and 84mm.
  /// Uses Robinson & Fleming formula: GA (days) = 8.052 * sqrt(CRL) + 23.73.
  static DateTime calculateEddFromUltrasound({
    required DateTime ultrasoundDate,
    required int crownRumpLengthMm,
  }) {
    final cleanUltrasound = CycleDateContract.cleanDate(ultrasoundDate);
    final crlClamped = crownRumpLengthMm.clamp(10, 84);
    final gaDays = (8.052 * math.sqrt(crlClamped.toDouble()) + 23.73).round();
    final remainingGestationDays = PregnancyProfile.gestationTotalDays - gaDays;
    return cleanUltrasound.add(Duration(days: remainingGestationDays));
  }

  /// Calculates DST-safe day difference between two calendar dates.
  static int dayShiftBetween(DateTime a, DateTime b) {
    final utcA = DateTime.utc(a.year, a.month, a.day);
    final utcB = DateTime.utc(b.year, b.month, b.day);
    return utcB.difference(utcA).inDays;
  }

  /// Calculates current gestational age in weeks, days, and total days.
  static GestationalAge calculateCurrentGestation({
    required DateTime lmp,
    DateTime? now,
  }) {
    final currentNow = now ?? CycleClock.now;
    final totalDays = dayShiftBetween(lmp, currentNow);
    return GestationalAge.fromDays(totalDays);
  }

  /// Calculates pregnancy trimester:
  /// Trimester 1: 1 to 91 days (weeks 1 to 13)
  /// Trimester 2: 92 to 189 days (weeks 14 to 27)
  /// Trimester 3: 190+ days (weeks 28+)
  static int calculateTrimester(int gestationDays) {
    if (gestationDays <= 91) return 1;
    if (gestationDays <= 189) return 2;
    return 3;
  }

  /// Calculates remaining days until delivery, lower bounded at 0.
  static int calculateRemainingDays({
    required DateTime edd,
    DateTime? now,
  }) {
    final currentNow = now ?? CycleClock.now;
    final diff = dayShiftBetween(currentNow, edd);
    return diff < 0 ? 0 : diff;
  }

  /// Formats gestational age into Persian localized string.
  static String formatGestationalAgeFa(
    GestationalAge age, {
    PregnancyAgeUnit unit = PregnancyAgeUnit.weeks,
  }) {
    final weekFa = PersianDigits.toFa(age.weeks.toString());
    if (unit == PregnancyAgeUnit.months) {
      final month = ((age.totalDays / 30.4).floor() + 1).clamp(1, 10);
      final monthFa = PersianDigits.toFa(month.toString());
      return 'ماه $monthFa (هفته $weekFa)';
    }

    if (age.days == 0) {
      return 'هفته $weekFa';
    }
    final daysFa = PersianDigits.toFa(age.days.toString());
    return 'هفته $weekFa و $daysFa روز';
  }

  /// Formats remaining pregnancy time until EDD into Persian localized string.
  static String formatRemainingTimeFa(int remainingDays) {
    if (remainingDays < 0) {
      return 'از موعد گذشته';
    }
    if (remainingDays == 0) {
      return 'امروز روز موعد است';
    }
    final weeks = remainingDays ~/ 7;
    final days = remainingDays % 7;
    final weeksFa = PersianDigits.toFa(weeks.toString());
    final daysFa = PersianDigits.toFa(days.toString());

    if (weeks == 0) {
      return '$daysFa روز تا زایمان';
    }
    if (days == 0) {
      return '$weeksFa هفته تا زایمان';
    }
    return '$weeksFa هفته و $daysFa روز تا زایمان';
  }

  /// Returns true if current date is strictly after EDD.
  static bool isOverdue({
    required DateTime edd,
    DateTime? now,
  }) {
    final currentNow = now ?? CycleClock.now;
    final cleanNow = CycleDateContract.cleanDate(currentNow);
    final cleanEdd = CycleDateContract.cleanDate(edd);
    return cleanNow.isAfter(cleanEdd);
  }

  /// Validates pregnancy date boundaries.
  static PregnancyDateValidationResult validatePregnancyDates({
    required DateTime lmp,
    required DateTime edd,
    DateTime? now,
  }) {
    final currentNow = now ?? CycleClock.now;
    final cleanNow = CycleDateContract.cleanDate(currentNow);
    final cleanLmp = CycleDateContract.cleanDate(lmp);
    final cleanEdd = CycleDateContract.cleanDate(edd);

    if (cleanLmp.isAfter(cleanNow)) {
      return const PregnancyDateValidationResult.invalid(
        errorCode: PregnancyDateErrorCode.futureLmp,
        errorMessageFa: 'تاریخ شروع نمی‌تواند در آینده باشد.',
      );
    }

    if (!cleanEdd.isAfter(cleanLmp)) {
      return const PregnancyDateValidationResult.invalid(
        errorCode: PregnancyDateErrorCode.eddBeforeLmp,
        errorMessageFa: 'تاریخ تخمینی زایمان باید بعد از تاریخ شروع باشد.',
      );
    }

    final spanDays = dayShiftBetween(cleanLmp, cleanEdd);
    if (spanDays < 240 || spanDays > 300) {
      return const PregnancyDateValidationResult.invalid(
        errorCode: PregnancyDateErrorCode.invalidGestationSpan,
        errorMessageFa: 'فاصله زمانی بارداری باید بین ۲۴۰ تا ۳۰۰ روز باشد.',
      );
    }

    final currentDays = dayShiftBetween(cleanLmp, cleanNow);
    if (currentDays < 0) {
      return const PregnancyDateValidationResult.invalid(
        errorCode: PregnancyDateErrorCode.negativeGestation,
        errorMessageFa: 'سن بارداری نمی‌تواند منفی باشد.',
      );
    }

    if (currentDays > 294) {
      return const PregnancyDateValidationResult.invalid(
        errorCode: PregnancyDateErrorCode.gestationExceeds42Weeks,
        errorMessageFa: 'سن بارداری نباید بیشتر از ۴۲ هفته باشد.',
      );
    }

    return const PregnancyDateValidationResult.valid();
  }
}

enum PregnancyDateErrorCode {
  futureLmp,
  eddBeforeLmp,
  invalidGestationSpan,
  gestationExceeds42Weeks,
  negativeGestation,
}

class PregnancyDateValidationResult {
  final bool isValid;
  final String? errorMessageFa;
  final PregnancyDateErrorCode? errorCode;

  const PregnancyDateValidationResult.valid()
      : isValid = true,
        errorMessageFa = null,
        errorCode = null;

  const PregnancyDateValidationResult.invalid({
    required this.errorCode,
    required this.errorMessageFa,
  }) : isValid = false;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PregnancyDateValidationResult &&
          runtimeType == other.runtimeType &&
          isValid == other.isValid &&
          errorMessageFa == other.errorMessageFa &&
          errorCode == other.errorCode;

  @override
  int get hashCode => Object.hash(isValid, errorMessageFa, errorCode);

  @override
  String toString() =>
      'PregnancyDateValidationResult(isValid: $isValid, error: $errorCode, message: $errorMessageFa)';
}
