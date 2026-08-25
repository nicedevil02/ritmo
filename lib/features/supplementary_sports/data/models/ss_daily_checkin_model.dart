class SsDailyCheckin {
  const SsDailyCheckin({
    required this.dateIso,
    required this.energy,
    required this.soreness,
    required this.fatigue,
    required this.painLevel,
    this.availableMinutes,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  final String dateIso;
  final int energy; // 1 (lowest) to 5 (highest)
  final int soreness; // 1 (none) to 5 (severe)
  final int fatigue; // 1 (fresh) to 5 (exhausted)
  final int painLevel; // 0 (none) to 10 (severe)
  final int? availableMinutes;
  final String? note;
  final int createdAt;
  final int updatedAt;

  Map<String, dynamic> toMap() {
    return {
      'dateIso': dateIso,
      'energy': energy,
      'soreness': soreness,
      'fatigue': fatigue,
      'painLevel': painLevel,
      'availableMinutes': availableMinutes,
      'note': note,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory SsDailyCheckin.fromMap(Map<String, dynamic> map) {
    return SsDailyCheckin(
      dateIso: map['dateIso'] as String,
      energy: (map['energy'] as num?)?.toInt() ?? 3,
      soreness: (map['soreness'] as num?)?.toInt() ?? 1,
      fatigue: (map['fatigue'] as num?)?.toInt() ?? 1,
      painLevel: (map['painLevel'] as num?)?.toInt() ?? 0,
      availableMinutes: (map['availableMinutes'] as num?)?.toInt(),
      note: map['note'] as String?,
      createdAt:
          (map['createdAt'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      updatedAt:
          (map['updatedAt'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }

  SsDailyCheckin copyWith({
    String? dateIso,
    int? energy,
    int? soreness,
    int? fatigue,
    int? painLevel,
    int? availableMinutes,
    String? note,
    int? createdAt,
    int? updatedAt,
  }) {
    return SsDailyCheckin(
      dateIso: dateIso ?? this.dateIso,
      energy: energy ?? this.energy,
      soreness: soreness ?? this.soreness,
      fatigue: fatigue ?? this.fatigue,
      painLevel: painLevel ?? this.painLevel,
      availableMinutes: availableMinutes ?? this.availableMinutes,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
