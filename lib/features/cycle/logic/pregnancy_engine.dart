import 'dart:math' as math;
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

  /// Calculates current gestational age in weeks, days, and total days.
  static GestationalAge calculateCurrentGestation({
    required DateTime lmp,
    DateTime? now,
  }) {
    final cleanNow = CycleDateContract.cleanDate(now ?? CycleClock.now);
    final cleanLmp = CycleDateContract.cleanDate(lmp);
    final totalDays = CycleDateContract.daysBetween(cleanLmp, cleanNow);
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
    final cleanNow = CycleDateContract.cleanDate(now ?? CycleClock.now);
    final cleanEdd = CycleDateContract.cleanDate(edd);
    final diff = CycleDateContract.daysBetween(cleanNow, cleanEdd);
    return diff < 0 ? 0 : diff;
  }

  /// Returns true if current date is strictly after EDD.
  static bool isOverdue({
    required DateTime edd,
    DateTime? now,
  }) {
    final cleanNow = CycleDateContract.cleanDate(now ?? CycleClock.now);
    final cleanEdd = CycleDateContract.cleanDate(edd);
    return cleanNow.isAfter(cleanEdd);
  }
}
