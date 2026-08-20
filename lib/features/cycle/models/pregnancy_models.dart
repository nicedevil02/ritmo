import 'package:flutter/foundation.dart';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';

enum PregnancyEddSource {
  lmp,
  ultrasound,
  doctorEdd;

  String get storageValue {
    switch (this) {
      case PregnancyEddSource.lmp:
        return 'lmp';
      case PregnancyEddSource.ultrasound:
        return 'ultrasound';
      case PregnancyEddSource.doctorEdd:
        return 'doctor_edd';
    }
  }

  static PregnancyEddSource fromStorage(String? raw) {
    if (raw == null) return PregnancyEddSource.lmp;
    final trimmed = raw.trim().toLowerCase();
    switch (trimmed) {
      case 'ultrasound':
        return PregnancyEddSource.ultrasound;
      case 'doctor_edd':
        return PregnancyEddSource.doctorEdd;
      case 'lmp':
      default:
        return PregnancyEddSource.lmp;
    }
  }
}

enum PregnancyTone {
  warm,
  neutral;

  String get storageValue {
    switch (this) {
      case PregnancyTone.warm:
        return 'warm';
      case PregnancyTone.neutral:
        return 'neutral';
    }
  }

  static PregnancyTone fromStorage(String? raw) {
    if (raw == null) return PregnancyTone.warm;
    final trimmed = raw.trim().toLowerCase();
    switch (trimmed) {
      case 'neutral':
      case 'calm':
        return PregnancyTone.neutral;
      case 'warm':
      default:
        return PregnancyTone.warm;
    }
  }
}

enum PregnancyAgeUnit {
  weeks,
  months;

  String get storageValue {
    switch (this) {
      case PregnancyAgeUnit.weeks:
        return 'weeks';
      case PregnancyAgeUnit.months:
        return 'months';
    }
  }

  static PregnancyAgeUnit fromStorage(String? raw) {
    if (raw == null) return PregnancyAgeUnit.weeks;
    final trimmed = raw.trim().toLowerCase();
    switch (trimmed) {
      case 'months':
        return PregnancyAgeUnit.months;
      case 'weeks':
      default:
        return PregnancyAgeUnit.weeks;
    }
  }
}

@immutable
class PregnancyProfile {
  static const int defaultKickTargetCount = 10;
  static const int defaultKickWindowMinutes = 120;
  static const int defaultVisitReminderLeadDays = 2;
  static const int defaultReminderHour = 10;
  static const int gestationTotalDays = 280;
  static const int maxGestationDays = 300;
  static const int minGestationDays = 0;

  final DateTime lmpDate;
  final DateTime dueDate;
  final PregnancyEddSource eddSource;
  final PregnancyTone tone;
  final PregnancyAgeUnit ageUnit;
  final bool isMultiple;
  final bool isHighRisk;
  final bool sectionHidden;
  final bool maskNotifications;
  final bool lockEnabled;
  final bool cycleResumeReminder;
  final int kickTargetCount;
  final int kickWindowMinutes;
  final bool kickBaselineComparison;
  final int visitReminderLeadDays;
  final int reminderHour;
  final bool showCountdown;
  final bool supplementReminder;
  final bool kickReminder;

  const PregnancyProfile({
    required this.lmpDate,
    required this.dueDate,
    this.eddSource = PregnancyEddSource.lmp,
    this.tone = PregnancyTone.warm,
    this.ageUnit = PregnancyAgeUnit.weeks,
    this.isMultiple = false,
    this.isHighRisk = false,
    this.sectionHidden = false,
    this.maskNotifications = false,
    this.lockEnabled = false,
    this.cycleResumeReminder = false,
    this.kickTargetCount = defaultKickTargetCount,
    this.kickWindowMinutes = defaultKickWindowMinutes,
    this.kickBaselineComparison = false,
    this.visitReminderLeadDays = defaultVisitReminderLeadDays,
    this.reminderHour = defaultReminderHour,
    this.showCountdown = true,
    this.supplementReminder = false,
    this.kickReminder = false,
  });

