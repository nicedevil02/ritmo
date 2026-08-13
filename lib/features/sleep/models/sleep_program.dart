/// وضعیت برنامهٔ خواب (سند «مسیر خواب»، بخش ۲).
enum SleepProgramStatus { listening, anchoring, active, paused, completed }

/// مدل برنامهٔ خواب.
///
/// هدف خواب عمداً اینجا ستون ندارد: تنها منبع حقیقتِ هدف، کلیدهای
/// `sleep_target_%` در `app_settings` است (اصل ۶ سند).
class SleepProgram {
  const SleepProgram({
    required this.id,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.stepMinutes = 15,
    this.minNightsPerStep = 2,
    this.freeNightWeekday,
    this.cycleSyncEnabled = false,
  });

  final String id;
  final SleepProgramStatus status;

  /// اندازهٔ هر پله به دقیقه (۱۰/۱۵/۲۰).
  final int stepMinutes;

  /// حداقل شب‌های لازم روی هر پله پیش از پیشروی.
  final int minNightsPerStep;

  /// روز هفتهٔ شب آزاد (۱ تا ۷)؛ null یعنی تنظیم نشده.
  final int? freeNightWeekday;
  final bool cycleSyncEnabled;
  final int createdAt;
  final int updatedAt;

  factory SleepProgram.fromMap(Map<String, dynamic> map) {
    return SleepProgram(
      id: map['id'] as String,
      status: SleepProgramStatus.values
              .asNameMap()[map['status'] as String? ?? ''] ??
          SleepProgramStatus.listening,
      stepMinutes: map['stepMinutes'] as int? ?? 15,
      minNightsPerStep: map['minNightsPerStep'] as int? ?? 2,
      freeNightWeekday: map['freeNightWeekday'] as int?,
      cycleSyncEnabled: (map['cycleSyncEnabled'] as int? ?? 0) == 1,
      createdAt: map['createdAt'] as int? ?? 0,
      updatedAt: map['updatedAt'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'status': status.name,
      'stepMinutes': stepMinutes,
      'minNightsPerStep': minNightsPerStep,
      'freeNightWeekday': freeNightWeekday,
      'cycleSyncEnabled': cycleSyncEnabled ? 1 : 0,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  SleepProgram copyWith({
    SleepProgramStatus? status,
    int? stepMinutes,
    int? minNightsPerStep,
    int? freeNightWeekday,
    bool? cycleSyncEnabled,
    int? updatedAt,
  }) {
    return SleepProgram(
      id: id,
      status: status ?? this.status,
      stepMinutes: stepMinutes ?? this.stepMinutes,
      minNightsPerStep: minNightsPerStep ?? this.minNightsPerStep,
      freeNightWeekday: freeNightWeekday ?? this.freeNightWeekday,
      cycleSyncEnabled: cycleSyncEnabled ?? this.cycleSyncEnabled,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
