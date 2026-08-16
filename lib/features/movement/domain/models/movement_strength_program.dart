import 'dart:convert';

/// وضعیت برنامهٔ قدرتی
enum MovementStrengthProgramStatus {
  none,
  draft,
  active,
  deload,
  paused,
  finished;

  static MovementStrengthProgramStatus fromString(String val) {
    return MovementStrengthProgramStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == val.toLowerCase(),
      orElse: () => MovementStrengthProgramStatus.none,
    );
  }
}

/// مدل برنامهٔ تمرین قدرتی در خانه
class MovementStrengthProgram {
  const MovementStrengthProgram({
    required this.id,
    this.name,
    this.goal,
    this.level,
    this.sensitiveAreas = const [],
    this.equipment = const [],
    this.daysPerWeek = 3,
    this.sessionMinutes = 30,
    this.preferredDays = const [],
    this.preferredTime,
    this.totalWeeks = 6,
    this.currentWeek = 1,
    this.deloadWeekIndex = 4,
    required this.status,
    this.draftStep = 1,
    this.draftDataJson,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? name;
  final String? goal;
  final String? level;
  final List<String> sensitiveAreas;
  final List<String> equipment;
  final int daysPerWeek;
  final int sessionMinutes;
  final List<int> preferredDays; // weekdays 1..7 (Saturday=1)
  final String? preferredTime;
  final int totalWeeks;
  final int currentWeek;
  final int? deloadWeekIndex;
  final MovementStrengthProgramStatus status;
  final int draftStep;
  final String? draftDataJson;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isActive => status == MovementStrengthProgramStatus.active;
  bool get isDeload => status == MovementStrengthProgramStatus.deload || (isActive && currentWeek == deloadWeekIndex);
  bool get isPaused => status == MovementStrengthProgramStatus.paused;
  bool get isFinished => status == MovementStrengthProgramStatus.finished;
  bool get isDraft => status == MovementStrengthProgramStatus.draft;
  bool get isInactive => status == MovementStrengthProgramStatus.none;

  double get progressFraction {
    if (totalWeeks <= 0) return 0.0;
    return (currentWeek / totalWeeks).clamp(0.0, 1.0);
  }

  Map<String, dynamic>? get draftData {
    if (draftDataJson == null || draftDataJson!.trim().isEmpty) return null;
    try {
      return jsonDecode(draftDataJson!) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  MovementStrengthProgram copyWith({
    String? id,
    String? name,
    String? goal,
    String? level,
    List<String>? sensitiveAreas,
    List<String>? equipment,
    int? daysPerWeek,
    int? sessionMinutes,
    List<int>? preferredDays,
    String? preferredTime,
    int? totalWeeks,
    int? currentWeek,
    int? deloadWeekIndex,
    MovementStrengthProgramStatus? status,
    int? draftStep,
    String? draftDataJson,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MovementStrengthProgram(
      id: id ?? this.id,
      name: name ?? this.name,
      goal: goal ?? this.goal,
      level: level ?? this.level,
      sensitiveAreas: sensitiveAreas ?? this.sensitiveAreas,
      equipment: equipment ?? this.equipment,
      daysPerWeek: daysPerWeek ?? this.daysPerWeek,
      sessionMinutes: sessionMinutes ?? this.sessionMinutes,
      preferredDays: preferredDays ?? this.preferredDays,
      preferredTime: preferredTime ?? this.preferredTime,
      totalWeeks: totalWeeks ?? this.totalWeeks,
      currentWeek: currentWeek ?? this.currentWeek,
      deloadWeekIndex: deloadWeekIndex ?? this.deloadWeekIndex,
      status: status ?? this.status,
      draftStep: draftStep ?? this.draftStep,
      draftDataJson: draftDataJson ?? this.draftDataJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory MovementStrengthProgram.fromMap(Map<String, dynamic> map) {
    List<String> parseStringList(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) return raw.map((e) => e.toString()).toList();
      try {
        final decoded = jsonDecode(raw.toString());
        if (decoded is List) return decoded.map((e) => e.toString()).toList();
      } catch (_) {}
      return [];
    }

    List<int> parseIntList(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) return raw.map((e) => (e as num).toInt()).toList();
      try {
        final decoded = jsonDecode(raw.toString());
        if (decoded is List) return decoded.map((e) => (e as num).toInt()).toList();
      } catch (_) {}
      return [];
    }

    return MovementStrengthProgram(
      id: map['id'] as String,
      name: map['name'] as String?,
      goal: map['goal'] as String?,
      level: map['level'] as String?,
      sensitiveAreas: parseStringList(map['sensitiveAreasJson']),
      equipment: parseStringList(map['equipmentJson']),
      daysPerWeek: (map['daysPerWeek'] as int?) ?? 3,
      sessionMinutes: (map['sessionMinutes'] as int?) ?? 30,
      preferredDays: parseIntList(map['preferredDaysJson']),
      preferredTime: map['preferredTime'] as String?,
      totalWeeks: (map['totalWeeks'] as int?) ?? 6,
      currentWeek: (map['currentWeek'] as int?) ?? 1,
      deloadWeekIndex: map['deloadWeekIndex'] as int?,
      status: MovementStrengthProgramStatus.fromString(map['status'] as String? ?? 'none'),
      draftStep: (map['draftStep'] as int?) ?? 1,
      draftDataJson: map['draftDataJson'] as String?,
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'goal': goal,
      'level': level,
      'sensitiveAreasJson': jsonEncode(sensitiveAreas),
      'equipmentJson': jsonEncode(equipment),
      'daysPerWeek': daysPerWeek,
      'sessionMinutes': sessionMinutes,
      'preferredDaysJson': jsonEncode(preferredDays),
      'preferredTime': preferredTime,
      'totalWeeks': totalWeeks,
      'currentWeek': currentWeek,
      'deloadWeekIndex': deloadWeekIndex,
      'status': status.name,
      'draftStep': draftStep,
      'draftDataJson': draftDataJson,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }
}