  PregnancyProfile copyWith({
    DateTime? lmpDate,
    DateTime? dueDate,
    PregnancyEddSource? eddSource,
    PregnancyTone? tone,
    PregnancyAgeUnit? ageUnit,
    bool? isMultiple,
    bool? isHighRisk,
    bool? sectionHidden,
    bool? maskNotifications,
    bool? lockEnabled,
    bool? cycleResumeReminder,
    int? kickTargetCount,
    int? kickWindowMinutes,
    bool? kickBaselineComparison,
    int? visitReminderLeadDays,
    int? reminderHour,
    bool? showCountdown,
    bool? supplementReminder,
    bool? kickReminder,
  }) {
    return PregnancyProfile(
      lmpDate: lmpDate ?? this.lmpDate,
      dueDate: dueDate ?? this.dueDate,
      eddSource: eddSource ?? this.eddSource,
      tone: tone ?? this.tone,
      ageUnit: ageUnit ?? this.ageUnit,
      isMultiple: isMultiple ?? this.isMultiple,
      isHighRisk: isHighRisk ?? this.isHighRisk,
      sectionHidden: sectionHidden ?? this.sectionHidden,
      maskNotifications: maskNotifications ?? this.maskNotifications,
      lockEnabled: lockEnabled ?? this.lockEnabled,
      cycleResumeReminder: cycleResumeReminder ?? this.cycleResumeReminder,
      kickTargetCount: kickTargetCount ?? this.kickTargetCount,
      kickWindowMinutes: kickWindowMinutes ?? this.kickWindowMinutes,
      kickBaselineComparison:
          kickBaselineComparison ?? this.kickBaselineComparison,
      visitReminderLeadDays:
          visitReminderLeadDays ?? this.visitReminderLeadDays,
      reminderHour: reminderHour ?? this.reminderHour,
      showCountdown: showCountdown ?? this.showCountdown,
      supplementReminder: supplementReminder ?? this.supplementReminder,
      kickReminder: kickReminder ?? this.kickReminder,
    );
  }

  Map<String, String> toMap() {
    return {
      'preg_start_date': CycleDateContract.toDayKey(lmpDate),
      'preg_due_date': CycleDateContract.toDayKey(dueDate),
      'preg_edd_source': eddSource.storageValue,
      'preg_tone': tone.storageValue,
      'preg_age_unit': ageUnit.storageValue,
      'preg_is_multiple': isMultiple.toString(),
      'preg_is_high_risk': isHighRisk.toString(),
      'preg_section_hidden': sectionHidden.toString(),
      'preg_mask_notifications': maskNotifications.toString(),
      'preg_lock_enabled': lockEnabled.toString(),
      'preg_cycle_resume_reminder': cycleResumeReminder.toString(),
      'preg_kick_target_count': kickTargetCount.toString(),
      'preg_kick_window_minutes': kickWindowMinutes.toString(),
      'preg_kick_baseline_compare': kickBaselineComparison.toString(),
      'preg_visit_reminder_lead_days': visitReminderLeadDays.toString(),
      'preg_reminder_hour': reminderHour.toString(),
      'preg_show_countdown': showCountdown.toString(),
      'preg_supplement_reminder': supplementReminder.toString(),
      'preg_kick_reminder': kickReminder.toString(),
    };
  }

