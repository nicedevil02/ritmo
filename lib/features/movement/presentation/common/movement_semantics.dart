import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/domain/models/movement_occurrence.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

abstract final class MovementSemantics {
  /// برچسب Semantics برای اسلات روز در ریل هفته
  static String dayLabel({
    required String dayName,
    required int dayNumber,
    required String monthName,
    required int sessionCount,
    required int completedCount,
    required bool isSelected,
    required bool isToday,
  }) {
    final buffer = StringBuffer();
    if (isToday) {
      buffer.write('امروز، ');
    }
    buffer.write('$dayName ${toPersianDigits(dayNumber)} $monthName');

    if (sessionCount == 0) {
      buffer.write('، بدون جلسه');
    } else {
      buffer.write('، ${toPersianDigits(sessionCount)} جلسه');
      if (completedCount > 0) {
        if (completedCount == 1) {
          buffer.write('، یکی انجام شده');
        } else {
          buffer.write('، ${toPersianDigits(completedCount)} انجام شده');
        }
      }
    }

    if (isSelected) {
      buffer.write('، انتخاب‌شده');
    }

    return buffer.toString();
  }

  /// برچسب فارسی وضعیت رخداد — Semantics هرگز نام انگلیسی enum نمی‌گیرد
  static String occurrenceStatusLabel(MovementOccurrenceStatus status) {
    return switch (status) {
      MovementOccurrenceStatus.planned => MovementStrings.statusPlanned,
      MovementOccurrenceStatus.inProgress => MovementStrings.statusInProgress,
      MovementOccurrenceStatus.completed => MovementStrings.statusCompleted,
      MovementOccurrenceStatus.partial => MovementStrings.statusPartial,
      MovementOccurrenceStatus.skipped => MovementStrings.statusSkipped,
      MovementOccurrenceStatus.moved => MovementStrings.statusMoved,
      MovementOccurrenceStatus.late => MovementStrings.statusLate,
      MovementOccurrenceStatus.restDay => MovementStrings.statusRestDay,
    };
  }

  /// برچسب Semantics برای کارت جلسه
  static String sessionCardLabel({
    required String title,
    required String timeOrDuration,
    required String targetOrType,
    required String status,
  }) {
    final timeStr = toPersianDigits(timeOrDuration);
    return 'جلسه: $title، زمان: $timeStr، هدف: $targetOrType، وضعیت: $status';
  }

  /// برچسب Semantics برای مقدار متریک
  static String metricLabel({
    required String label,
    required String value,
    String? unit,
  }) {
    final valStr = toPersianDigits(value);
    if (unit != null && unit.isNotEmpty) {
      return '$label: $valStr $unit';
    }
    return '$label: $valStr';
  }

  /// برچسب Semantics برای ردیف ست تمرین قدرتی
  static String strengthSetRowLabel({
    required int setNumber,
    required String reps,
    required String weight,
    required bool isCompleted,
  }) {
    final sNum = toPersianDigits(setNumber);
    final rStr = toPersianDigits(reps);
    final wStr = toPersianDigits(weight);
    final statusStr = isCompleted ? 'انجام شده' : 'انجام نشده';
    return 'ست $sNum: $rStr تکرار، $wStr کیلوگرم، $statusStr';
  }
}
