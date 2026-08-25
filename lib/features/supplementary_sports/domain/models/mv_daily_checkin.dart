/// Daily Check-in Model (Single Source of Truth: ss_daily_checkin).
class MvDailyCheckin {
  final String dateIso;
  final int? energy; // 1..5
  final int? soreness; // 1..5
  final int? fatigue; // 1..5
  final int? painLevel; // 0..10
  final int? availableMinutes;
  final String? note;
  final int createdAt;
  final int updatedAt;

  const MvDailyCheckin({
    required this.dateIso,
    this.energy,
    this.soreness,
    this.fatigue,
    this.painLevel,
    this.availableMinutes,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

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

  factory MvDailyCheckin.fromMap(Map<String, dynamic> map) {
    return MvDailyCheckin(
      dateIso: map['dateIso'] as String,
      energy: (map['energy'] as num?)?.toInt(),
      soreness: (map['soreness'] as num?)?.toInt(),
      fatigue: (map['fatigue'] as num?)?.toInt(),
      painLevel: (map['painLevel'] as num?)?.toInt(),
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
}
