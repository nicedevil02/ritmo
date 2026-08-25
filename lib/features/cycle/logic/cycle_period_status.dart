import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/logic/cycle_period_repository.dart';
import 'package:ritmo/features/cycle/logic/cycle_settings.dart';

/// تنها مرجع برای پاسخ به «این روز چه وضعیتی دارد؟»
/// UI هرگز نباید این محاسبات را دوباره پیاده کند.
class CyclePeriodStatus {
  const CyclePeriodStatus._();

  /// دورهٔ باز (endDate == null) — در صورت وجود چند مورد، جدیدترین بازگردانده می‌شود.
  static CyclePeriod? openPeriod(List<CyclePeriod> periods) {
    final openList = periods.where((p) => p.isOpen).toList();
    if (openList.isEmpty) return null;
    openList.sort((a, b) => b.startDate.compareTo(a.startDate));
    return openList.first;
  }

  /// دورهٔ بازی که از آستانهٔ forgottenOpenPeriodDays گذشته.
  static CyclePeriod? forgottenPeriod(
    List<CyclePeriod> periods,
    DateTime today,
  ) {
    final open = openPeriod(periods);
    if (open == null) return null;
    final elapsed = open.elapsedDaysAt(today);
    if (elapsed >= CycleSettings.forgottenOpenPeriodDays) {
      return open;
    }
    return null;
  }

  /// فقط روزهای قطعی: دورهٔ بسته در بازهٔ [start, end]،
  /// یا دورهٔ باز در بازهٔ [start, today]. هرگز بر اساس pDur حدس نمی‌زند.
  static bool isConfirmedPeriodDay(
    List<CyclePeriod> periods,
    DateTime day,
    DateTime today,
  ) {
    final cleanDay = CycleDateContract.cleanDate(day);
    final cleanToday = CycleDateContract.cleanDate(today);

    for (final p in periods) {
      final cleanStart = CycleDateContract.cleanDate(p.startDate);
      if (p.isOpen) {
        if (CycleDateContract.inWindow(cleanDay, cleanStart, cleanToday)) {
          return true;
        }
      } else {
        final cleanEnd = CycleDateContract.cleanDate(p.endDate!);
        if (CycleDateContract.inWindow(cleanDay, cleanStart, cleanEnd)) {
          return true;
        }
      }
    }
    return false;
  }

  /// شمارهٔ روز درون دورهٔ فعال (۱-مبنا). اگر روز قاعدگی نیست، null.
  /// هرگز فال‌بک 1 برنمی‌گرداند.
  static int? activeDayNumber(List<CyclePeriod> periods, DateTime today) {
    final cleanToday = CycleDateContract.cleanDate(today);
    for (final p in periods) {
      final cleanStart = CycleDateContract.cleanDate(p.startDate);
      if (p.isOpen) {
        if (CycleDateContract.inWindow(cleanToday, cleanStart, cleanToday)) {
          return CycleDateContract.daysBetween(cleanStart, cleanToday) + 1;
        }
      } else {
        final cleanEnd = CycleDateContract.cleanDate(p.endDate!);
        if (CycleDateContract.inWindow(cleanToday, cleanStart, cleanEnd)) {
          return CycleDateContract.daysBetween(cleanStart, cleanToday) + 1;
        }
      }
    }
    return null;
  }

  /// برچسب دکمه: true به معنای «ثبت پایان»، false به معنای «ثبت شروع».
  static bool shouldOfferEnd(List<CyclePeriod> periods, DateTime today) {
    final open = openPeriod(periods);
    if (open == null) return false;
    final cleanToday = CycleDateContract.cleanDate(today);
    final elapsed = open.elapsedDaysAt(cleanToday);
    return elapsed < CycleSettings.forgottenOpenPeriodDays;
  }
}
