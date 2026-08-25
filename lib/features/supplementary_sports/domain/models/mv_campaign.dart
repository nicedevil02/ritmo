/// Campaign / Goal-Oriented Program (`movement_campaigns`).
/// Follows N-08 & F-28.
class MvCampaign {
  final String id;
  final String titleFa;
  final String goalCode;
  final String startDate; // ISO YYYY-MM-DD
  final int weeks;
  final String status; // ACTIVE, COMPLETED, ARCHIVED
  final List<String> routineIds;
  final String? progressJson;
  final int createdAt;
  final int updatedAt;

  const MvCampaign({
    required this.id,
    required this.titleFa,
    required this.goalCode,
    required this.startDate,
    required this.weeks,
    this.status = 'ACTIVE',
    this.routineIds = const [],
    this.progressJson,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive => status == 'ACTIVE';

  MvCampaign copyWith({
    String? id,
    String? titleFa,
    String? goalCode,
    String? startDate,
    int? weeks,
    String? status,
    List<String>? routineIds,
    String? progressJson,
    int? createdAt,
    int? updatedAt,
  }) {
    return MvCampaign(
      id: id ?? this.id,
      titleFa: titleFa ?? this.titleFa,
      goalCode: goalCode ?? this.goalCode,
      startDate: startDate ?? this.startDate,
      weeks: weeks ?? this.weeks,
      status: status ?? this.status,
      routineIds: routineIds ?? this.routineIds,
      progressJson: progressJson ?? this.progressJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'titleFa': titleFa,
      'goalCode': goalCode,
      'startDate': startDate,
      'weeks': weeks,
      'status': status,
      'routineIds': routineIds.join(','),
      'progressJson': progressJson,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory MvCampaign.fromMap(Map<String, dynamic> map) {
    List<String> parseList(dynamic val) {
      if (val == null) return [];
      final s = val.toString().trim();
      if (s.isEmpty) return [];
      return s
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return MvCampaign(
      id: map['id'] as String,
      titleFa: map['titleFa'] as String,
      goalCode: (map['goalCode'] as String?) ?? 'general',
      startDate: map['startDate'] as String,
      weeks: (map['weeks'] as num?)?.toInt() ?? 4,
      status: (map['status'] as String?) ?? 'ACTIVE',
      routineIds: parseList(map['routineIds']),
      progressJson: map['progressJson'] as String?,
      createdAt:
          (map['createdAt'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      updatedAt:
          (map['updatedAt'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }
}
