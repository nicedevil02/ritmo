import 'package:flutter/foundation.dart';

typedef AnalyticsEventCallback = void Function(String eventName, Map<String, dynamic> parameters);

/// سرویس ثبت رویدادهای تحلیلی ماژول حرکت (Gate 5)
/// شامل ۱۳ رویداد مشخص شده بدون داده‌های سلامت، یادداشت متنی، نام فعالیت سفارشی یا دادهٔ مکانی.
class MovementAnalyticsService {
  MovementAnalyticsService._();
  static final MovementAnalyticsService instance = MovementAnalyticsService._();

  static final List<Map<String, dynamic>> _recordedEventsForTesting = [];
  static AnalyticsEventCallback? _customObserver;

  @visibleForTesting
  static void setObserver(AnalyticsEventCallback? observer) {
    _customObserver = observer;
  }

  @visibleForTesting
  static List<Map<String, dynamic>> get recordedEvents => List.unmodifiable(_recordedEventsForTesting);

  @visibleForTesting
  static void clearEvents() {
    _recordedEventsForTesting.clear();
  }

  void _log(String eventName, Map<String, dynamic> params) {
    final sanitizedParams = Map<String, dynamic>.from(params);
    // تضمین عدم وجود داده‌های حساس
    sanitizedParams.removeWhere((key, value) =>
        key.toLowerCase().contains('note') ||
        key.toLowerCase().contains('health') ||
        key.toLowerCase().contains('customname') ||
        key.toLowerCase().contains('location') ||
        key.toLowerCase().contains('lat') ||
        key.toLowerCase().contains('lng'));

    _recordedEventsForTesting.add({
      'name': eventName,
      'params': sanitizedParams,
      'timestamp': DateTime.now().toIso8601String(),
    });

    if (_customObserver != null) {
      _customObserver!(eventName, sanitizedParams);
    }
  }

  // ۱. ورود به صفحهٔ مرکز حرکت
  void logCenterOpened({
    required String source,
    required bool hasPlan,
    required String heroState,
  }) {
    _log('movement_center_opened', {
      'source': source,
      'has_plan': hasPlan,
      'hero_state': heroState,
    });
  }

  // ۲. انتخاب ردیف در شیت افزودن
  void logAddIntentSelected({
    required String intentType,
  }) {
    _log('movement_add_intent_selected', {
      'intent_type': intentType,
    });
  }

  // ۳. رسیدن به پیش‌نمایش برنامه
  void logPlanPreviewed({
    required String family,
    required int daysCount,
    required bool hasConflict,
  }) {
    _log('movement_plan_previewed', {
      'family': family,
      'days_count': daysCount,
      'has_conflict': hasConflict,
    });
  }

  // ۴. تراکنش موفق ذخیرهٔ برنامه
  void logPlanSaved({
    required int occurrencesCount,
    required String recurrenceType,
  }) {
    _log('movement_plan_saved', {
      'occurrences_count': occurrencesCount,
      'recurrence_type': recurrenceType,
    });
  }

  // ۵. تأیید شیت جابه‌جایی جلسه
  void logOccurrenceMoved({
    required String scope,
    required int dayOffset,
    required String actionSource,
  }) {
    _log('movement_occurrence_moved', {
      'scope': scope,
      'day_offset': dayOffset,
      'action_source': actionSource,
    });
  }

  // ۶. انتخاب گزینه در شیت Plan B
  void logPlanBSelected({
    required String versionType,
    required String trigger,
  }) {
    _log('movement_plan_b_selected', {
      'version_type': versionType,
      'trigger': trigger,
    });
  }

  // ۷. گذار به حالت active در جلسهٔ زنده
  void logSessionStarted({
    required String mode,
    required String startSource,
    required bool hasOccurrence,
  }) {
    _log('movement_session_started', {
      'mode': mode,
      'start_source': startSource,
      'has_occurrence': hasOccurrence,
    });
  }

  // ۸. ادامهٔ جلسه از بنر یا اعلان
  void logSessionResumed({
    required String mode,
    required int pauseDurationSec,
  }) {
    _log('movement_session_resumed', {
      'mode': mode,
      'pause_duration_sec': pauseDurationSec,
    });
  }

  // ۹. اتمام کامل جلسهٔ زنده
  void logSessionCompleted({
    required String mode,
    required int durationSec,
    required bool goalAchieved,
  }) {
    _log('movement_session_completed', {
      'mode': mode,
      'duration_sec': durationSec,
      'goal_achieved': goalAchieved,
    });
  }

  // ۱۰. ثبت جلسهٔ نیمه‌تمام
  void logSessionPartial({
    required String mode,
    required double progressPct,
    String? reason,
  }) {
    _log('movement_session_partial', {
      'mode': mode,
      'progress_pct': progressPct,
      'reason': ?reason,
    });
  }

  // ۱۱. ثبت چک‌این آمادگی
  void logReadinessSubmitted({
    required int filledFieldsCount,
    required String trigger,
  }) {
    _log('movement_readiness_submitted', {
      'filled_fields_count': filledFieldsCount,
      'trigger': trigger,
    });
  }

  // ۱۲. پایان گام ۵ آنبوردینگ قدرت
  void logStrengthOnboardingCompleted({
    required String goal,
    required int daysPerWeek,
    required int equipmentCount,
  }) {
    _log('strength_onboarding_completed', {
      'goal': goal,
      'days_per_week': daysPerWeek,
      'equipment_count': equipmentCount,
    });
  }

  // ۱۳. فعال‌سازی موفق برنامهٔ قدرت
  void logStrengthProgramActivated({
    required int totalWeeks,
    required int sessionsPerWeek,
  }) {
    _log('strength_program_activated', {
      'total_weeks': totalWeeks,
      'sessions_per_week': sessionsPerWeek,
    });
  }
}
