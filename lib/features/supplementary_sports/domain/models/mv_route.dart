/// Domain model for recurring trails, tracks, and routes (`mv_routes` / S4-T7).
class MvRoute {
  final int? id;
  final String titleFa;
  final String kindCode;
  final double? distanceM;
  final double? elevationGainM;
  final String? notes;
  final int timesCompleted;
  final int? bestDurationMin;
  final String? lastDoneAt;
  final String createdAt;

  const MvRoute({
    this.id,
    required this.titleFa,
    required this.kindCode,
    this.distanceM,
    this.elevationGainM,
    this.notes,
    this.timesCompleted = 0,
    this.bestDurationMin,
    this.lastDoneAt,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'titleFa': titleFa,
      'kindCode': kindCode,
      'distanceM': distanceM,
      'elevationGainM': elevationGainM,
      'notes': notes,
      'timesCompleted': timesCompleted,
      'bestDurationMin': bestDurationMin,
      'lastDoneAt': lastDoneAt,
      'createdAt': createdAt,
    };
  }

  factory MvRoute.fromMap(Map<String, dynamic> map) {
    return MvRoute(
      id: map['id'] as int?,
      titleFa: map['titleFa'] as String,
      kindCode: map['kindCode'] as String,
      distanceM: (map['distanceM'] as num?)?.toDouble(),
      elevationGainM: (map['elevationGainM'] as num?)?.toDouble(),
      notes: map['notes'] as String?,
      timesCompleted: (map['timesCompleted'] as int?) ?? 0,
      bestDurationMin: map['bestDurationMin'] as int?,
      lastDoneAt: map['lastDoneAt'] as String?,
      createdAt: map['createdAt'] as String,
    );
  }

  MvRoute copyWith({
    int? id,
    String? titleFa,
    String? kindCode,
    double? distanceM,
    double? elevationGainM,
    String? notes,
    int? timesCompleted,
    int? bestDurationMin,
    String? lastDoneAt,
    String? createdAt,
  }) {
    return MvRoute(
      id: id ?? this.id,
      titleFa: titleFa ?? this.titleFa,
      kindCode: kindCode ?? this.kindCode,
      distanceM: distanceM ?? this.distanceM,
      elevationGainM: elevationGainM ?? this.elevationGainM,
      notes: notes ?? this.notes,
      timesCompleted: timesCompleted ?? this.timesCompleted,
      bestDurationMin: bestDurationMin ?? this.bestDurationMin,
      lastDoneAt: lastDoneAt ?? this.lastDoneAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'MvRoute(id: $id, title: $titleFa, kind: $kindCode, completed: $timesCompleted, best: $bestDurationMin)';
}
