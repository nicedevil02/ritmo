import 'package:ritmo/features/courses/models/course_models.dart';

class CourseValidationException implements Exception {
  CourseValidationException(this.code, this.messageFa);

  final String code;
  final String messageFa;

  @override
  String toString() => 'CourseValidationException($code): $messageFa';
}

class CourseValidator {
  static void validateCourse(Course c) {
    final title = c.title.trim();
    if (title.isEmpty) {
      throw CourseValidationException('INVALID_TITLE', 'عنوان دوره نمی‌تواند خالی باشد.');
    }
    if (title.length > 120) {
      throw CourseValidationException('TITLE_TOO_LONG', 'عنوان دوره نمی‌تواند بیش از ۱۲۰ کاراکتر باشد.');
    }
    if (c.totalSessions < CourseLimits.minTotalSessions || c.totalSessions > CourseLimits.maxTotalSessions) {
      throw CourseValidationException('INVALID_TOTAL_SESSIONS', 'تعداد جلسات باید بین ${CourseLimits.minTotalSessions} تا ${CourseLimits.maxTotalSessions} باشد.');
    }
    if (c.sessionDurationMinutes < CourseLimits.minSessionDurationMinutes || c.sessionDurationMinutes > CourseLimits.maxSessionDurationMinutes) {
      throw CourseValidationException('INVALID_DURATION', 'مدت زمان هر جلسه باید بین ${CourseLimits.minSessionDurationMinutes} تا ${CourseLimits.maxSessionDurationMinutes} دقیقه باشد.');
    }
    if (c.weeklyTargetSessions < CourseLimits.minWeeklyTarget || c.weeklyTargetSessions > CourseLimits.maxWeeklyTarget) {
      throw CourseValidationException('INVALID_WEEKLY_TARGET', 'هدف هفتگی باید بین ${CourseLimits.minWeeklyTarget} تا ${CourseLimits.maxWeeklyTarget} جلسه باشد.');
    }

    final validDaysCount = c.preferredDays.where((d) => d >= 0 && d <= 6).toSet().length;
    if (validDaysCount == 0 && c.preferredDays.isNotEmpty) {
      throw CourseValidationException('INVALID_PREFERRED_DAYS', 'روزهای ترجیحی انتخاب‌شده نامعتبر هستند.');
    }
    if (validDaysCount > 0) {
      final maxWeeklyPossible = validDaysCount * CourseLimits.maxSessionsPerDay;
      if (c.weeklyTargetSessions > maxWeeklyPossible) {
        throw CourseValidationException(
          'TARGET_EXCEEDS_CAPACITY',
          'هدف هفتگی (${c.weeklyTargetSessions}) بیش از حداکثر ظرفیت روزهای انتخابی ($maxWeeklyPossible جلسه) است.',
        );
      }
    }

    if (c.reminderEnabled) {
      if (c.preferredTime == null || c.preferredTime!.trim().isEmpty) {
        throw CourseValidationException('INVALID_REMINDER_TIME', 'برای فعال‌سازی یادآور، زمان یادآوری باید مشخص شود.');
      }
      final parts = c.preferredTime!.split(':');
      if (parts.length != 2) {
        throw CourseValidationException('INVALID_REMINDER_TIME', 'فرمت زمان یادآوری باید HH:mm باشد.');
      }
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
        throw CourseValidationException('INVALID_REMINDER_TIME', 'ساعت یا دقیقه یادآوری نامعتبر است.');
      }
    }
  }

  static int _farsiDayRank(int d) {
    // Saturday(6)=0, Sunday(0)=1, Monday(1)=2, Tuesday(2)=3, Wednesday(3)=4, Thursday(4)=5, Friday(5)=6
    switch (d) {
      case 6:
        return 0;
      case 0:
        return 1;
      case 1:
        return 2;
      case 2:
        return 3;
      case 3:
        return 4;
      case 4:
        return 5;
      case 5:
        return 6;
      default:
        return 7;
    }
  }

  static List<int> normalizePreferredDays(List<int> days) {
    final valid = days.where((d) => d >= 0 && d <= 6).toSet().toList();
    if (valid.isEmpty) {
      return [6, 1, 3]; // Default: Saturday, Monday, Wednesday (شنبه، دوشنبه، چهارشنبه)
    }
    valid.sort((a, b) => _farsiDayRank(a).compareTo(_farsiDayRank(b)));
    return valid;
  }
}
