/// مدل زمان‌بندی قالب برنامهٔ حرکت
class MovementPlanSchedule {
  const MovementPlanSchedule({
    required this.id,
    required this.templateId,
    required this.weekday,
    required this.timeOfDay,
    this.recurrence = 'weekly',
    required this.startDateIso,
    this.weeksCount,
    required this.createdAt,
  });

  final String id;
  final String templateId;

  /// روز هفته: ۰ = شنبه، ۱ = یکشنبه، ۲ = دوشنبه، ۳ = سه‌شنبه، ۴ = چهارشنبه، ۵ = پنجشنبه، ۶ = جمعه
  final int weekday;

  /// ساعت جلسه، برای نمونه: "18:30"
  final String timeOfDay;

  /// تکرار: once (یک بار), weekly (هر هفته), multiWeek (چندهفته‌ای)
  final String recurrence;

  /// تاریخ شروع برنامه (ISO yyyy-MM-dd)
  final String startDateIso;

  /// تعداد هفته‌ها (برای multiWeek)
  final int? weeksCount;

  final DateTime createdAt;

  factory MovementPlanSchedule.fromMap(Map<String, dynamic> map) {
    return MovementPlanSchedule(
      id: map['id'] as String,
      templateId: map['templateId'] as String,
      weekday: map['weekday'] as int,
      timeOfDay: map['timeOfDay'] as String,
      recurrence: (map['recurrence'] as String?) ?? 'weekly',
      startDateIso: map['startDateIso'] as String,
      weeksCount: map['weeksCount'] as int?,
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'templateId': templateId,
      'weekday': weekday,
      'timeOfDay': timeOfDay,
      'recurrence': recurrence,
      'startDateIso': startDateIso,
      'weeksCount': weeksCount,
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
  }

  MovementPlanSchedule copyWith({
    String? id,
    String? templateId,
    int? weekday,
    String? timeOfDay,
    String? recurrence,
    String? startDateIso,
    int? weeksCount,
    DateTime? createdAt,
  }) {
    return MovementPlanSchedule(
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      weekday: weekday ?? this.weekday,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      recurrence: recurrence ?? this.recurrence,
      startDateIso: startDateIso ?? this.startDateIso,
      weeksCount: weeksCount ?? this.weeksCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
