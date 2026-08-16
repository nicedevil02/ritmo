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
    required this.status,
    this.currentWeek,
    this.totalWeeks,
    this.daysPerWeek,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? name;
  final MovementStrengthProgramStatus status;
  final int? currentWeek;
  final int? totalWeeks;
  final int? daysPerWeek;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isActive => status == MovementStrengthProgramStatus.active;
  bool get isDeload => status == MovementStrengthProgramStatus.deload;
  bool get isFinished => status == MovementStrengthProgramStatus.finished;
  bool get isInactive =>
      status == MovementStrengthProgramStatus.none ||
      status == MovementStrengthProgramStatus.draft;

  double get progressFraction {
    if (currentWeek == null || totalWeeks == null || totalWeeks! <= 0) return 0.0;
    return (currentWeek! / totalWeeks!).clamp(0.0, 1.0);
  }

  MovementStrengthProgram copyWith({
    String? id,
    String? name,
    MovementStrengthProgramStatus? status,
    int? currentWeek,
    int? totalWeeks,
    int? daysPerWeek,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MovementStrengthProgram(
      id: id ?? this.id,
      name: name ?? this.name,
      status: status ?? this.status,
      currentWeek: currentWeek ?? this.currentWeek,
      totalWeeks: totalWeeks ?? this.totalWeeks,
      daysPerWeek: daysPerWeek ?? this.daysPerWeek,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory MovementStrengthProgram.fromMap(Map<String, dynamic> map) {
    return MovementStrengthProgram(
      id: map['id'] as String,
      name: map['name'] as String?,
      status: MovementStrengthProgramStatus.fromString(map['status'] as String? ?? 'none'),
      currentWeek: map['currentWeek'] as int?,
      totalWeeks: map['totalWeeks'] as int?,
      daysPerWeek: map['daysPerWeek'] as int?,
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'status': status.name,
      'currentWeek': currentWeek,
      'totalWeeks': totalWeeks,
      'daysPerWeek': daysPerWeek,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
