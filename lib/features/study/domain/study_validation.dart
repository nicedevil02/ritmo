import 'package:ritmo/features/study/domain/study_models.dart';

class StudyValidationException implements Exception {
  const StudyValidationException(this.code, this.messageFa);

  final String code;
  final String messageFa;

  @override
  String toString() => 'StudyValidationException($code): $messageFa';
}

abstract final class StudyLimits {
  static const int maxSubjectNameLength = 80;
  static const int maxTopicNameLength = 120;
  static const int maxSessionDurationMinutes = 1440; // 24 hours
  static const int maxWeeklyTargetMinutes = 10080; // 7 * 24 * 60
}

class StudyValidator {
  const StudyValidator._();

  static void validateSubject(StudySubject subject) {
    validateSubjectName(subject.name);
    if (subject.id.trim().isEmpty) {
      throw const StudyValidationException('INVALID_ID', 'شناسه درس نمی‌تواند خالی باشد.');
    }
    if (subject.weeklyTargetMinutes < 0 || subject.weeklyTargetMinutes > StudyLimits.maxWeeklyTargetMinutes) {
      throw const StudyValidationException(
        'INVALID_WEEKLY_TARGET',
        'هدف هفتگی مطالعه نامعتبر است.',
      );
    }
  }

  static void validateSubjectName(
    String name, {
    List<StudySubject> existingSubjects = const [],
    String? currentSubjectId,
  }) {
    final clean = name.trim();
    if (clean.isEmpty) {
      throw const StudyValidationException('EMPTY_NAME', 'نام درس نمی‌تواند خالی باشد.');
    }
    if (clean.length > StudyLimits.maxSubjectNameLength) {
      throw const StudyValidationException(
        'NAME_TOO_LONG',
        'نام درس نمی‌تواند بیش از ۸۰ کاراکتر باشد.',
      );
    }

    final hasDuplicate = existingSubjects.any(
      (s) => s.id != currentSubjectId && s.name.trim().toLowerCase() == clean.toLowerCase(),
    );
    if (hasDuplicate) {
      throw const StudyValidationException(
        'DUPLICATE_NAME',
        'درسی با این نام قبلاً ثبت شده است.',
      );
    }
  }

  static void validateTopic(StudyTopic topic) {
    validateTopicName(topic.name);
    if (topic.id.trim().isEmpty) {
      throw const StudyValidationException('INVALID_ID', 'شناسه سرفصل نمی‌تواند خالی باشد.');
    }
    if (topic.subjectId.trim().isEmpty) {
      throw const StudyValidationException('INVALID_SUBJECT_ID', 'سرفصل باید به یک درس متصل باشد.');
    }
    if (topic.studyCompletedMinutes < 0) {
      throw const StudyValidationException('INVALID_MINUTES', 'مدت مطالعه سرفصل نمی‌تواند منفی باشد.');
    }
  }

  static void validateTopicName(String name) {
    final clean = name.trim();
    if (clean.isEmpty) {
      throw const StudyValidationException('EMPTY_NAME', 'نام سرفصل نمی‌تواند خالی باشد.');
    }
    if (clean.length > StudyLimits.maxTopicNameLength) {
      throw const StudyValidationException(
        'NAME_TOO_LONG',
        'نام سرفصل نمی‌تواند بیش از ۱۲۰ کاراکتر باشد.',
      );
    }
  }

  static void validateSession(StudySession session) {
    if (session.id.trim().isEmpty) {
      throw const StudyValidationException('INVALID_ID', 'شناسه جلسه نمی‌تواند خالی باشد.');
    }
    if (session.subjectId.trim().isEmpty) {
      throw const StudyValidationException('INVALID_SUBJECT_ID', 'درس مربوط به جلسه باید مشخص باشد.');
    }
    if (session.durationMinutes < 0 || session.durationMinutes > StudyLimits.maxSessionDurationMinutes) {
      throw const StudyValidationException(
        'INVALID_DURATION',
        'مدت زمان جلسه مطالعه نامعتبر است.',
      );
    }
    if (session.dateIso.trim().isEmpty) {
      throw const StudyValidationException('INVALID_DATE', 'تاریخ جلسه الزامی است.');
    }
  }
}
