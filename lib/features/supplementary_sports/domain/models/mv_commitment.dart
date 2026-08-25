import 'package:flutter/foundation.dart';

enum CommitmentRecurrence {
  weekly('WEEKLY', 'هر هفته'),
  biweekly('BIWEEKLY', 'یک‌هفته‌درمیان'),
  once('ONCE', 'فقط یک‌بار');

  final String code;
  final String titleFa;
  const CommitmentRecurrence(this.code, this.titleFa);

  static CommitmentRecurrence fromCode(String code) {
    return CommitmentRecurrence.values.firstWhere(
      (r) => r.code.toUpperCase() == code.toUpperCase(),
      orElse: () => CommitmentRecurrence.weekly,
    );
  }
}

/// مدل ایمیوتبل تعهد ورزشی ثابت (لنگر) کاربر
@immutable
class MvCommitment {
  static final RegExp _timeRegex = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
  static const List<String> persianWeekdays = [
    'شنبه',
    'یک‌شنبه',
    'دوشنبه',
    'سه‌شنبه',
    'چهارشنبه',
    'پنج‌شنبه',
    'جمعه',
  ];

  final int? id;
  final String kindCode;
  final String? titleFa;
  final int dayOfWeekSat0; // 0=شنبه .. 6=جمعه
  final String startTime; // HH:mm
  final int durationMinutes;
  final String? venueNote;
  final String? partnerNote;
  final CommitmentRecurrence recurrence;
  final bool isActive;
  final bool isFlexible;
  final String? startDateIso;
  final String? endDateIso;
  final int? reminderMinutes;
  final String createdAt;
  final String updatedAt;

  MvCommitment({
    this.id,
    required this.kindCode,
    this.titleFa,
    required this.dayOfWeekSat0,
    required this.startTime,
    required this.durationMinutes,
    this.venueNote,
    this.partnerNote,
    this.recurrence = CommitmentRecurrence.weekly,
    this.isActive = true,
    this.isFlexible = false,
    this.startDateIso,
    this.endDateIso,
    this.reminderMinutes,
    String? createdAt,
    String? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now().toIso8601String(),
        updatedAt = updatedAt ?? DateTime.now().toIso8601String() {
    if (dayOfWeekSat0 < 0 || dayOfWeekSat0 > 6) {
      throw ArgumentError.value(
        dayOfWeekSat0,
        'dayOfWeekSat0',
        'باید عددی بین ۰ (شنبه) تا ۶ (جمعه) باشد.',
      );
    }
    if (!_timeRegex.hasMatch(startTime)) {
      throw ArgumentError.value(
        startTime,
        'startTime',
        'فرمت زمان باید به صورت HH:mm باشد.',
      );
    }
    if (durationMinutes <= 0) {
      throw ArgumentError.value(
        durationMinutes,
        'durationMinutes',
        'مدت زمان تعهد باید بیشتر از ۰ باشد.',
      );
    }
  }

  /// نام فارسی روز هفته (۰=شنبه .. ۶=جمعه)
  String get persianWeekdayName => persianWeekdays[dayOfWeekSat0];

  MvCommitment copyWith({
    int? id,
    String? kindCode,
    String? titleFa,
    int? dayOfWeekSat0,
    String? startTime,
    int? durationMinutes,
    String? venueNote,
    String? partnerNote,
    CommitmentRecurrence? recurrence,
    bool? isActive,
    bool? isFlexible,
    String? startDateIso,
    String? endDateIso,
    int? reminderMinutes,
    String? createdAt,
    String? updatedAt,
  }) {
    return MvCommitment(
      id: id ?? this.id,
      kindCode: kindCode ?? this.kindCode,
      titleFa: titleFa ?? this.titleFa,
      dayOfWeekSat0: dayOfWeekSat0 ?? this.dayOfWeekSat0,
      startTime: startTime ?? this.startTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      venueNote: venueNote ?? this.venueNote,
      partnerNote: partnerNote ?? this.partnerNote,
      recurrence: recurrence ?? this.recurrence,
      isActive: isActive ?? this.isActive,
      isFlexible: isFlexible ?? this.isFlexible,
      startDateIso: startDateIso ?? this.startDateIso,
      endDateIso: endDateIso ?? this.endDateIso,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'kindCode': kindCode,
      'titleFa': titleFa,
      'dayOfWeekSat0': dayOfWeekSat0,
      'startTime': startTime,
      'durationMinutes': durationMinutes,
      'venueNote': venueNote,
      'partnerNote': partnerNote,
      'recurrence': recurrence.code,
      'isActive': isActive ? 1 : 0,
      'isFlexible': isFlexible ? 1 : 0,
      'startDateIso': startDateIso,
      'endDateIso': endDateIso,
      'reminderMinutes': reminderMinutes,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory MvCommitment.fromMap(Map<String, dynamic> map) {
    return MvCommitment(
      id: map['id'] as int?,
      kindCode: map['kindCode'] as String,
      titleFa: map['titleFa'] as String?,
      dayOfWeekSat0: map['dayOfWeekSat0'] as int,
      startTime: map['startTime'] as String,
      durationMinutes: map['durationMinutes'] as int,
      venueNote: map['venueNote'] as String?,
      partnerNote: map['partnerNote'] as String?,
      recurrence: CommitmentRecurrence.fromCode(
        map['recurrence'] as String? ?? 'WEEKLY',
      ),
      isActive: (map['isActive'] as int? ?? 1) == 1,
      isFlexible: (map['isFlexible'] as int? ?? 0) == 1,
      startDateIso: map['startDateIso'] as String?,
      endDateIso: map['endDateIso'] as String?,
      reminderMinutes: map['reminderMinutes'] as int?,
      createdAt: map['createdAt'] as String?,
      updatedAt: map['updatedAt'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MvCommitment &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          kindCode == other.kindCode &&
          titleFa == other.titleFa &&
          dayOfWeekSat0 == other.dayOfWeekSat0 &&
          startTime == other.startTime &&
          durationMinutes == other.durationMinutes &&
          venueNote == other.venueNote &&
          partnerNote == other.partnerNote &&
          recurrence == other.recurrence &&
          isActive == other.isActive &&
          isFlexible == other.isFlexible &&
          startDateIso == other.startDateIso &&
          endDateIso == other.endDateIso &&
          reminderMinutes == other.reminderMinutes;

  @override
  int get hashCode => Object.hash(
        id,
        kindCode,
        titleFa,
        dayOfWeekSat0,
        startTime,
        durationMinutes,
        venueNote,
        partnerNote,
        recurrence,
        isActive,
        isFlexible,
        startDateIso,
        endDateIso,
        reminderMinutes,
      );
}