  factory PregnancyProfile.fromMap(Map<String, dynamic> map) {
    final cleanNow = CycleDateContract.cleanDate(CycleClock.now);
    final parsedLmp = CycleDateContract.parseDayKey(
      map['preg_start_date']?.toString(),
    );
    final lmp = parsedLmp ?? cleanNow;

    final parsedDue = CycleDateContract.parseDayKey(
      map['preg_due_date']?.toString(),
    );
    final due = parsedDue ?? lmp.add(const Duration(days: gestationTotalDays));

    return PregnancyProfile(
      lmpDate: lmp,
      dueDate: due,
      eddSource: PregnancyEddSource.fromStorage(
        map['preg_edd_source']?.toString(),
      ),
      tone: PregnancyTone.fromStorage(map['preg_tone']?.toString()),
      ageUnit: PregnancyAgeUnit.fromStorage(map['preg_age_unit']?.toString()),
      isMultiple: map['preg_is_multiple']?.toString() == 'true',
      isHighRisk: map['preg_is_high_risk']?.toString() == 'true',
      sectionHidden: map['preg_section_hidden']?.toString() == 'true',
      maskNotifications: map['preg_mask_notifications']?.toString() == 'true',
      lockEnabled: map['preg_lock_enabled']?.toString() == 'true',
      cycleResumeReminder:
          map['preg_cycle_resume_reminder']?.toString() == 'true',
      kickTargetCount:
          int.tryParse(map['preg_kick_target_count']?.toString() ?? '') ??
          defaultKickTargetCount,
      kickWindowMinutes:
          int.tryParse(map['preg_kick_window_minutes']?.toString() ?? '') ??
          defaultKickWindowMinutes,
      kickBaselineComparison:
          map['preg_kick_baseline_compare']?.toString() == 'true',
      visitReminderLeadDays:
          int.tryParse(
            map['preg_visit_reminder_lead_days']?.toString() ?? '',
          ) ??
          defaultVisitReminderLeadDays,
      reminderHour:
          int.tryParse(map['preg_reminder_hour']?.toString() ?? '') ??
          defaultReminderHour,
      showCountdown: map['preg_show_countdown']?.toString() != 'false',
      supplementReminder: map['preg_supplement_reminder']?.toString() == 'true',
      kickReminder: map['preg_kick_reminder']?.toString() == 'true',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PregnancyProfile &&
          runtimeType == other.runtimeType &&
          CycleDateContract.isSameDay(lmpDate, other.lmpDate) &&
          CycleDateContract.isSameDay(dueDate, other.dueDate) &&
          eddSource == other.eddSource &&
          tone == other.tone &&
          ageUnit == other.ageUnit &&
          isMultiple == other.isMultiple &&
          isHighRisk == other.isHighRisk &&
          sectionHidden == other.sectionHidden &&
          maskNotifications == other.maskNotifications &&
          lockEnabled == other.lockEnabled &&
          cycleResumeReminder == other.cycleResumeReminder &&
          kickTargetCount == other.kickTargetCount &&
          kickWindowMinutes == other.kickWindowMinutes &&
          kickBaselineComparison == other.kickBaselineComparison &&
          visitReminderLeadDays == other.visitReminderLeadDays &&
          reminderHour == other.reminderHour;

  @override
  int get hashCode => Object.hash(
    CycleDateContract.toDayKey(lmpDate),
    CycleDateContract.toDayKey(dueDate),
    eddSource,
    tone,
    ageUnit,
    isMultiple,
    isHighRisk,
    sectionHidden,
    maskNotifications,
    lockEnabled,
    cycleResumeReminder,
    kickTargetCount,
    kickWindowMinutes,
    kickBaselineComparison,
    visitReminderLeadDays,
    reminderHour,
  );
}

@immutable
class GestationalAge {
  final int weeks;
  final int days;
  final int totalDays;

  const GestationalAge({
    required this.weeks,
    required this.days,
    required this.totalDays,
  });

  factory GestationalAge.fromDays(int totalDays) {
    final clamped = totalDays < 0 ? 0 : totalDays;
    final w = clamped ~/ 7;
    final d = clamped % 7;
    return GestationalAge(weeks: w, days: d, totalDays: clamped);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GestationalAge &&
          runtimeType == other.runtimeType &&
          weeks == other.weeks &&
          days == other.days &&
          totalDays == other.totalDays;

  @override
  int get hashCode => Object.hash(weeks, days, totalDays);

  @override
  String toString() =>
      'GestationalAge(weeks: $weeks, days: $days, totalDays: $totalDays)';
}

@immutable
class PregnancyOnboardingData {
  final PregnancyTone tone;
  final PregnancyEddSource eddSource;
  final DateTime? lmpDate;
  final DateTime? dueDate;
  final DateTime? scanDate;
  final int scanWeeks;
  final int scanDays;
  final bool isMultiple;
  final bool isHighRisk;
  final bool pauseCyclePredictions;
  final bool suspendWorship;
  final bool lockEnabled;
  final bool hideFromDashboard;
  final bool maskNotifications;
  final PregnancyAgeUnit ageUnit;

  const PregnancyOnboardingData({
    this.tone = PregnancyTone.warm,
    this.eddSource = PregnancyEddSource.lmp,
    this.lmpDate,
    this.dueDate,
    this.scanDate,
    this.scanWeeks = 8,
    this.scanDays = 0,
    this.isMultiple = false,
    this.isHighRisk = false,
    this.pauseCyclePredictions = true,
    this.suspendWorship = false,
    this.lockEnabled = false,
    this.hideFromDashboard = true,
    this.maskNotifications = true,
    this.ageUnit = PregnancyAgeUnit.weeks,
  });

  PregnancyOnboardingData copyWith({
    PregnancyTone? tone,
    PregnancyEddSource? eddSource,
    DateTime? lmpDate,
    DateTime? dueDate,
    DateTime? scanDate,
    int? scanWeeks,
    int? scanDays,
    bool? isMultiple,
    bool? isHighRisk,
    bool? pauseCyclePredictions,
    bool? suspendWorship,
    bool? lockEnabled,
    bool? hideFromDashboard,
    bool? maskNotifications,
    PregnancyAgeUnit? ageUnit,
  }) {
    return PregnancyOnboardingData(
      tone: tone ?? this.tone,
      eddSource: eddSource ?? this.eddSource,
      lmpDate: lmpDate ?? this.lmpDate,
      dueDate: dueDate ?? this.dueDate,
      scanDate: scanDate ?? this.scanDate,
      scanWeeks: scanWeeks ?? this.scanWeeks,
      scanDays: scanDays ?? this.scanDays,
      isMultiple: isMultiple ?? this.isMultiple,
      isHighRisk: isHighRisk ?? this.isHighRisk,
      pauseCyclePredictions:
          pauseCyclePredictions ?? this.pauseCyclePredictions,
      suspendWorship: suspendWorship ?? this.suspendWorship,
      lockEnabled: lockEnabled ?? this.lockEnabled,
      hideFromDashboard: hideFromDashboard ?? this.hideFromDashboard,
      maskNotifications: maskNotifications ?? this.maskNotifications,
      ageUnit: ageUnit ?? this.ageUnit,
    );
  }
}
